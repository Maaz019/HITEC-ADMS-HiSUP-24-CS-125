-- ============================================================
-- trg_AfterLibraryReturn
-- AFTER UPDATE trigger on LibraryIssues: when a row's ReturnDate
-- transitions from NULL to a real date (i.e. a book is being
-- returned), increments AvailableCopies on the corresponding
-- LibraryItems row.
--
-- IMPORTANT: ReturnLibraryBook currently does this manually too
-- ("UPDATE LibraryItems SET AvailableCopies = AvailableCopies + 1").
-- Like trg_AfterEnrollment, this will double-count once the
-- trigger exists - fixed in the companion cleanup script.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_AfterLibraryReturn
ON LibraryIssues
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only fire the copy-count increment when ReturnDate just
    -- changed from NULL to NOT NULL (i.e. this update IS a return,
    -- not some other unrelated field edit)
    UPDATE li
    SET li.AvailableCopies = li.AvailableCopies + 1
    FROM LibraryItems li
    INNER JOIN inserted i ON li.ItemID = i.ItemID
    INNER JOIN deleted d ON i.IssueID = d.IssueID
    WHERE d.ReturnDate IS NULL
      AND i.ReturnDate IS NOT NULL;
END;
GO

-- ============================================================
-- Test it
-- ============================================================
DECLARE @TestIssueID INT;

INSERT INTO LibraryIssues (ItemID, StudentID, IssueDate, DueDate, ReturnDate, FineAmount)
VALUES (1, 2, GETDATE(), DATEADD(DAY, 14, GETDATE()), NULL, 0);

SET @TestIssueID = SCOPE_IDENTITY();

SELECT AvailableCopies AS CopiesBeforeReturn FROM LibraryItems WHERE ItemID = 1;

UPDATE LibraryIssues SET ReturnDate = GETDATE() WHERE IssueID = @TestIssueID;

SELECT AvailableCopies AS CopiesAfterReturn FROM LibraryItems WHERE ItemID = 1;
GO
