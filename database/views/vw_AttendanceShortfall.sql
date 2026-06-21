-- ============================================================
-- vw_AttendanceShortfall
-- Reporting view: enrollments where attendance has dropped
-- below 75% (a common eligibility threshold for sitting exams).
-- Uses fn_GetAttendancePercentage (built in Module 2).
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_AttendanceShortfall
AS
SELECT
    e.EnrollmentID,
    s.StudentID,
    s.RegistrationNo,
    s.FirstName,
    s.LastName,
    c.CourseCode,
    c.CourseTitle,
    dbo.fn_GetAttendancePercentage(e.EnrollmentID) AS AttendancePercentage
FROM Enrollments e
INNER JOIN Students s ON e.StudentID = s.StudentID
INNER JOIN Sections sec ON e.SectionID = sec.SectionID
INNER JOIN Courses c ON sec.CourseID = c.CourseID
WHERE dbo.fn_GetAttendancePercentage(e.EnrollmentID) < 75
  AND dbo.fn_GetAttendancePercentage(e.EnrollmentID) IS NOT NULL;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_AttendanceShortfall ORDER BY AttendancePercentage ASC;
GO
