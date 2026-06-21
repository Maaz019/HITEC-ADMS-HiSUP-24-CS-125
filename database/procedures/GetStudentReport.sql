-- ============================================================
-- GetStudentReport
-- Returns a consolidated dashboard view for one student:
-- academic standing, attendance percentage, and fee balance.
-- This is the data source for the Student Dashboard page
-- (vw_StudentDashboard will formalize part of this as a view later).
-- Demonstrates: multiple aggregations, LEFT JOINs for optional data,
--               read-only reporting procedure
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE GetStudentReport
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    SELECT
        s.StudentID,
        s.RegistrationNo,
        s.FirstName,
        s.LastName,
        p.ProgramName,
        s.CurrentSemester,

        -- Latest CGPA on record
        (SELECT TOP 1 CGPA FROM Results WHERE StudentID = s.StudentID ORDER BY Semester DESC) AS LatestCGPA,

        -- Attendance percentage across all enrollments
        (SELECT
            CASE WHEN COUNT(*) = 0 THEN NULL
                 ELSE CAST(SUM(CASE WHEN ar.Status = 'Present' THEN 1 ELSE 0 END) AS DECIMAL(5,2))
                      * 100.0 / COUNT(*)
            END
         FROM AttendanceRecords ar
         INNER JOIN Enrollments e2 ON ar.EnrollmentID = e2.EnrollmentID
         WHERE e2.StudentID = s.StudentID
        ) AS AttendancePercentage,

        -- Total fee owed across all fee structures tied to the student's program
        (SELECT ISNULL(SUM(fs.TuitionFee + fs.LabFee + fs.OtherCharges), 0)
         FROM FeeStructure fs
         WHERE fs.ProgramID = s.ProgramID
        ) AS TotalFeeCharged,

        -- Total paid so far
        (SELECT ISNULL(SUM(AmountPaid), 0)
         FROM FeePayments
         WHERE StudentID = s.StudentID AND Status = 'Completed'
        ) AS TotalFeePaid,

        -- Active hostel allotment, if any
        (SELECT TOP 1 h.HostelName + ' - ' + ha.RoomNumber
         FROM HostelAllotments ha
         INNER JOIN Hostels h ON ha.HostelID = h.HostelID
         WHERE ha.StudentID = s.StudentID AND ha.Status = 'Active'
        ) AS CurrentHostelRoom

    FROM Students s
    INNER JOIN Programs p ON s.ProgramID = p.ProgramID
    WHERE s.StudentID = @StudentID;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
EXEC GetStudentReport @StudentID = 1;
GO

EXEC GetStudentReport @StudentID = 2;
GO

-- ============================================================
-- Test error handling - non-existent student
-- ============================================================
BEGIN TRY
    EXEC GetStudentReport @StudentID = 9999;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
