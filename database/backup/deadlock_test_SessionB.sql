-- ============================================================
-- DEADLOCK SIMULATION - SESSION B
-- Run this in a SECOND tab IMMEDIATELY after starting Session A
-- (within the 5-second WAITFOR DELAY window in Session A).
-- This locks in the OPPOSITE order to Session A: Sections first,
-- then Students - completing the deadlock cycle.
-- ============================================================
USE HiSUP_DB;
GO

BEGIN TRANSACTION;

UPDATE Sections
SET RoomNumber = RoomNumber
WHERE SectionID = 1;

PRINT 'Session B: locked Sections row 1. Now requesting Students lock...';

UPDATE Students
SET CurrentSemester = CurrentSemester
WHERE StudentID = 1;

PRINT 'Session B: got Students lock too - no deadlock occurred on this run.';

COMMIT TRANSACTION;
GO
