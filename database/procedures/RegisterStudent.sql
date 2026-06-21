-- ============================================================
-- RegisterStudent
-- Registers a new student into the Students table
-- Demonstrates: TRY/CATCH, explicit transaction, RAISERROR/THROW,
--               input validation, OUTPUT parameter
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE RegisterStudent
    @RegistrationNo   NVARCHAR(20),
    @FirstName        NVARCHAR(50),
    @LastName         NVARCHAR(50),
    @Email             NVARCHAR(100),
    @CNIC              NVARCHAR(15),
    @DateOfBirth       DATE,
    @ProgramID         INT,
    @EnrollmentYear    INT,
    @NewStudentID      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation (before opening a transaction) ----
    IF @FirstName IS NULL OR LTRIM(RTRIM(@FirstName)) = ''
    BEGIN
        RAISERROR('FirstName cannot be empty.', 16, 1);
        RETURN;
    END

    IF @LastName IS NULL OR LTRIM(RTRIM(@LastName)) = ''
    BEGIN
        RAISERROR('LastName cannot be empty.', 16, 1);
        RETURN;
    END

    IF @Email IS NULL OR @Email NOT LIKE '%_@__%.__%'
    BEGIN
        RAISERROR('A valid email address is required.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Programs WHERE ProgramID = @ProgramID)
    BEGIN
        RAISERROR('ProgramID %d does not exist.', 16, 1, @ProgramID);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Students WHERE RegistrationNo = @RegistrationNo)
    BEGIN
        RAISERROR('A student with RegistrationNo %s already exists.', 16, 1, @RegistrationNo);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Students WHERE Email = @Email)
    BEGIN
        RAISERROR('A student with this email already exists.', 16, 1);
        RETURN;
    END

    -- ---- Transaction ----
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Students (
            RegistrationNo, FirstName, LastName, Email, CNIC,
            DateOfBirth, ProgramID, EnrollmentYear, CurrentSemester, Status
        )
        VALUES (
            @RegistrationNo, @FirstName, @LastName, @Email, @CNIC,
            @DateOfBirth, @ProgramID, @EnrollmentYear, 1, 'Active'
        );

        SET @NewStudentID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

-- ============================================================
-- Test it
-- ============================================================
DECLARE @NewID INT;

EXEC RegisterStudent
    @RegistrationNo = '24-CS-130',
    @FirstName = 'Fahad',
    @LastName = 'Iqbal',
    @Email = 'fahad.iqbal@student.hitecuni.edu.pk',
    @CNIC = '3520198765440',
    @DateOfBirth = '2004-04-15',
    @ProgramID = 1,
    @EnrollmentYear = 2024,
    @NewStudentID = @NewID OUTPUT;

SELECT @NewID AS NewStudentID;
SELECT * FROM Students WHERE StudentID = @NewID;
GO

-- ============================================================
-- Test the error handling - duplicate registration number
-- (Expected: should fail with our custom error message)
-- ============================================================
DECLARE @NewID2 INT;

BEGIN TRY
    EXEC RegisterStudent
        @RegistrationNo = '24-CS-130',  -- duplicate, should fail
        @FirstName = 'Another',
        @LastName = 'Student',
        @Email = 'another@student.hitecuni.edu.pk',
        @CNIC = '3520198765441',
        @DateOfBirth = '2004-01-01',
        @ProgramID = 1,
        @EnrollmentYear = 2024,
        @NewStudentID = @NewID2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
