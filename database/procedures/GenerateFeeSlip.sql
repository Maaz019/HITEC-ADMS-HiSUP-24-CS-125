-- ============================================================
-- GenerateFeeSlip
-- Generates a fee slip for a student against a fee structure:
-- itemized charges, total paid so far, and outstanding balance.
-- Demonstrates: calculation logic reused from ProcessFeePayment,
--               read-only reporting procedure
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE GenerateFeeSlip
    @StudentID       INT,
    @FeeStructureID  INT
AS
BEGIN
    SET NOCOUNT ON;

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

    -- ---- Student + program header ----
    SELECT
        s.StudentID,
        s.RegistrationNo,
        s.FirstName,
        s.LastName,
        p.ProgramName,
        fs.Semester,
        fs.EffectiveYear
    FROM Students s
    INNER JOIN Programs p ON s.ProgramID = p.ProgramID
    INNER JOIN FeeStructure fs ON fs.FeeStructureID = @FeeStructureID
    WHERE s.StudentID = @StudentID;

    -- ---- Itemized charges and balance ----
    DECLARE @TuitionFee DECIMAL(10,2), @LabFee DECIMAL(10,2), @OtherCharges DECIMAL(10,2);
    DECLARE @TotalFee DECIMAL(10,2), @AlreadyPaid DECIMAL(10,2), @OutstandingBalance DECIMAL(10,2);

    SELECT @TuitionFee = TuitionFee, @LabFee = LabFee, @OtherCharges = OtherCharges
    FROM FeeStructure
    WHERE FeeStructureID = @FeeStructureID;

    SET @TotalFee = @TuitionFee + @LabFee + @OtherCharges;

    SELECT @AlreadyPaid = ISNULL(SUM(AmountPaid), 0)
    FROM FeePayments
    WHERE StudentID = @StudentID AND FeeStructureID = @FeeStructureID AND Status = 'Completed';

    SET @OutstandingBalance = @TotalFee - @AlreadyPaid;

    SELECT
        @TuitionFee AS TuitionFee,
        @LabFee AS LabFee,
        @OtherCharges AS OtherCharges,
        @TotalFee AS TotalFee,
        @AlreadyPaid AS AmountPaidSoFar,
        @OutstandingBalance AS OutstandingBalance;

    -- ---- Payment history for this fee structure ----
    SELECT PaymentID, AmountPaid, PaymentDate, PaymentMethod, TransactionRef, Status
    FROM FeePayments
    WHERE StudentID = @StudentID AND FeeStructureID = @FeeStructureID
    ORDER BY PaymentDate;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
EXEC GenerateFeeSlip @StudentID = 1, @FeeStructureID = 1;
GO

-- ============================================================
-- Test error handling - non-existent fee structure
-- ============================================================
BEGIN TRY
    EXEC GenerateFeeSlip @StudentID = 1, @FeeStructureID = 9999;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
