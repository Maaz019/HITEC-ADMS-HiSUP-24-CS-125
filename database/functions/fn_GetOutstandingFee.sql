-- ============================================================
-- fn_GetOutstandingFee
-- Scalar UDF: returns the outstanding fee balance for a student
-- against a specific fee structure (total charges minus completed
-- payments). Formalizes the balance logic used inline in
-- ProcessFeePayment and GenerateFeeSlip.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER FUNCTION fn_GetOutstandingFee (@StudentID INT, @FeeStructureID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
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

    SET @OutstandingBalance = ISNULL(@TotalFee, 0) - ISNULL(@AlreadyPaid, 0);

    RETURN @OutstandingBalance;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
SELECT dbo.fn_GetOutstandingFee(1, 1) AS OutstandingBalance_Student1;
SELECT dbo.fn_GetOutstandingFee(2, 1) AS OutstandingBalance_Student2;
GO

-- Test against all fee structures at once - useful for vw_FeeDefaulters later
SELECT
    s.StudentID,
    s.RegistrationNo,
    fs.FeeStructureID,
    dbo.fn_GetOutstandingFee(s.StudentID, fs.FeeStructureID) AS OutstandingBalance
FROM Students s
CROSS JOIN FeeStructure fs
WHERE dbo.fn_GetOutstandingFee(s.StudentID, fs.FeeStructureID) > 0;
GO
