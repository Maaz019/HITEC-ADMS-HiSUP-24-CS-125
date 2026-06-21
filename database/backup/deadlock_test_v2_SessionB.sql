-- ============================================================
-- DEADLOCK TEST v2 - SESSION B (easier timing version)
-- Run this AS SOON AS you see Session A's "YOU HAVE 15 SECONDS"
-- message. You have a comfortable 15-second window now.
-- ============================================================
USE HiSUP_DB;
GO

BEGIN TRANSACTION;

UPDATE Sections
SET RoomNumber = RoomNumber
WHERE SectionID = 1;

PRINT '>>> SESSION B: Locked Sections row 1 at ' + CONVERT(NVARCHAR(30), GETDATE(), 121);
PRINT '>>> SESSION B: Now requesting Students lock...';

UPDATE Students
SET CurrentSemester = CurrentSemester
WHERE StudentID = 1;

PRINT '>>> SESSION B: Got Students lock - completed without being the victim.';

COMMIT TRANSACTION;
GO
