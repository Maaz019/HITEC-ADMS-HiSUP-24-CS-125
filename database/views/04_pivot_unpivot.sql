-- =========================================================
-- Module 6: PIVOT and UNPIVOT  (matches real HiSUP_DB schema)
-- Feature: Semester-wise Attendance Matrix
--
-- Real chain: Students -> Enrollments -> Sections -> Courses -> Departments
--             AttendanceRecords links via EnrollmentID
--             Sections.Semester is NVARCHAR (e.g. 'Fall 2024'), not an int
-- NOTE: assumes Programs(ProgramID, DepartmentID, ...) -- adjust if different.
-- =========================================================
USE HiSUP_DB;
GO

-- ---------------------------------------------------------
-- 1. DYNAMIC PIVOT (primary approach -- semester values are
--    free text, so the column list can't be hardcoded)
-- ---------------------------------------------------------
IF OBJECT_ID('dbo.GetAttendanceMatrixDynamic', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetAttendanceMatrixDynamic;
GO

CREATE PROCEDURE dbo.GetAttendanceMatrixDynamic
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cols NVARCHAR(MAX);
    DECLARE @sql  NVARCHAR(MAX);

    SELECT @cols = STRING_AGG(QUOTENAME(Semester), ',')
    FROM (SELECT DISTINCT Semester FROM Sections) AS sems;

    SET @sql = N'
    SELECT StudentID, StudentName, DeptName, ' + @cols + N'
    FROM
    (
        SELECT
            s.StudentID,
            s.FirstName + '' '' + s.LastName AS StudentName,
            d.DeptName,
            se.Semester,
            CAST(
                100.0 * SUM(CASE WHEN ar.Status = ''Present'' THEN 1 ELSE 0 END)
                / COUNT(ar.AttendanceID) AS DECIMAL(5,2)
            ) AS AttendancePct
        FROM Students s
        JOIN Programs p           ON p.ProgramID = s.ProgramID
        JOIN Departments d        ON d.DepartmentID = p.DepartmentID
        JOIN Enrollments e        ON e.StudentID = s.StudentID
        JOIN Sections se          ON se.SectionID = e.SectionID
        JOIN AttendanceRecords ar ON ar.EnrollmentID = e.EnrollmentID
        GROUP BY s.StudentID, s.FirstName, s.LastName, d.DeptName, se.Semester
    ) AS SourceData
    PIVOT
    (
        MAX(AttendancePct)
        FOR Semester IN (' + @cols + N')
    ) AS PivotTable;';

    EXEC sp_executesql @sql;
END;
GO

EXEC dbo.GetAttendanceMatrixDynamic;
GO

-- ---------------------------------------------------------
-- 2. UNPIVOT demo
--    Since the column list is dynamic, UNPIVOT is shown
--    against a snapshot temp table built from the dynamic
--    PIVOT result (UNPIVOT itself still needs a fixed,
--    known column list at compile time).
-- ---------------------------------------------------------
IF OBJECT_ID('tempdb..#AttendanceSnapshot') IS NOT NULL
    DROP TABLE #AttendanceSnapshot;
GO

-- Run this block AFTER checking which semester columns came back
-- from GetAttendanceMatrixDynamic above, then list them explicitly:

/*
SELECT StudentID, StudentName, DeptName, [Fall 2024], [Spring 2025]
INTO #AttendanceSnapshot
FROM ( ...same source query as above... ) AS SourceData
PIVOT ( MAX(AttendancePct) FOR Semester IN ([Fall 2024],[Spring 2025]) ) AS PivotTable;

SELECT StudentID, StudentName, DeptName, SemesterLabel, AttendancePct
FROM #AttendanceSnapshot
UNPIVOT
(
    AttendancePct FOR SemesterLabel IN ([Fall 2024],[Spring 2025])
) AS UnpivotTable;
*/
