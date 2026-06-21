-- ============================================================
-- MODULE 5: ROW-LEVEL SECURITY (RLS)
-- File: database/security/02_row_level_security.sql
-- Run AFTER 01_roles_and_permissions.sql
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- HOW RLS WORKS (viva explanation):
-- 1. You create a predicate function that returns 1 (allow) or 0 (block)
-- 2. You bind it to a table via CREATE SECURITY POLICY
-- 3. SQL Server silently adds the predicate to every SELECT/INSERT/UPDATE/DELETE
--    on that table — even if someone bypasses your stored procedures
-- This is why RLS is superior to just using WHERE clauses in procedures.
-- ============================================================

-- ============================================================
-- STEP 1: Helper function to get the current user's StudentID
-- In production this will be set via SESSION_CONTEXT by ASP.NET
-- ============================================================

CREATE OR ALTER FUNCTION dbo.fn_GetCurrentStudentID()
RETURNS INT
AS
BEGIN
    -- SESSION_CONTEXT is set by C# before any query:
    -- SqlCommand.CommandText = "EXEC sp_set_session_context 'StudentID', @id";
    -- This allows the app to pass the logged-in user's ID securely
    RETURN CAST(SESSION_CONTEXT(N'StudentID') AS INT);
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetCurrentFacultyID()
RETURNS INT
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'FacultyID') AS INT);
END
GO

-- ============================================================
-- STEP 2: RLS Predicate Functions
-- Must be in a schema, must return TABLE with a single column
-- The function returns 1 (row is visible) or 0 (row is hidden)
-- ============================================================

-- Predicate for Enrollments: students see only their own rows
CREATE OR ALTER FUNCTION dbo.rls_fn_EnrollmentFilter
    (@StudentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_result
    WHERE
        -- Admins and finance see everything (IS_MEMBER checks the DB role)
        IS_MEMBER('db_admin')    = 1
     OR IS_MEMBER('db_finance')  = 1
        -- Faculty see all (they need to see who is in their sections)
     OR IS_MEMBER('db_faculty')  = 1
        -- Students see only their own rows
     OR (IS_MEMBER('db_student') = 1
         AND @StudentID = dbo.fn_GetCurrentStudentID());
GO

-- Predicate for Grades: students see only their own grades
CREATE OR ALTER FUNCTION dbo.rls_fn_GradeFilter
    (@EnrollmentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_result
    WHERE
        IS_MEMBER('db_admin')   = 1
     OR IS_MEMBER('db_finance') = 1
     OR IS_MEMBER('db_faculty') = 1
        -- For students: check that the enrollment belongs to them
     OR (IS_MEMBER('db_student') = 1
         AND EXISTS (
             SELECT 1 FROM dbo.Enrollments e
             WHERE e.EnrollmentID = @EnrollmentID
               AND e.StudentID = dbo.fn_GetCurrentStudentID()
         ));
GO

-- Predicate for FeePayments: students see only their own payments
CREATE OR ALTER FUNCTION dbo.rls_fn_FeePaymentFilter
    (@StudentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_result
    WHERE
        IS_MEMBER('db_admin')   = 1
     OR IS_MEMBER('db_finance') = 1
     OR IS_MEMBER('db_faculty') = 1
     OR (IS_MEMBER('db_student') = 1
         AND @StudentID = dbo.fn_GetCurrentStudentID());
GO

-- Predicate for Sections: faculty see only their assigned sections
CREATE OR ALTER FUNCTION dbo.rls_fn_SectionFilter
    (@FacultyID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_result
    WHERE
        IS_MEMBER('db_admin')   = 1
     OR IS_MEMBER('db_finance') = 1
     OR IS_MEMBER('db_student') = 1  -- students can see all sections (for enrollment)
        -- Faculty see only sections assigned to them
     OR (IS_MEMBER('db_faculty') = 1
         AND @FacultyID = dbo.fn_GetCurrentFacultyID());
GO

-- ============================================================
-- STEP 3: Create Security Policies (bind predicates to tables)
-- Drop existing policies first so this script is re-runnable
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'EnrollmentSecurityPolicy')
    DROP SECURITY POLICY dbo.EnrollmentSecurityPolicy;
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'GradeSecurityPolicy')
    DROP SECURITY POLICY dbo.GradeSecurityPolicy;
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'FeePaymentSecurityPolicy')
    DROP SECURITY POLICY dbo.FeePaymentSecurityPolicy;
GO

IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = 'SectionSecurityPolicy')
    DROP SECURITY POLICY dbo.SectionSecurityPolicy;
GO

-- Bind to Enrollments table — filter on StudentID column
CREATE SECURITY POLICY dbo.EnrollmentSecurityPolicy
    ADD FILTER PREDICATE dbo.rls_fn_EnrollmentFilter(StudentID)
    ON dbo.Enrollments
    WITH (STATE = ON);
GO

-- Bind to Grades table — filter on EnrollmentID (indirect link to StudentID)
CREATE SECURITY POLICY dbo.GradeSecurityPolicy
    ADD FILTER PREDICATE dbo.rls_fn_GradeFilter(EnrollmentID)
    ON dbo.Grades
    WITH (STATE = ON);
GO

-- Bind to FeePayments table — filter on StudentID column
CREATE SECURITY POLICY dbo.FeePaymentSecurityPolicy
    ADD FILTER PREDICATE dbo.rls_fn_FeePaymentFilter(StudentID)
    ON dbo.FeePayments
    WITH (STATE = ON);
GO

-- Bind to Sections table — filter on FacultyID column
CREATE SECURITY POLICY dbo.SectionSecurityPolicy
    ADD FILTER PREDICATE dbo.rls_fn_SectionFilter(FacultyID)
    ON dbo.Sections
    WITH (STATE = ON);
GO

-- ============================================================
-- STEP 4: Test RLS works
-- Simulate a student (StudentID = 1) viewing Enrollments
-- ============================================================

-- Set SESSION_CONTEXT to simulate student ID 1 logged in
EXEC sp_set_session_context N'StudentID', 1;

-- As db_admin (current user) we can still see all rows
SELECT 'As admin - all enrollments:' AS Test, COUNT(*) AS RowCount FROM dbo.Enrollments;

-- To properly test the student filter, you would:
-- 1. Connect to SSMS as test_student (a user in db_student role)
-- 2. Run: EXEC sp_set_session_context N'StudentID', 1;
-- 3. Run: SELECT * FROM Enrollments;
-- You should see ONLY rows where StudentID = 1
-- Without SESSION_CONTEXT set, a student user would see 0 rows (no match)

-- Verify security policies are active
SELECT 
    sp.name AS PolicyName,
    sp.is_enabled,
    sp.is_schema_bound,
    pred.predicate_type_desc,
    pred.target_schema_name + '.' + pred.target_object_name AS TargetTable,
    pred.predicate_definition
FROM sys.security_policies sp
JOIN sys.security_predicates pred ON sp.object_id = pred.object_id
ORDER BY sp.name;
GO

-- ============================================================
-- HOW TO USE SESSION_CONTEXT IN C# (for your ASP.NET app)
-- In your DbContext or repository, before any query:
--
-- var cmd = connection.CreateCommand();
-- cmd.CommandText = "EXEC sp_set_session_context N'StudentID', @id";
-- cmd.Parameters.AddWithValue("@id", currentUser.StudentId);
-- cmd.ExecuteNonQuery();
--
-- After this, all queries in this session automatically filter by RLS.
-- ============================================================
