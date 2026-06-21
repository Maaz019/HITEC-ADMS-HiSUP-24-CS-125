-- =========================================================
-- Module 6: MERGE Statement (matches real HiSUP_DB schema)
-- Feature: Bulk Grade Import
-- Grades is keyed by EnrollmentID, not StudentID+SectionID
-- =========================================================
USE HiSUP_DB;
GO

IF OBJECT_ID('dbo.GradeImportStaging', 'U') IS NOT NULL
    DROP TABLE dbo.GradeImportStaging;
GO

CREATE TABLE dbo.GradeImportStaging (
    EnrollmentID  INT NOT NULL,
    MarksObtained DECIMAL(5,2) NOT NULL,
    LetterGrade   NVARCHAR(2) NOT NULL,
    GradePoints   DECIMAL(3,2) NOT NULL
);
GO

IF OBJECT_ID('dbo.BulkGradeImport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.BulkGradeImport;
GO

CREATE PROCEDURE dbo.BulkGradeImport
    @SectionID INT   -- restrict the delete branch to the section being re-imported
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MergeOutput TABLE (
        Action       NVARCHAR(10),
        InsertedID   INT NULL,
        DeletedID    INT NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        MERGE Grades AS target
        USING dbo.GradeImportStaging AS source
            ON target.EnrollmentID = source.EnrollmentID

        WHEN MATCHED THEN
            UPDATE SET
                target.MarksObtained = source.MarksObtained,
                target.LetterGrade   = source.LetterGrade,
                target.GradePoints   = source.GradePoints,
                target.GradedDate    = GETDATE()

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (EnrollmentID, MarksObtained, LetterGrade, GradePoints, GradedDate)
            VALUES (source.EnrollmentID, source.MarksObtained, source.LetterGrade,
                    source.GradePoints, GETDATE())

        -- only delete grades belonging to enrollments in THIS section
        -- that were dropped from the import file
        WHEN NOT MATCHED BY SOURCE
             AND target.EnrollmentID IN (
                 SELECT e.EnrollmentID FROM Enrollments e WHERE e.SectionID = @SectionID
             )
        THEN
            DELETE

        OUTPUT $action, inserted.EnrollmentID, deleted.EnrollmentID
        INTO @MergeOutput (Action, InsertedID, DeletedID);

        COMMIT TRANSACTION;

        -- return the summary to the caller (this is fine -- it's a plain
        -- SELECT against a table variable, not an OUTPUT clause hitting
        -- a triggered table directly)
        SELECT Action, InsertedID, DeletedID FROM @MergeOutput;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ---------------------------------------------------------
-- Demo
-- ---------------------------------------------------------
-- TRUNCATE TABLE dbo.GradeImportStaging;
-- INSERT INTO dbo.GradeImportStaging (EnrollmentID, MarksObtained, LetterGrade, GradePoints)
-- VALUES (1, 88.5, 'A', 4.00), (2, 71.0, 'B', 3.00);
-- EXEC dbo.BulkGradeImport @SectionID = 101;
