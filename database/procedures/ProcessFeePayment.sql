-- ============================================================
-- ProcessFeePayment
-- Records a fee payment for a student against a fee structure
-- Demonstrates: TRY/CATCH, explicit transaction, RAISERROR/THROW,
--               input validation, balance calculation
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE ProcessFeePayment
    @StudentID       INT,
    @FeeStructureID  INT,
    @AmountPaid      DECIMAL(10,2),
    @PaymentMethod   NVARCHAR(20),
    @BankAccount     NVARCHAR(30) = NULL,
    @NewPaymentID    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM FeeStructure WHERE FeeStructureID = @FeeStructureID)
    BEGIN
        RAISERROR('FeeStructureID %d does not exist.', 16, 1, @FeeStructureID);
        RETURN;
    END

    IF @AmountPaid IS NULL OR @AmountPaid <= 0
    BEGIN
        RAISERROR('AmountPaid must be greater than zero.', 16, 1);
        RETURN;
    END

    IF @PaymentMethod NOT IN ('Bank Transfer', 'Cash', 'Online')
    BEGIN
        RAISERROR('PaymentMethod must be Bank Transfer, Cash, or Online.', 16, 1);
        RETURN;
    END

    -- ---- Calculate outstanding balance before accepting payment ----
    DECLARE @TotalFee DECIMAL(10,2);
    DECLARE @AlreadyPaid DECIMAL(10,2);
    DECLARE @OutstandingBalance DECIMAL(10,2);

    SELECT @TotalFee = TuitionFee + LabFee + OtherCharges
    FROM FeeStructure
    WHERE FeeStructureID = @FeeStructureID;

    SELECT @AlreadyPaid = ISNULL(SUM(AmountPaid), 0)
    FROM FeePayments
    WHERE StudentID = @StudentID
      AND FeeStructureID = @FeeStructureID
      AND Status = 'Completed';

    SET @OutstandingBalance = @TotalFee - @AlreadyPaid;

    IF @AmountPaid > @OutstandingBalance
    BEGIN
        RAISERROR('Payment of %d exceeds outstanding balance of %d.', 16, 1, @AmountPaid, @OutstandingBalance);
        RETURN;
    END

    -- ---- Transaction ----
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TransactionRef NVARCHAR(50) = 'TXN-' + CONVERT(NVARCHAR(20), NEWID());

        INSERT INTO FeePayments (
            StudentID, FeeStructureID, AmountPaid, PaymentMethod,
            BankAccount, TransactionRef, Status
        )
        VALUES (
            @StudentID, @FeeStructureID, @AmountPaid, @PaymentMethod,
            @BankAccount, @TransactionRef, 'Completed'
        );

        SET @NewPaymentID = SCOPE_IDENTITY();

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
-- Test it - pay remaining balance for student 1 (already paid 50000 of 95000)
-- ============================================================
DECLARE @NewPayID INT;

EXEC ProcessFeePayment
    @StudentID = 1,
    @FeeStructureID = 1,
    @AmountPaid = 20000.00,
    @PaymentMethod = 'Online',
    @BankAccount = '01234567899999',
    @NewPaymentID = @NewPayID OUTPUT;

SELECT @NewPayID AS NewPaymentID;
SELECT * FROM FeePayments WHERE PaymentID = @NewPayID;
GO

-- ============================================================
-- Test overpayment rejection - should fail
-- ============================================================
DECLARE @NewPayID2 INT;

BEGIN TRY
    EXEC ProcessFeePayment
        @StudentID = 1,
        @FeeStructureID = 1,
        @AmountPaid = 999999.00,  -- way more than outstanding balance
        @PaymentMethod = 'Cash',
        @NewPaymentID = @NewPayID2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
