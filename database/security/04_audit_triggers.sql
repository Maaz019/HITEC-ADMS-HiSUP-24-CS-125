-- ============================================================
-- MODULE 5: AUDIT LOG TRIGGERS
-- File: database/security/04_audit_triggers.sql
-- Every INSERT/UPDATE/DELETE on Students, FeePayments, Grades
-- must be recorded in AuditLog with old value, new value,
-- DB user, and timestamp.
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- Trigger 1: Audit Students table (INSERT / UPDATE / DELETE)
-- ============================================================

CREATE OR ALTER TRIGGER trg_AuditStudents
ON dbo.Students
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Operation NVARCHAR(10);

    -- Determine operation type by checking inserted/deleted row counts
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';

    -- For INSERT: OldValue is NULL, NewValue is the new row as JSON-like string
    -- For DELETE: OldValue is the deleted row, NewValue is NULL
    -- For UPDATE: OldValue is before, NewValue is after
    INSERT INTO dbo.AuditLog
        (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT
        'Students',
        @Operation,
        COALESCE(i.StudentID, d.StudentID),
        -- OldValue: from deleted pseudo-table
        CASE WHEN d.StudentID IS NOT NULL THEN
            'StudentID=' + CAST(d.StudentID AS NVARCHAR) +
            '|Name='  + ISNULL(d.FirstName, '') + ' ' + ISNULL(d.LastName, '') +
            '|Email=' + ISNULL(d.Email, '') +
            '|Status='+ ISNULL(d.Status, '') +
            '|ProgramID=' + CAST(ISNULL(d.ProgramID, 0) AS NVARCHAR)
        END,
        -- NewValue: from inserted pseudo-table
        CASE WHEN i.StudentID IS NOT NULL THEN
            'StudentID=' + CAST(i.StudentID AS NVARCHAR) +
            '|Name='  + ISNULL(i.FirstName, '') + ' ' + ISNULL(i.LastName, '') +
            '|Email=' + ISNULL(i.Email, '') +
            '|Status='+ ISNULL(i.Status, '') +
            '|ProgramID=' + CAST(ISNULL(i.ProgramID, 0) AS NVARCHAR)
        END,
        SUSER_NAME(),   -- the SQL Server login that made the change
        GETDATE()
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.StudentID = d.StudentID;
END
GO

-- ============================================================
-- Trigger 2: Audit FeePayments table
-- ============================================================

CREATE OR ALTER TRIGGER trg_AuditFeePayments
ON dbo.FeePayments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Operation NVARCHAR(10);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';

    INSERT INTO dbo.AuditLog
        (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT
        'FeePayments',
        @Operation,
        COALESCE(i.PaymentID, d.PaymentID),
        CASE WHEN d.PaymentID IS NOT NULL THEN
            'PaymentID=' + CAST(d.PaymentID AS NVARCHAR) +
            '|StudentID=' + CAST(d.StudentID AS NVARCHAR) +
            '|Amount=' + CAST(d.AmountPaid AS NVARCHAR) +
            '|Status=' + ISNULL(d.Status, '') +
            '|Date=' + CONVERT(NVARCHAR, d.PaymentDate, 120)
        END,
        CASE WHEN i.PaymentID IS NOT NULL THEN
            'PaymentID=' + CAST(i.PaymentID AS NVARCHAR) +
            '|StudentID=' + CAST(i.StudentID AS NVARCHAR) +
            '|Amount=' + CAST(i.AmountPaid AS NVARCHAR) +
            '|Status=' + ISNULL(i.Status, '') +
            '|Date=' + CONVERT(NVARCHAR, i.PaymentDate, 120)
        END,
        SUSER_NAME(),
        GETDATE()
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.PaymentID = d.PaymentID;
END
GO

-- ============================================================
-- Trigger 3: Audit Grades table
-- ============================================================

CREATE OR ALTER TRIGGER trg_AuditGrades
ON dbo.Grades
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Operation NVARCHAR(10);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Operation = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Operation = 'INSERT';
    ELSE
        SET @Operation = 'DELETE';

    INSERT INTO dbo.AuditLog
        (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT
        'Grades',
        @Operation,
        COALESCE(i.GradeID, d.GradeID),
        CASE WHEN d.GradeID IS NOT NULL THEN
            'GradeID=' + CAST(d.GradeID AS NVARCHAR) +
            '|EnrollmentID=' + CAST(d.EnrollmentID AS NVARCHAR) +
            '|Marks=' + CAST(ISNULL(d.MarksObtained, 0) AS NVARCHAR) +
            '|Letter=' + ISNULL(d.LetterGrade, '') +
            '|GradePoints=' + CAST(ISNULL(d.GradePoints, 0) AS NVARCHAR)
        END,
        CASE WHEN i.GradeID IS NOT NULL THEN
            'GradeID=' + CAST(i.GradeID AS NVARCHAR) +
            '|EnrollmentID=' + CAST(i.EnrollmentID AS NVARCHAR) +
            '|Marks=' + CAST(ISNULL(i.MarksObtained, 0) AS NVARCHAR) +
            '|Letter=' + ISNULL(i.LetterGrade, '') +
            '|GradePoints=' + CAST(ISNULL(i.GradePoints, 0) AS NVARCHAR)
        END,
        SUSER_NAME(),
        GETDATE()
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.GradeID = d.GradeID;
END
GO

-- ============================================================
-- VERIFICATION: Trigger a change and check AuditLog
-- ============================================================

-- Update a student status (should appear in AuditLog)
UPDATE Students SET Status = 'Active' WHERE StudentID = 1;

-- Check the audit entry was created
SELECT TOP 5 * FROM AuditLog ORDER BY AuditID DESC;
GO
