-- ============================================================
-- trg_PreventDuplicateEnrollment
-- INSTEAD OF INSERT trigger on Enrollments: this is the brief's
-- required INSTEAD OF trigger. It intercepts every INSERT attempt
-- and only allows it through if the student isn't already
-- actively enrolled in that section. This is a second layer of
-- protection on top of the UNIQUE constraint and the procedure-
-- level check already in EnrollInCourse - demonstrating that
-- enforcement also exists at the trigger level, independent of
-- which procedure (or raw INSERT) is used to write the row.
--
-- IMPORTANT: Because this is INSTEAD OF, the original INSERT
-- never actually happens unless we explicitly perform it
-- ourselves inside the trigger body.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_PreventDuplicateEnrollment
ON Enrollments
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Block any inserted row that would duplicate an existing
    -- active enrollment for the same student/section pair
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Enrollments e
            ON e.StudentID = i.StudentID
           AND e.SectionID = i.SectionID
           AND e.Status <> 'Dropped'
    )
    BEGIN
        RAISERROR('Duplicate enrollment blocked by trg_PreventDuplicateEnrollment.', 16, 1);
        RETURN;
    END

    -- No duplicates found - perform the actual insert ourselves,
    -- since INSTEAD OF intercepts and replaces the default behavior
    INSERT INTO Enrollments (StudentID, SectionID, EnrollmentDate, Status)
    SELECT StudentID, SectionID, ISNULL(EnrollmentDate, GETDATE()), ISNULL(Status, 'Enrolled')
    FROM inserted;
END;
GO

-- ============================================================
-- Test it - a valid new enrollment should still go through
-- ============================================================
INSERT INTO Enrollments (StudentID, SectionID, Status)
VALUES (6, 1, 'Enrolled');  -- Bilal Akhtar enrolling in section 1

SELECT * FROM Enrollments WHERE StudentID = 6 AND SectionID = 1;
GO

-- ============================================================
-- Test the block - try to enroll the same student in the same
-- section again (should be rejected by the trigger)
-- ============================================================
BEGIN TRY
    INSERT INTO Enrollments (StudentID, SectionID, Status)
    VALUES (6, 1, 'Enrolled');
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
