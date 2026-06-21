-- ============================================================
-- vw_StudentDashboard
-- UPDATABLE view, WITH SCHEMABINDING (one of the 2 required
-- updatable+schemabound views).
-- Shows core student identity info pulled directly from base
-- columns only (no aggregates/joins-with-calcs) - this is what
-- makes it updatable: SQL Server allows updates through a view
-- only if each column maps to exactly one underlying base table
-- column, with no GROUP BY, DISTINCT, or computed expressions.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_StudentDashboard
WITH SCHEMABINDING
AS
SELECT
    StudentID,
    RegistrationNo,
    FirstName,
    LastName,
    Email,
    ProgramID,
    CurrentSemester,
    Status
FROM dbo.Students;
GO

-- ============================================================
-- Test it - read
-- ============================================================
SELECT * FROM vw_StudentDashboard WHERE StudentID = 1;
GO

-- ============================================================
-- Test it - update THROUGH the view (proves it's updatable)
-- ============================================================
UPDATE vw_StudentDashboard
SET CurrentSemester = 5
WHERE StudentID = 1;

SELECT StudentID, CurrentSemester FROM Students WHERE StudentID = 1;  -- confirm base table changed
GO

-- Revert test change
UPDATE vw_StudentDashboard SET CurrentSemester = 4 WHERE StudentID = 1;
GO
