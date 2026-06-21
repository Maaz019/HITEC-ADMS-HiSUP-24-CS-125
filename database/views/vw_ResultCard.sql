-- ============================================================
-- vw_ResultCard
-- Reporting view: a student's semester-by-semester result card
-- (the data behind the Results page / transcript summary).
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_ResultCard
AS
SELECT
    r.ResultID,
    s.StudentID,
    s.RegistrationNo,
    s.FirstName,
    s.LastName,
    p.ProgramName,
    r.Semester,
    r.SemesterGPA,
    r.CGPA,
    r.TotalCreditHours,
    r.ResultStatus,
    r.PublishedDate
FROM Results r
INNER JOIN Students s ON r.StudentID = s.StudentID
INNER JOIN Programs p ON s.ProgramID = p.ProgramID;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_ResultCard ORDER BY RegistrationNo, Semester;
GO
