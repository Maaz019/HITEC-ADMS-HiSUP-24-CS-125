-- ============================================================
-- AllocateHostelRoom
-- Allocates a hostel room to a student, with capacity checking.
-- A student may only have ONE active allotment at a time.
-- Demonstrates: TRY/CATCH, transaction with locking, business rule
--               enforcement (one active allotment per student)
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER PROCEDURE AllocateHostelRoom
    @StudentID       INT,
    @HostelID        INT,
    @RoomNumber      NVARCHAR(10),
    @NewAllotmentID  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input validation ----
    IF NOT EXISTS (SELECT 1 FROM Students WHERE StudentID = @StudentID)
    BEGIN
        RAISERROR('StudentID %d does not exist.', 16, 1, @StudentID);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Hostels WHERE HostelID = @HostelID)
    BEGIN
        RAISERROR('HostelID %d does not exist.', 16, 1, @HostelID);
        RETURN;
    END

    IF @RoomNumber IS NULL OR LTRIM(RTRIM(@RoomNumber)) = ''
    BEGIN
        RAISERROR('RoomNumber cannot be empty.', 16, 1);
        RETURN;
    END

    -- A student cannot hold two active allotments at once
    IF EXISTS (
        SELECT 1 FROM HostelAllotments
        WHERE StudentID = @StudentID AND Status = 'Active'
    )
    BEGIN
        RAISERROR('This student already has an active hostel allotment.', 16, 1);
        RETURN;
    END

    -- A specific room in a specific hostel cannot be double-booked while active
    IF EXISTS (
        SELECT 1 FROM HostelAllotments
        WHERE HostelID = @HostelID AND RoomNumber = @RoomNumber AND Status = 'Active'
    )
    BEGIN
        RAISERROR('Room %s in this hostel is already occupied.', 16, 1, @RoomNumber);
        RETURN;
    END

    -- ---- Transaction: check hostel capacity, then allocate ----
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TotalRooms INT, @ActiveAllotments INT;

        -- Lock the hostel row while we check capacity (same race-condition
        -- protection used in EnrollInCourse for seat checking)
        SELECT @TotalRooms = TotalRooms
        FROM Hostels WITH (UPDLOCK, HOLDLOCK)
        WHERE HostelID = @HostelID;

        SELECT @ActiveAllotments = COUNT(*)
        FROM HostelAllotments
        WHERE HostelID = @HostelID AND Status = 'Active';

        IF @ActiveAllotments >= @TotalRooms
        BEGIN
            RAISERROR('No rooms available in this hostel (all %d rooms occupied).', 16, 1, @TotalRooms);
        END

        INSERT INTO HostelAllotments (StudentID, HostelID, RoomNumber, AllotmentDate, Status)
        VALUES (@StudentID, @HostelID, @RoomNumber, GETDATE(), 'Active');

        SET @NewAllotmentID = SCOPE_IDENTITY();

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
-- Test it - allocate a room to a student with no current allotment
-- ============================================================
DECLARE @NewAllotID INT;
DECLARE @TestStudentID INT = (SELECT StudentID FROM Students WHERE RegistrationNo = '24-CS-127');  -- Ayesha, no hostel yet

EXEC AllocateHostelRoom
    @StudentID = @TestStudentID,
    @HostelID = 2,
    @RoomNumber = 'F-205',
    @NewAllotmentID = @NewAllotID OUTPUT;

SELECT @NewAllotID AS NewAllotmentID;
SELECT * FROM HostelAllotments WHERE AllotmentID = @NewAllotID;
GO

-- ============================================================
-- Test error handling - student already has an active allotment
-- (Student 2 already has 'B-204' allocated in seed data)
-- ============================================================
DECLARE @NewAllotID2 INT;

BEGIN TRY
    EXEC AllocateHostelRoom
        @StudentID = 2,
        @HostelID = 1,
        @RoomNumber = 'B-310',
        @NewAllotmentID = @NewAllotID2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Caught expected error: ' + ERROR_MESSAGE();
END CATCH
GO
