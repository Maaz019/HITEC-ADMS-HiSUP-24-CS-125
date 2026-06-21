-- ============================================================
-- vw_ExamTimetable
-- Reporting view: exam schedule joined with course/section info,
-- presented in a timetable-friendly shape.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER VIEW vw_ExamTimetable
AS
SELECT
    es.ExamScheduleID,
    c.CourseCode,
    c.CourseTitle,
    sec.SectionCode,
    sec.Semester,
    es.ExamType,
    es.ExamDate,
    es.StartTime,
    es.EndTime,
    es.RoomNumber,
    f.FirstName AS FacultyFirstName,
    f.LastName AS FacultyLastName
FROM ExamSchedule es
INNER JOIN Sections sec ON es.SectionID = sec.SectionID
INNER JOIN Courses c ON sec.CourseID = c.CourseID
INNER JOIN Faculty f ON sec.FacultyID = f.FacultyID;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT * FROM vw_ExamTimetable ORDER BY ExamDate, StartTime;
GO
