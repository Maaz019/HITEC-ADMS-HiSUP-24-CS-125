-- ============================================================
-- trg_AuditStudentUpdate
-- AFTER UPDATE trigger on Students: writes old and new values
-- to AuditLog whenever a student row is updated. This is the
-- core audit mechanism required by Module 5 (Security) for the
-- Students table specifically.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_AuditStudentUpdate
ON Students
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditLog (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT
        'Students',
        'UPDATE',
        d.StudentID,
        'FirstName=' + d.FirstName + ', LastName=' + d.LastName +
            ', Email=' + d.Email + ', Status=' + d.Status,
        'FirstName=' + i.FirstName + ', LastName=' + i.LastName +
            ', Email=' + i.Email + ', Status=' + i.Status,
        SUSER_NAME(),
        GETDATE()
    FROM deleted d
    INNER JOIN inserted i ON d.StudentID = i.StudentID;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
UPDATE Students SET Status = 'Suspended' WHERE StudentID = 6;
GO

SELECT * FROM AuditLog WHERE TableName = 'Students' ORDER BY AuditID DESC;
GO

-- Revert the test change
UPDATE Students SET Status = 'Active' WHERE StudentID = 6;
GO
