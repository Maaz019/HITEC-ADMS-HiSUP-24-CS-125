-- ============================================================
-- fn_GetAttendancePercentage
-- Scalar UDF: returns the attendance percentage for a student
-- in a specific enrollment (section). 'Present' counts as attended;
-- 'Absent' and 'Leave' do not.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER FUNCTION fn_GetAttendancePercentage (@EnrollmentID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @TotalClasses INT;
    DECLARE @PresentCount INT;
    DECLARE @Percentage DECIMAL(5,2);

    SELECT
        @TotalClasses = COUNT(*),
        @PresentCount = SUM(CASE WHEN Status = 'Present' THEN 1 ELSE 0 END)
    FROM AttendanceRecords
    WHERE EnrollmentID = @EnrollmentID;

    SET @Percentage = CASE
        WHEN @TotalClasses IS NULL OR @TotalClasses = 0 THEN NULL  -- no attendance recorded yet
        ELSE CAST(@PresentCount AS DECIMAL(5,2)) * 100.0 / @TotalClasses
    END;

    RETURN @Percentage;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT dbo.fn_GetAttendancePercentage(1) AS AttendancePct_Enrollment1;
SELECT dbo.fn_GetAttendancePercentage(4) AS AttendancePct_Enrollment4;
SELECT dbo.fn_GetAttendancePercentage(9999) AS AttendancePct_NoRecords;  -- should return NULL
GO

-- Test against all enrollments at once - useful for vw_AttendanceShortfall later
SELECT
    e.EnrollmentID,
    s.RegistrationNo,
    c.CourseCode,
    dbo.fn_GetAttendancePercentage(e.EnrollmentID) AS AttendancePercentage
FROM Enrollments e
INNER JOIN Students s ON e.StudentID = s.StudentID
INNER JOIN Sections sec ON e.SectionID = sec.SectionID
INNER JOIN Courses c ON sec.CourseID = c.CourseID;
GO
