-- ============================================================
-- trg_AfterFeePayment
-- AFTER INSERT trigger on FeePayments: this is a verification/
-- audit-style trigger. Since balance is calculated live via
-- fn_GetOutstandingFee (not stored as a column), there's no
-- "balance column" to update - instead this trigger writes a
-- confirmation entry to AuditLog so every payment leaves a
-- trace independent of the FeePayments row itself.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_AfterFeePayment
ON FeePayments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditLog (TableName, Operation, RecordID, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT
        'FeePayments',
        'INSERT',
        i.PaymentID,
        NULL,
        'StudentID=' + CAST(i.StudentID AS NVARCHAR(10)) +
            ', AmountPaid=' + CAST(i.AmountPaid AS NVARCHAR(20)) +
            ', NewOutstandingBalance=' + CAST(dbo.fn_GetOutstandingFee(i.StudentID, i.FeeStructureID) AS NVARCHAR(20)),
        SUSER_NAME(),
        GETDATE()
    FROM inserted i;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
INSERT INTO FeePayments (StudentID, FeeStructureID, AmountPaid, PaymentMethod, TransactionRef, Status)
VALUES (3, 1, 30000.00, 'Cash', 'TXN-TEST-001', 'Completed');
GO

SELECT * FROM AuditLog WHERE TableName = 'FeePayments' ORDER BY AuditID DESC;
GO
