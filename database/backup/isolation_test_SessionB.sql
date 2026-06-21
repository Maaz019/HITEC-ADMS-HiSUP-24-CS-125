-- ============================================================
-- ISOLATION LEVEL TEST - SESSION B
-- Run this in a SECOND, separate query tab while Session A
-- (isolation_test_SessionA.sql) has an open transaction.
-- ============================================================
USE HiSUP_DB;
GO

-- ============================================================
-- PASS 1 block - run this WHILE Session A's Pass 1 transaction
-- is open (after Session A's first SELECT, before its second).
-- Expected: this INSERT completes immediately, no waiting.
-- ============================================================
INSERT INTO Enrollments (StudentID, SectionID, Status)
VALUES (5, 1, 'Enrolled');

SELECT GETDATE() AS Pass1_InsertCompletedAt;
GO


-- ============================================================
-- PASS 2 block - run this WHILE Session A's Pass 2 (SERIALIZABLE)
-- transaction is open (after Session A's SELECT, before its COMMIT).
-- Expected: this INSERT will BLOCK / spin with no result until
-- Session A's COMMIT runs in the other tab.
-- ============================================================
INSERT INTO Enrollments (StudentID, SectionID, Status)
VALUES (4, 1, 'Enrolled');

SELECT GETDATE() AS Pass2_InsertCompletedAt;
GO


-- ============================================================
-- Cleanup - remove the test rows inserted above once done
-- ============================================================
-- DELETE FROM Enrollments WHERE StudentID IN (4, 5) AND SectionID = 1;
-- GO
