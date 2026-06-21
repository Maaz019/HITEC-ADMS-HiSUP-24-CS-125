-- ============================================================
-- MODULE 5: COLUMN ENCRYPTION (CNIC and BankAccount)
-- File: database/security/03_column_encryption.sql
-- Uses ENCRYPTBYPASSPHRASE (simpler than Always Encrypted)
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- APPROACH: ENCRYPTBYPASSPHRASE
-- Viva explanation: ENCRYPTBYPASSPHRASE uses AES-128 symmetric
-- encryption with a passphrase you supply. The column stores
-- VARBINARY (encrypted bytes), not plain text. Only someone
-- who knows the passphrase can decrypt it with DECRYPTBYPASSPHRASE.
-- This is simpler to demo than Always Encrypted but still valid.
-- ============================================================

-- ============================================================
-- STEP 1: Add encrypted columns to Faculty and FeePayments
-- We keep the original NVARCHAR columns AND add encrypted VARBINARY
-- columns — then we'll zero out the plain text after migration.
-- In a real project you'd ALTER the table; here we add new columns
-- so the rest of your schema still works during the transition.
-- ============================================================

-- Add encrypted CNIC column to Faculty (if not already there)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('Faculty') AND name = 'CNIC_Encrypted'
)
    ALTER TABLE Faculty ADD CNIC_Encrypted VARBINARY(256) NULL;
GO

-- Add encrypted CNIC column to Students
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('Students') AND name = 'CNIC_Encrypted'
)
    ALTER TABLE Students ADD CNIC_Encrypted VARBINARY(256) NULL;
GO

-- Add encrypted BankAccount column to FeePayments
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('FeePayments') AND name = 'BankAccount_Encrypted'
)
    ALTER TABLE FeePayments ADD BankAccount_Encrypted VARBINARY(256) NULL;
GO

-- ============================================================
-- STEP 2: Stored procedure to encrypt and store a CNIC
-- The passphrase should come from an environment variable in C#,
-- NEVER hardcoded in production code.
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.SetFacultyCNIC
    @FacultyID   INT,
    @PlainCNIC   NVARCHAR(15),
    @Passphrase  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Faculty WHERE FacultyID = @FacultyID)
    BEGIN
        RAISERROR('FacultyID %d does not exist.', 16, 1, @FacultyID);
        RETURN;
    END

    UPDATE Faculty
    SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@Passphrase, @PlainCNIC)
    WHERE FacultyID = @FacultyID;

    PRINT 'CNIC encrypted and stored for FacultyID ' + CAST(@FacultyID AS NVARCHAR);
END
GO

CREATE OR ALTER PROCEDURE dbo.SetStudentCNIC
    @StudentID   INT,
    @PlainCNIC   NVARCHAR(15),
    @Passphrase  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Students
    SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@Passphrase, @PlainCNIC)
    WHERE StudentID = @StudentID;
    PRINT 'CNIC encrypted for StudentID ' + CAST(@StudentID AS NVARCHAR);
END
GO

CREATE OR ALTER PROCEDURE dbo.SetPaymentBankAccount
    @PaymentID   INT,
    @BankAccount NVARCHAR(30),
    @Passphrase  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FeePayments
    SET BankAccount_Encrypted = ENCRYPTBYPASSPHRASE(@Passphrase, @BankAccount)
    WHERE PaymentID = @PaymentID;
    PRINT 'BankAccount encrypted for PaymentID ' + CAST(@PaymentID AS NVARCHAR);
END
GO

-- ============================================================
-- STEP 3: Stored procedure to DECRYPT and return the value
-- Only callable by db_admin and db_finance roles
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.GetFacultyCNIC
    @FacultyID  INT,
    @Passphrase NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        FacultyID,
        FirstName + ' ' + LastName AS FullName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, CNIC_Encrypted) AS NVARCHAR(15)) AS DecryptedCNIC
    FROM Faculty
    WHERE FacultyID = @FacultyID;
END
GO

CREATE OR ALTER PROCEDURE dbo.GetStudentCNIC
    @StudentID  INT,
    @Passphrase NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        StudentID,
        FirstName + ' ' + LastName AS FullName,
        CAST(DECRYPTBYPASSPHRASE(@Passphrase, CNIC_Encrypted) AS NVARCHAR(15)) AS DecryptedCNIC
    FROM Students
    WHERE StudentID = @StudentID;
END
GO

-- Grant decrypt procedures only to admin (not student/faculty)
GRANT EXECUTE ON dbo.SetFacultyCNIC     TO db_admin;
GRANT EXECUTE ON dbo.SetStudentCNIC     TO db_admin;
GRANT EXECUTE ON dbo.GetFacultyCNIC     TO db_admin;
GRANT EXECUTE ON dbo.GetStudentCNIC     TO db_admin;
GRANT EXECUTE ON dbo.SetPaymentBankAccount TO db_finance;
GO

-- ============================================================
-- STEP 4: Encrypt the seeded data so you can demo decryption
-- IMPORTANT: In production, the passphrase comes from an
-- environment variable, NEVER from code committed to GitHub.
-- This passphrase is demo-only.
-- ============================================================

DECLARE @DemoPassphrase NVARCHAR(128) = 'HiSUP_Demo_Key_2026!';

-- Encrypt CNICs for seeded Faculty
UPDATE Faculty SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35201-1234567-1') WHERE FacultyID = 1;
UPDATE Faculty SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35201-7654321-9') WHERE FacultyID = 2;
UPDATE Faculty SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35202-1111111-3') WHERE FacultyID = 3;
UPDATE Faculty SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35202-9999999-7') WHERE FacultyID = 4;

-- Encrypt CNICs for seeded Students
UPDATE Students SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35201-0000001-1') WHERE StudentID = 1;
UPDATE Students SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35201-0000002-2') WHERE StudentID = 2;
UPDATE Students SET CNIC_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, '35201-0000003-3') WHERE StudentID = 3;

-- Encrypt BankAccount for seeded FeePayments
UPDATE FeePayments SET BankAccount_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, 'HBL-0001-2345') WHERE PaymentID = 1;
UPDATE FeePayments SET BankAccount_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, 'MCB-0002-6789') WHERE PaymentID = 2;
UPDATE FeePayments SET BankAccount_Encrypted = ENCRYPTBYPASSPHRASE(@DemoPassphrase, 'UBL-0003-1234') WHERE PaymentID = 3;
GO

-- ============================================================
-- STEP 5: Verify encryption and decryption works
-- ============================================================

DECLARE @DemoPassphrase NVARCHAR(128) = 'HiSUP_Demo_Key_2026!';

-- Show that the stored column is unreadable ciphertext
SELECT FacultyID, FirstName, CNIC_Encrypted AS 'Stored (unreadable)' FROM Faculty WHERE FacultyID = 1;

-- Show that decryption returns the original value
SELECT
    FacultyID,
    FirstName + ' ' + LastName AS FullName,
    CAST(DECRYPTBYPASSPHRASE(@DemoPassphrase, CNIC_Encrypted) AS NVARCHAR(15)) AS 'Decrypted CNIC'
FROM Faculty
WHERE FacultyID = 1;

-- Wrong passphrase returns NULL (not an error)
SELECT
    FacultyID,
    CAST(DECRYPTBYPASSPHRASE('WRONG_PASSPHRASE', CNIC_Encrypted) AS NVARCHAR(15)) AS 'Wrong key (should be NULL)'
FROM Faculty
WHERE FacultyID = 1;
GO
