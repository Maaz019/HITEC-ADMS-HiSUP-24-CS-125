-- ============================================================
-- vw_FacultyCourseLoad
-- UPDATABLE view, WITH SCHEMABINDING (the 2nd of 2 required
-- updatable+schemabound views).
-- Like vw_StudentDashboard, this exposes base columns from
-- Faculty directly with no aggregation, keeping it updatable.
-- (The actual "course load" reporting with joins/counts lives
-- in GetFacultyWorkload and will also appear in a separate,
-- non-updatable reporting view later if needed.)
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_FacultyCourseLoad
WITH SCHEMABINDING
AS
SELECT
    FacultyID,
    FirstName,
    LastName,
    Email,
    DepartmentID,
    Designation
FROM dbo.Faculty;
GO

-- ============================================================
-- Test it - read
-- ============================================================
SELECT * FROM vw_FacultyCourseLoad WHERE FacultyID = 1;
GO

-- ============================================================
-- Test it - update through the view
-- ============================================================
UPDATE vw_FacultyCourseLoad
SET Designation = 'Senior Lecturer'
WHERE FacultyID = 1;

SELECT FacultyID, Designation FROM Faculty WHERE FacultyID = 1;
GO

-- Revert test change
UPDATE vw_FacultyCourseLoad SET Designation = 'Lecturer' WHERE FacultyID = 1;
GO
