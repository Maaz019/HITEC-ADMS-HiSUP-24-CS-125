-- ============================================================
-- vw_FeeDefaulters
-- Reporting view: students who owe money on any fee structure.
-- Uses fn_GetOutstandingFee (built in Module 2) to compute the
-- balance per student/structure pair, filtering to only positive
-- balances.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_FeeDefaulters
AS
SELECT
    s.StudentID,
    s.RegistrationNo,
    s.FirstName,
    s.LastName,
    fs.FeeStructureID,
    fs.Semester,
    dbo.fn_GetOutstandingFee(s.StudentID, fs.FeeStructureID) AS OutstandingBalance
FROM Students s
INNER JOIN Programs p ON s.ProgramID = p.ProgramID
INNER JOIN FeeStructure fs ON fs.ProgramID = p.ProgramID
WHERE dbo.fn_GetOutstandingFee(s.StudentID, fs.FeeStructureID) > 0;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_FeeDefaulters ORDER BY OutstandingBalance DESC;
GO
