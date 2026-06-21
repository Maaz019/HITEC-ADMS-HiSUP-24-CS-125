-- ============================================================
-- vw_LibraryOverdue
-- Reporting view: library issues that are overdue (past DueDate)
-- and not yet returned.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_LibraryOverdue
AS
SELECT
    li.IssueID,
    it.Title,
    it.Author,
    s.RegistrationNo,
    s.FirstName,
    s.LastName,
    f.FirstName AS FacultyFirstName,
    f.LastName AS FacultyLastName,
    li.IssueDate,
    li.DueDate,
    DATEDIFF(DAY, li.DueDate, CAST(GETDATE() AS DATE)) AS DaysOverdue
FROM LibraryIssues li
INNER JOIN LibraryItems it ON li.ItemID = it.ItemID
LEFT JOIN Students s ON li.StudentID = s.StudentID
LEFT JOIN Faculty f ON li.FacultyID = f.FacultyID
WHERE li.ReturnDate IS NULL
  AND li.DueDate < CAST(GETDATE() AS DATE);
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_LibraryOverdue ORDER BY DaysOverdue DESC;
GO
