-- ============================================================
-- MODULE 5: DATABASE ROLES AND PERMISSIONS
-- File: database/security/01_roles_and_permissions.sql
-- Run this in SSMS with HiSUP_DB selected
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- STEP 1: Create the four required roles
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_student' AND type = 'R')
    CREATE ROLE db_student;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_faculty' AND type = 'R')
    CREATE ROLE db_faculty;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_admin' AND type = 'R')
    CREATE ROLE db_admin;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'db_finance' AND type = 'R')
    CREATE ROLE db_finance;
GO

-- ============================================================
-- STEP 2: DENY direct table access to all roles
-- Students must NEVER query Grades, FeePayments, Enrollments directly
-- ============================================================

DENY SELECT ON dbo.Grades         TO db_student;
DENY SELECT ON dbo.FeePayments    TO db_student;
DENY SELECT ON dbo.Enrollments    TO db_student;
DENY INSERT ON dbo.Grades         TO db_student;
DENY UPDATE ON dbo.Grades         TO db_student;
DENY DELETE ON dbo.Grades         TO db_student;
DENY INSERT ON dbo.FeePayments    TO db_student;
DENY DELETE ON dbo.FeePayments    TO db_student;
DENY DELETE ON dbo.Enrollments    TO db_student;
GO

-- Faculty cannot touch fee tables or student personal info directly
DENY SELECT ON dbo.FeePayments    TO db_faculty;
DENY INSERT ON dbo.FeePayments    TO db_faculty;
DENY UPDATE ON dbo.FeePayments    TO db_faculty;
DENY DELETE ON dbo.FeePayments    TO db_faculty;
DENY UPDATE ON dbo.Students       TO db_faculty;
DENY DELETE ON dbo.Students       TO db_faculty;
GO

-- Finance cannot modify academic records
DENY INSERT ON dbo.Grades         TO db_finance;
DENY UPDATE ON dbo.Grades         TO db_finance;
DENY DELETE ON dbo.Grades         TO db_finance;
DENY INSERT ON dbo.Enrollments    TO db_finance;
DENY DELETE ON dbo.Enrollments    TO db_finance;
GO

-- ============================================================
-- STEP 3: GRANT EXECUTE on procedures per role
-- db_student: read own data, pay fees, enroll
-- ============================================================

GRANT EXECUTE ON dbo.RegisterStudent        TO db_admin;
GRANT EXECUTE ON dbo.EnrollInCourse         TO db_student;
GRANT EXECUTE ON dbo.ProcessFeePayment      TO db_student;
GRANT EXECUTE ON dbo.GenerateTranscript     TO db_student;
GRANT EXECUTE ON dbo.GetStudentReport       TO db_student;
GRANT EXECUTE ON dbo.GenerateFeeSlip        TO db_student;
GRANT EXECUTE ON dbo.SearchCourses          TO db_student;
GO

-- db_faculty: attendance, grades, workload
GRANT EXECUTE ON dbo.MarkAttendance         TO db_faculty;
GRANT EXECUTE ON dbo.AddExamResult          TO db_faculty;
GRANT EXECUTE ON dbo.CalculateSemesterGPA   TO db_faculty;
GRANT EXECUTE ON dbo.GetFacultyWorkload     TO db_faculty;
GRANT EXECUTE ON dbo.GenerateTranscript     TO db_faculty;
GRANT EXECUTE ON dbo.SearchCourses          TO db_faculty;
GRANT EXECUTE ON dbo.BulkResultUpload       TO db_faculty;
GO

