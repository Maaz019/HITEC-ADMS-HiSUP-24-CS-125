-- ============================================================
-- MODULE 6: DYNAMIC SQL WITH sp_executesql
-- File: database/procedures/AdvancedSearch.sql
-- Injection-safe parameterised dynamic SQL for the search page
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- WHY sp_executesql INSTEAD OF EXEC(@sql)?
-- 
-- EXEC(@sql) builds a raw string — if any part of it comes from
-- user input, SQL injection is possible.
-- 
-- sp_executesql separates the query template from the parameters.
-- The parameters are NEVER concatenated into the SQL string;
-- they are passed as typed values. SQL Server compiles the
-- parameterised query once and reuses the plan.
-- 
-- Example of what we NEVER do:
--   SET @sql = 'SELECT * FROM Students WHERE Name = ''' + @Name + ''''
-- 
-- What we do instead:
--   SET @sql = 'SELECT * FROM Students WHERE Name = @p_Name'
--   EXEC sp_executesql @sql, N'@p_Name NVARCHAR(100)', @p_Name = @Name
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.AdvancedStudentSearch
    @FirstName      NVARCHAR(50)  = NULL,
    @LastName       NVARCHAR(50)  = NULL,
    @DepartmentID   INT           = NULL,
    @ProgramID      INT           = NULL,
    @Status         NVARCHAR(20)  = NULL,
    @MinCGPA        DECIMAL(3,2)  = NULL,
    @MaxCGPA        DECIMAL(3,2)  = NULL,
    @EnrollmentYear INT           = NULL,
    @SortColumn     NVARCHAR(50)  = 'RegistrationNo',  -- which column to sort by
    @SortDirection  NVARCHAR(4)   = 'ASC',             -- ASC or DESC
    @PageNumber     INT           = 1,
    @PageSize       INT           = 20
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate sort direction to prevent injection even in ORDER BY
    IF @SortDirection NOT IN ('ASC', 'DESC')
        SET @SortDirection = 'ASC';

    -- Whitelist allowed sort columns (ORDER BY cannot be parameterised directly)
    IF @SortColumn NOT IN ('RegistrationNo','FirstName','LastName','EnrollmentYear','Status')
        SET @SortColumn = 'RegistrationNo';

    -- --------------------------------------------------------
    -- Build the WHERE clause dynamically
    -- Each filter only gets added if the caller supplied a value
    -- --------------------------------------------------------
    DECLARE @sql       NVARCHAR(MAX);
    DECLARE @params    NVARCHAR(MAX);
    DECLARE @where     NVARCHAR(MAX) = N' WHERE 1=1 ';

    -- All user-supplied values are referenced as named parameters (@p_*)
    -- They are NEVER concatenated into the string directly
    IF @FirstName IS NOT NULL
        SET @where += N' AND s.FirstName LIKE @p_FirstName ';

    IF @LastName IS NOT NULL
        SET @where += N' AND s.LastName LIKE @p_LastName ';

    IF @DepartmentID IS NOT NULL
        SET @where += N' AND p.DepartmentID = @p_DepartmentID ';

    IF @ProgramID IS NOT NULL
        SET @where += N' AND s.ProgramID = @p_ProgramID ';

    IF @Status IS NOT NULL
        SET @where += N' AND s.Status = @p_Status ';

    IF @EnrollmentYear IS NOT NULL
        SET @where += N' AND s.EnrollmentYear = @p_EnrollmentYear ';

    -- CGPA filter using the UDF (inline scalar)
    IF @MinCGPA IS NOT NULL OR @MaxCGPA IS NOT NULL
    BEGIN
        -- We need a subquery for CGPA since it's computed
        SET @where += N' AND dbo.fn_CalculateCGPA(s.StudentID) BETWEEN
                         ISNULL(@p_MinCGPA, 0) AND ISNULL(@p_MaxCGPA, 4.0) ';
    END

    -- --------------------------------------------------------
    -- Build the full query string
    -- ORDER BY uses the whitelisted @SortColumn (safe — it came
    -- from our whitelist, not raw user input)
    -- --------------------------------------------------------
    SET @sql = N'
    SELECT
        s.StudentID,
        s.RegistrationNo,
        s.FirstName,
        s.LastName,
        s.Email,
        s.Status,
        s.EnrollmentYear,
        s.CurrentSemester,
        p.ProgramName,
        d.DeptName        AS Department,
        dbo.fn_CalculateCGPA(s.StudentID) AS CGPA,
        COUNT(*) OVER ()  AS TotalMatchCount
    FROM dbo.Students s
    JOIN dbo.Programs     p ON s.ProgramID    = p.ProgramID
    JOIN dbo.Departments  d ON p.DepartmentID = d.DepartmentID
    ' + @where + N'
    ORDER BY s.' + @SortColumn + N' ' + @SortDirection + N'
    OFFSET (@p_PageNumber - 1) * @p_PageSize ROWS
    FETCH NEXT @p_PageSize ROWS ONLY;
    ';

    -- --------------------------------------------------------
    -- Define ALL parameters the query may reference
    -- Type mismatches here cause a clear error, not injection
    -- --------------------------------------------------------
    SET @params = N'
        @p_FirstName      NVARCHAR(50),
        @p_LastName       NVARCHAR(50),
        @p_DepartmentID   INT,
        @p_ProgramID      INT,
        @p_Status         NVARCHAR(20),
        @p_MinCGPA        DECIMAL(3,2),
        @p_MaxCGPA        DECIMAL(3,2),
        @p_EnrollmentYear INT,
        @p_PageNumber     INT,
        @p_PageSize       INT
    ';

    -- --------------------------------------------------------
    -- Execute — note we append wildcards for LIKE here (safe)
    -- because @p_FirstName is typed, not concatenated into SQL
    -- --------------------------------------------------------
    EXEC sp_executesql
        @sql,
        @params,
        @p_FirstName      = CASE WHEN @FirstName IS NOT NULL THEN '%' + @FirstName + '%' END,
        @p_LastName       = CASE WHEN @LastName  IS NOT NULL THEN '%' + @LastName  + '%' END,
        @p_DepartmentID   = @DepartmentID,
        @p_ProgramID      = @ProgramID,
        @p_Status         = @Status,
        @p_MinCGPA        = @MinCGPA,
        @p_MaxCGPA        = @MaxCGPA,
        @p_EnrollmentYear = @EnrollmentYear,
        @p_PageNumber     = @PageNumber,
        @p_PageSize       = @PageSize;
END
GO

-- Advanced search for courses (for the SearchCourses page)
CREATE OR ALTER PROCEDURE dbo.AdvancedCourseSearch
    @Keyword        NVARCHAR(100) = NULL,
    @DepartmentID   INT           = NULL,
    @CreditHours    INT           = NULL,
    @HasPrerequisite BIT          = NULL,
    @Semester       NVARCHAR(20)  = NULL,  -- filter by sections in a given semester
    @PageNumber     INT           = 1,
    @PageSize       INT           = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql    NVARCHAR(MAX);
    DECLARE @params NVARCHAR(MAX);
    DECLARE @where  NVARCHAR(MAX) = N' WHERE 1=1 ';

    IF @Keyword IS NOT NULL
        SET @where += N' AND (c.CourseTitle LIKE @p_Keyword OR c.CourseCode LIKE @p_Keyword) ';

    IF @DepartmentID IS NOT NULL
        SET @where += N' AND c.DepartmentID = @p_DepartmentID ';

    IF @CreditHours IS NOT NULL
        SET @where += N' AND c.CreditHours = @p_CreditHours ';

    IF @HasPrerequisite = 1
        SET @where += N' AND c.PrerequisiteCourseID IS NOT NULL ';
    ELSE IF @HasPrerequisite = 0
        SET @where += N' AND c.PrerequisiteCourseID IS NULL ';

    IF @Semester IS NOT NULL
        SET @where += N' AND EXISTS (
            SELECT 1 FROM dbo.Sections sec
            WHERE sec.CourseID = c.CourseID AND sec.Semester = @p_Semester
        ) ';

    SET @sql = N'
    SELECT
        c.CourseID,
        c.CourseCode,
        c.CourseTitle,
        c.CreditHours,
        d.DeptName         AS Department,
        prereq.CourseCode  AS PrerequisiteCourse,
        COUNT(*) OVER ()   AS TotalMatchCount
    FROM dbo.Courses c
    JOIN dbo.Departments d ON c.DepartmentID = d.DepartmentID
    LEFT JOIN dbo.Courses prereq ON c.PrerequisiteCourseID = prereq.CourseID
    ' + @where + N'
    ORDER BY c.CourseCode
    OFFSET (@p_PageNumber - 1) * @p_PageSize ROWS
    FETCH NEXT @p_PageSize ROWS ONLY;
    ';

    SET @params = N'
        @p_Keyword      NVARCHAR(200),
        @p_DepartmentID INT,
        @p_CreditHours  INT,
        @p_Semester     NVARCHAR(20),
        @p_PageNumber   INT,
        @p_PageSize     INT
    ';

    EXEC sp_executesql
        @sql,
        @params,
        @p_Keyword      = CASE WHEN @Keyword IS NOT NULL THEN '%' + @Keyword + '%' END,
        @p_DepartmentID = @DepartmentID,
        @p_CreditHours  = @CreditHours,
        @p_Semester     = @Semester,
        @p_PageNumber   = @PageNumber,
        @p_PageSize     = @PageSize;
END
GO

-- ============================================================
-- TESTS
-- ============================================================

-- Test 1: Search students in department 1
EXEC dbo.AdvancedStudentSearch @DepartmentID = 1;

-- Test 2: Search by partial name, sorted by last name descending
EXEC dbo.AdvancedStudentSearch
    @FirstName = 'A',
    @SortColumn = 'LastName',
    @SortDirection = 'DESC';

-- Test 3: SQL injection attempt — this is SAFE, treated as literal string
EXEC dbo.AdvancedStudentSearch @FirstName = N"'; DROP TABLE Students; --";
-- Returns 0 rows, no error, no damage

-- Test 4: Course search
EXEC dbo.AdvancedCourseSearch @Keyword = 'Database';
GO
