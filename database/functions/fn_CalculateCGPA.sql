-- ============================================================
-- fn_CalculateCGPA
-- Scalar UDF: computes a student's overall CGPA as a weighted
-- average of GradePoints across ALL their graded enrollments
-- (not just one semester - that's what makes this CGPA, not GPA).
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER FUNCTION fn_CalculateCGPA (@StudentID INT)
RETURNS DECIMAL(3,2)
AS
BEGIN
    DECLARE @CGPA DECIMAL(3,2);

    SELECT @CGPA = CASE
        WHEN SUM(c.CreditHours) = 0 OR SUM(c.CreditHours) IS NULL THEN 0
        ELSE SUM(g.GradePoints * c.CreditHours) * 1.0 / SUM(c.CreditHours)
    END
    FROM Grades g
    INNER JOIN Enrollments e ON g.EnrollmentID = e.EnrollmentID
    INNER JOIN Sections s ON e.SectionID = s.SectionID
    INNER JOIN Courses c ON s.CourseID = c.CourseID
    WHERE e.StudentID = @StudentID;

    RETURN ISNULL(@CGPA, 0);
END;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT dbo.fn_CalculateCGPA(1) AS CGPA_Student1;
SELECT dbo.fn_CalculateCGPA(2) AS CGPA_Student2;
SELECT dbo.fn_CalculateCGPA(9999) AS CGPA_NonExistentStudent;  -- should return 0, not error
GO

-- Test against all students at once
SELECT StudentID, RegistrationNo, FirstName, LastName, dbo.fn_CalculateCGPA(StudentID) AS ComputedCGPA
FROM Students;
GO