-- db_admin: everything
GRANT EXECUTE ON dbo.RegisterStudent        TO db_admin;
GRANT EXECUTE ON dbo.EnrollInCourse         TO db_admin;
GRANT EXECUTE ON dbo.ProcessFeePayment      TO db_admin;
GRANT EXECUTE ON dbo.GenerateTranscript     TO db_admin;
GRANT EXECUTE ON dbo.CalculateSemesterGPA   TO db_admin;
GRANT EXECUTE ON dbo.MarkAttendance         TO db_admin;
GRANT EXECUTE ON dbo.AllocateHostelRoom     TO db_admin;
GRANT EXECUTE ON dbo.IssueLibraryBook       TO db_admin;
GRANT EXECUTE ON dbo.ReturnLibraryBook      TO db_admin;
GRANT EXECUTE ON dbo.AddExamResult          TO db_admin;
GRANT EXECUTE ON dbo.GetStudentReport       TO db_admin;
GRANT EXECUTE ON dbo.GetFacultyWorkload     TO db_admin;
GRANT EXECUTE ON dbo.GetDepartmentEnrollment TO db_admin;
GRANT EXECUTE ON dbo.GenerateFeeSlip        TO db_admin;
GRANT EXECUTE ON dbo.SearchCourses          TO db_admin;
GRANT EXECUTE ON dbo.BulkResultUpload       TO db_admin;
GO

-- db_finance: fee-related only
GRANT EXECUTE ON dbo.ProcessFeePayment      TO db_finance;
GRANT EXECUTE ON dbo.GenerateFeeSlip        TO db_finance;
GRANT EXECUTE ON dbo.GetDepartmentEnrollment TO db_finance;
GRANT SELECT  ON dbo.vw_FeeDefaulters       TO db_finance;
GRANT SELECT  ON dbo.vw_DepartmentEnrollmentSummary TO db_finance;
GO

-- ============================================================
-- STEP 4: Grant SELECT on views per role (read-only reporting)
-- ============================================================

GRANT SELECT ON dbo.vw_StudentDashboard             TO db_student;
GRANT SELECT ON dbo.vw_ExamTimetable                TO db_student;
GRANT SELECT ON dbo.vw_ResultCard                   TO db_student;
GRANT SELECT ON dbo.vw_LibraryOverdue               TO db_student;

GRANT SELECT ON dbo.vw_FacultyCourseLoad            TO db_faculty;
GRANT SELECT ON dbo.vw_AttendanceShortfall          TO db_faculty;
GRANT SELECT ON dbo.vw_ExamTimetable                TO db_faculty;
GRANT SELECT ON dbo.vw_DepartmentEnrollmentSummary  TO db_faculty;

GRANT SELECT ON dbo.vw_StudentDashboard             TO db_admin;
GRANT SELECT ON dbo.vw_FacultyCourseLoad            TO db_admin;
GRANT SELECT ON dbo.vw_DepartmentEnrollmentSummary  TO db_admin;
GRANT SELECT ON dbo.vw_FeeDefaulters                TO db_admin;
GRANT SELECT ON dbo.vw_AttendanceShortfall          TO db_admin;
GRANT SELECT ON dbo.vw_LibraryOverdue               TO db_admin;
GRANT SELECT ON dbo.vw_ExamTimetable                TO db_admin;
GRANT SELECT ON dbo.vw_ResultCard                   TO db_admin;
GO

-- ============================================================
-- STEP 5: Create SQL logins and database users to TEST the roles
-- These are test-only users. In production, ASP.NET Identity
-- handles auth — these let you verify DENY works in SSMS.
-- ============================================================

-- Create logins at server level (run these if you want to test)
-- You may need to be in master for these two lines:
-- CREATE LOGIN test_student WITH PASSWORD = 'Student@1234!';
-- CREATE LOGIN test_faculty WITH PASSWORD = 'Faculty@1234!';

-- Then in HiSUP_DB:
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'test_student')
BEGIN
    CREATE USER test_student WITHOUT LOGIN;  -- no real login needed for DENY testing
    ALTER ROLE db_student ADD MEMBER test_student;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'test_faculty')
BEGIN
    CREATE USER test_faculty WITHOUT LOGIN;
    ALTER ROLE db_faculty ADD MEMBER test_faculty;
END
GO

-- ============================================================
-- VERIFICATION: Check roles and their members
-- ============================================================
SELECT 
    r.name AS RoleName,
    m.name AS MemberName
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
ORDER BY r.name, m.name;

-- Check what procedures each role can execute
SELECT 
    dp.name AS RoleName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    perm.permission_name,
    perm.state_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.objects o ON perm.major_id = o.object_id
WHERE dp.type = 'R'
  AND dp.name IN ('db_student','db_faculty','db_admin','db_finance')
ORDER BY dp.name, o.name;
GO
