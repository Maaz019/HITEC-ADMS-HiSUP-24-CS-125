-- ============================================================
-- trg_AfterEnrollment
-- AFTER INSERT trigger on Enrollments: increments SeatsFilled
-- on the relevant Section whenever a new enrollment is created.
-- NOTE: Once this trigger exists, EnrollInCourse's manual
-- "UPDATE Sections SET SeatsFilled = SeatsFilled + 1" line must
-- be removed - otherwise seats get double-counted. See the
-- companion fix script after all 6 triggers are built.
-- ============================================================
USE HiSUP_DB;
GO

CREATE OR ALTER TRIGGER trg_AfterEnrollment
ON Enrollments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE sec
    SET sec.SeatsFilled = sec.SeatsFilled + 1
    FROM Sections sec
    INNER JOIN inserted i ON sec.SectionID = i.SectionID
    WHERE i.Status = 'Enrolled';
END;
GO

-- ============================================================
-- Test it - this trigger fires automatically on any INSERT,
-- so we just insert directly and check the seat count changed
-- ============================================================
DECLARE @BeforeSeats INT = (SELECT SeatsFilled FROM Sections WHERE SectionID = 4);

INSERT INTO Enrollments (StudentID, SectionID, Status)
VALUES (5, 4, 'Enrolled');  -- Zainab Iqbal enrolling in section 4

DECLARE @AfterSeats INT = (SELECT SeatsFilled FROM Sections WHERE SectionID = 4);

SELECT @BeforeSeats AS SeatsBefore, @AfterSeats AS SeatsAfter;
GO
