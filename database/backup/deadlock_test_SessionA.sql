-- ============================================================
-- DEADLOCK SIMULATION - SESSION A
-- Run in ONE query tab. Locks Students row first, then tries
-- to lock a Sections row. Session B (in the other tab) will do
-- the OPPOSITE order - Sections first, then Students - which is
-- exactly what creates a deadlock: each session ends up waiting
-- on a resource the other one is holding.
--
-- HOW TO RUN:
-- 1. Run this entire Session A script
-- 2. Run Session B's entire script in a second tab IMMEDIATELY after
--    (within a few seconds, before either commits)
-- 3. SQL Server's deadlock monitor will detect the cycle and pick
--    one session as the "deadlock victim" - that session's
--    transaction gets automatically rolled back with Error 1205,
--    while the other session proceeds normally.
-- ============================================================
USE HiSUP_DB;
GO

BEGIN TRANSACTION;

UPDATE Students
SET CurrentSemester = CurrentSemester
WHERE StudentID = 1;

PRINT 'Session A: locked Students row 1. Waiting 5 seconds before requesting Sections lock...';
WAITFOR DELAY '00:00:05';

UPDATE Sections
SET RoomNumber = RoomNumber
WHERE SectionID = 1;

PRINT 'Session A: got Sections lock too - no deadlock occurred on this run.';

COMMIT TRANSACTION;
GO
