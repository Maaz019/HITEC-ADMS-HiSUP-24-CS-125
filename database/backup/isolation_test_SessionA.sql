-- ============================================================
-- ISOLATION LEVEL TEST - SESSION A
-- Run this in ONE query tab. You will run it in two passes:
-- Pass 1 with READ COMMITTED, Pass 2 with SERIALIZABLE.
-- A second tab (Session B) will try to read/modify the same
-- row WHILE Session A's transaction is still open, to observe
-- the difference in behavior.
--
-- WHAT THIS DEMONSTRATES:
-- READ COMMITTED (SQL Server's default): Session B's INSERT of
--   a NEW row into the same range Session A is querying is NOT
--   blocked - this can cause a "phantom read" (Session A re-runs
--   its query and sees a row that wasn't there a moment ago).
-- SERIALIZABLE: Session B's INSERT INTO the same key-range IS
--   blocked until Session A's transaction finishes - preventing
--   phantom reads, at the cost of reduced concurrency.
-- ============================================================
USE HiSUP_DB;
GO

-- ============================================================
-- PASS 1: READ COMMITTED (the default isolation level)
-- ============================================================
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

SELECT EnrollmentID, StudentID, SectionID, Status
FROM Enrollments
WHERE SectionID = 1;

-- >>> NOW SWITCH TO SESSION B TAB AND RUN ITS "PASS 1" BLOCK <<<
-- >>> Under READ COMMITTED, Session B's INSERT should succeed
--     immediately, without waiting for Session A <<<

SELECT EnrollmentID, StudentID, SectionID, Status
FROM Enrollments
WHERE SectionID = 1;

COMMIT TRANSACTION;
GO


-- ============================================================
-- PASS 2: SERIALIZABLE (strictest isolation level)
-- Clean up any test rows from Pass 1 before starting Pass 2 if needed
-- ============================================================
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;

SELECT EnrollmentID, StudentID, SectionID, Status
FROM Enrollments
WHERE SectionID = 1;

-- >>> NOW SWITCH TO SESSION B TAB AND RUN ITS "PASS 2" BLOCK <<<
-- >>> Under SERIALIZABLE, Session B's INSERT should BLOCK / HANG
--     because Session A holds a range lock on SectionID = 1 <<<
-- >>> Session B will only proceed once Session A commits below <<<

COMMIT TRANSACTION;
-- As soon as this COMMIT runs, Session B's blocked INSERT in the
-- other tab should immediately complete
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
