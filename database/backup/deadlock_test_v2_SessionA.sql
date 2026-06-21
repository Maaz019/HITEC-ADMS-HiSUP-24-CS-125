-- ============================================================
-- DEADLOCK TEST v2 - SESSION A (easier timing version)
-- Delay extended to 15 seconds to give you a comfortable
-- window to switch tabs and run Session B.
-- ============================================================
USE HiSUP_DB;
GO

BEGIN TRANSACTION;

UPDATE Students
SET CurrentSemester = CurrentSemester
WHERE StudentID = 1;

PRINT '>>> SESSION A: Locked Students row 1 at ' + CONVERT(NVARCHAR(30), GETDATE(), 121);
PRINT '>>> YOU HAVE 15 SECONDS - GO RUN SESSION B NOW <<<';

WAITFOR DELAY '00:00:15';

PRINT '>>> SESSION A: Now requesting Sections lock at ' + CONVERT(NVARCHAR(30), GETDATE(), 121);

UPDATE Sections
SET RoomNumber = RoomNumber
WHERE SectionID = 1;

PRINT '>>> SESSION A: Got Sections lock - completed without being the victim.';

COMMIT TRANSACTION;
GO
