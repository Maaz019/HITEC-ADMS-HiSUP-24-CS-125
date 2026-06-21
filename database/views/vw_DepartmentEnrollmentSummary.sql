-- ============================================================
-- vw_DepartmentEnrollmentSummary
-- Reporting view (NOT updatable - uses aggregation/JOINs).
-- Shows active student counts per department.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_DepartmentEnrollmentSummary
AS
SELECT
    d.DepartmentID,
    d.DeptName,
    d.DeptCode,
    COUNT(DISTINCT s.StudentID) AS ActiveStudentCount,
    COUNT(DISTINCT p.ProgramID) AS ProgramCount
FROM Departments d
LEFT JOIN Programs p ON p.DepartmentID = d.DepartmentID
LEFT JOIN Students s ON s.ProgramID = p.ProgramID AND s.Status = 'Active'
GROUP BY d.DepartmentID, d.DeptName, d.DeptCode;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_DepartmentEnrollmentSummary ORDER BY DeptName;
GO
