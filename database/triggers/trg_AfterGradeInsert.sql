-- ============================================================
-- trg_AfterGradeInsert
-- AFTER INSERT trigger on Grades: recalculates the affected
-- student's CGPA using fn_CalculateCGPA and updates their most
-- recent Results row (if one exists). This demonstrates the
-- brief's own example trigger almost exactly.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_AfterGradeInsert
ON Grades
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- For each affected student (could be a multi-row insert),
    -- recompute CGPA and push it into their latest Results row
    UPDATE r
    SET r.CGPA = dbo.fn_CalculateCGPA(r.StudentID)
    FROM Results r
    WHERE r.StudentID IN (
        SELECT e.StudentID
        FROM inserted i
        INNER JOIN Enrollments e ON i.EnrollmentID = e.EnrollmentID
    )
    AND r.Semester = (
        SELECT MAX(Semester) FROM Results r2 WHERE r2.StudentID = r.StudentID
    );
END;
GO

-- ============================================================
-- Test it
-- ============================================================

-- Check student 1's CGPA in Results before adding a new grade
SELECT * FROM Results WHERE StudentID = 1;
GO

-- Grade enrollment 2 (student 1, section 2 - CS-305) which has no grade yet
INSERT INTO Grades (EnrollmentID, MarksObtained, LetterGrade, GradePoints, GradedDate)
VALUES (2, 78.00, dbo.fn_GetLetterGrade(78.00), 3.00, GETDATE());

-- Check Results again - CGPA should now reflect this new grade too
SELECT * FROM Results WHERE StudentID = 1;
GO

SELECT dbo.fn_CalculateCGPA(1) AS RecomputedCGPA;
GO
