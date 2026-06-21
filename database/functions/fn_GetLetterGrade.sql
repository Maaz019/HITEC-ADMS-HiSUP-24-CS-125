-- ============================================================
-- fn_GetLetterGrade
-- Scalar UDF: converts numeric marks (0-100) into a letter grade.
-- This formalizes the CASE logic that was inline in AddExamResult.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER FUNCTION fn_GetLetterGrade (@MarksObtained DECIMAL(5,2))
RETURNS NVARCHAR(2)
AS
BEGIN
    DECLARE @LetterGrade NVARCHAR(2);

    SET @LetterGrade = CASE
        WHEN @MarksObtained >= 90 THEN 'A'
        WHEN @MarksObtained >= 85 THEN 'A-'
        WHEN @MarksObtained >= 80 THEN 'B+'
        WHEN @MarksObtained >= 75 THEN 'B'
        WHEN @MarksObtained >= 70 THEN 'B-'
        WHEN @MarksObtained >= 65 THEN 'C+'
        WHEN @MarksObtained >= 60 THEN 'C'
        WHEN @MarksObtained >= 50 THEN 'D'
        ELSE 'F'
    END;

    RETURN @LetterGrade;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT dbo.fn_GetLetterGrade(95.00) AS Grade_95;
SELECT dbo.fn_GetLetterGrade(72.50) AS Grade_72_5;
SELECT dbo.fn_GetLetterGrade(45.00) AS Grade_45;
GO

-- Test against real data
SELECT EnrollmentID, MarksObtained, LetterGrade AS StoredGrade, dbo.fn_GetLetterGrade(MarksObtained) AS ComputedGrade
FROM Grades;
GO
