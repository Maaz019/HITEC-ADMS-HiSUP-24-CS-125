-- ============================================================
-- HiSUP_DB_Seed.sql
-- Sample data for testing procedures, views, and reports
-- Run this AFTER HiSUP_DB_Script.sql
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- Departments
-- ============================================================
INSERT INTO Departments (DeptName, DeptCode, EstablishedYear) VALUES
('Computer Science', 'CS', 2000),
('Electrical Engineering', 'EE', 1998),
('Business Administration', 'BBA', 2005);
GO

-- ============================================================
-- Programs
-- ============================================================
INSERT INTO Programs (ProgramName, DepartmentID, DurationYears, DegreeLevel) VALUES
('BS Computer Science', 1, 4, 'BS'),
('BS Electrical Engineering', 2, 4, 'BS'),
('BBA Honors', 3, 4, 'BS'),
('MS Computer Science', 1, 2, 'MS');
GO

-- ============================================================
-- Faculty
-- ============================================================
INSERT INTO Faculty (FirstName, LastName, Email, CNIC, DepartmentID, Designation, HireDate) VALUES
('Shamshad', 'Bibi', 'shamshad.bibi@hitecuni.edu.pk', '3520112345671', 1, 'Lecturer', '2018-09-01'),
('Ahmed', 'Khan', 'ahmed.khan@hitecuni.edu.pk', '3520112345672', 1, 'Assistant Professor', '2015-02-15'),
('Sara', 'Malik', 'sara.malik@hitecuni.edu.pk', '3520112345673', 2, 'Associate Professor', '2012-08-20'),
('Bilal', 'Hussain', 'bilal.hussain@hitecuni.edu.pk', '3520112345674', 3, 'Lecturer', '2019-01-10');
GO

-- ============================================================
-- Staff
-- ============================================================
INSERT INTO Staff (FirstName, LastName, Email, DepartmentID, Role) VALUES
('Imran', 'Sheikh', 'imran.sheikh@hitecuni.edu.pk', NULL, 'Librarian'),
('Nadia', 'Yousaf', 'nadia.yousaf@hitecuni.edu.pk', NULL, 'Cashier'),
('Tariq', 'Aziz', 'tariq.aziz@hitecuni.edu.pk', NULL, 'Admin Officer');
GO

-- ============================================================
-- Students
-- ============================================================
INSERT INTO Students (RegistrationNo, FirstName, LastName, Email, CNIC, DateOfBirth, ProgramID, EnrollmentYear, CurrentSemester, Status) VALUES
('24-CS-125', 'Maaz', 'Ahmed', 'maaz.ahmed@student.hitecuni.edu.pk', '3520198765431', '2004-05-12', 1, 2024, 4, 'Active'),
('24-CS-126', 'Hassan', 'Raza', 'hassan.raza@student.hitecuni.edu.pk', '3520198765432', '2004-03-22', 1, 2024, 4, 'Active'),
('24-CS-127', 'Ayesha', 'Tariq', 'ayesha.tariq@student.hitecuni.edu.pk', '3520198765433', '2004-07-09', 1, 2024, 4, 'Active'),
('23-EE-091', 'Usman', 'Farooq', 'usman.farooq@student.hitecuni.edu.pk', '3520198765434', '2003-11-30', 2, 2023, 6, 'Active'),
('23-EE-092', 'Zainab', 'Iqbal', 'zainab.iqbal@student.hitecuni.edu.pk', '3520198765435', '2003-09-18', 2, 2023, 6, 'Active'),
('22-BBA-045', 'Bilal', 'Akhtar', 'bilal.akhtar@student.hitecuni.edu.pk', '3520198765436', '2002-12-05', 3, 2022, 8, 'Active');
GO

-- ============================================================
-- Courses (note: prerequisites added after base courses exist)
-- ============================================================
INSERT INTO Courses (CourseCode, CourseTitle, CreditHours, DepartmentID, PrerequisiteCourseID) VALUES
('CS-101', 'Introduction to Programming', 3, 1, NULL),
('CS-201', 'Data Structures', 3, 1, NULL),
('CS-318', 'Advanced Database Management Systems', 3, 1, NULL),
('CS-305', 'Computer Networks', 3, 1, NULL),
('CS-401', 'Artificial Intelligence', 3, 1, NULL),
('EE-101', 'Circuit Analysis', 3, 2, NULL),
('BBA-101', 'Principles of Management', 3, 3, NULL);
GO

-- Set up prerequisite chain: Data Structures requires Intro to Programming
-- AI requires Data Structures
UPDATE Courses SET PrerequisiteCourseID = (SELECT CourseID FROM Courses WHERE CourseCode = 'CS-101')
WHERE CourseCode = 'CS-201';

UPDATE Courses SET PrerequisiteCourseID = (SELECT CourseID FROM Courses WHERE CourseCode = 'CS-201')
WHERE CourseCode = 'CS-401';
GO

-- ============================================================
-- Sections
-- ============================================================
INSERT INTO Sections (CourseID, FacultyID, Semester, SectionCode, MaxSeats, SeatsFilled, RoomNumber, Schedule) VALUES
((SELECT CourseID FROM Courses WHERE CourseCode = 'CS-318'), 1, 'Spring 2026', 'A', 40, 0, 'Lab-3', 'Mon/Wed 10:00-11:30'),
((SELECT CourseID FROM Courses WHERE CourseCode = 'CS-305'), 2, 'Spring 2026', 'A', 35, 0, 'Room-204', 'Tue/Thu 09:00-10:30'),
((SELECT CourseID FROM Courses WHERE CourseCode = 'CS-401'), 2, 'Spring 2026', 'A', 30, 0, 'Lab-1', 'Mon/Wed 13:00-14:30'),
((SELECT CourseID FROM Courses WHERE CourseCode = 'CS-201'), 1, 'Spring 2026', 'B', 40, 0, 'Room-101', 'Tue/Thu 11:00-12:30');
GO

-- ============================================================
-- Enrollments
-- ============================================================
INSERT INTO Enrollments (StudentID, SectionID, Status) VALUES
(1, 1, 'Enrolled'),
(1, 2, 'Enrolled'),
(1, 3, 'Enrolled'),
(2, 1, 'Enrolled'),
(2, 2, 'Enrolled'),
(3, 1, 'Enrolled'),
(3, 4, 'Enrolled');
GO

-- Update seat counts to reflect enrollments (normally a trigger would do this - see Module 2)
UPDATE Sections SET SeatsFilled = (SELECT COUNT(*) FROM Enrollments WHERE Enrollments.SectionID = Sections.SectionID);
GO

-- ============================================================
-- Grades
-- ============================================================
INSERT INTO Grades (EnrollmentID, MarksObtained, LetterGrade, GradePoints, GradedDate) VALUES
(1, 88.50, 'A', 4.00, '2026-06-01'),
(4, 76.00, 'B+', 3.33, '2026-06-01'),
(6, 92.00, 'A', 4.00, '2026-06-01');
GO

-- ============================================================
-- AttendanceRecords
-- ============================================================
INSERT INTO AttendanceRecords (EnrollmentID, AttendanceDate, Status) VALUES
(1, '2026-06-01', 'Present'),
(1, '2026-06-03', 'Present'),
(1, '2026-06-08', 'Absent'),
(4, '2026-06-01', 'Present'),
(4, '2026-06-03', 'Absent'),
(6, '2026-06-01', 'Present');
GO

-- ============================================================
-- FeeStructure
-- ============================================================
INSERT INTO FeeStructure (ProgramID, Semester, TuitionFee, LabFee, OtherCharges, EffectiveYear) VALUES
(1, 4, 85000.00, 8000.00, 2000.00, 2026),
(2, 6, 90000.00, 10000.00, 2000.00, 2026),
(3, 8, 70000.00, 0.00, 1500.00, 2026);
GO

-- ============================================================
-- FeePayments
-- ============================================================
INSERT INTO FeePayments (StudentID, FeeStructureID, AmountPaid, PaymentMethod, BankAccount, TransactionRef, Status) VALUES
(1, 1, 50000.00, 'Bank Transfer', '01234567890123', 'TXN-0001', 'Completed'),
(2, 1, 95000.00, 'Online', '01234567890124', 'TXN-0002', 'Completed'),
(4, 2, 40000.00, 'Cash', '01234567890125', 'TXN-0003', 'Completed');
GO

-- ============================================================
-- ExamSchedule
-- ============================================================
INSERT INTO ExamSchedule (SectionID, ExamType, ExamDate, StartTime, EndTime, RoomNumber) VALUES
(1, 'Midterm', '2026-07-10', '10:00', '12:00', 'Lab-3'),
(2, 'Midterm', '2026-07-11', '09:00', '11:00', 'Room-204'),
(1, 'Final', '2026-09-15', '10:00', '13:00', 'Lab-3');
GO

-- ============================================================
-- Results
-- ============================================================
INSERT INTO Results (StudentID, Semester, SemesterGPA, CGPA, TotalCreditHours, ResultStatus, PublishedDate) VALUES
(1, 3, 3.75, 3.68, 45, 'Pass', '2026-01-15'),
(2, 3, 3.30, 3.40, 45, 'Pass', '2026-01-15'),
(4, 5, 3.90, 3.85, 75, 'Pass', '2026-01-15');
GO

-- ============================================================
-- LibraryItems
-- ============================================================
INSERT INTO LibraryItems (Title, Author, ISBN, ItemType, TotalCopies, AvailableCopies) VALUES
('Fundamentals of Database Systems', 'Elmasri and Navathe', '978-0136086208', 'Book', 5, 4),
('T-SQL Fundamentals', 'Itzik Ben-Gan', '978-1509302000', 'Book', 3, 3),
('ASP.NET Core in Action', 'Andrew Lock', '978-1617298301', 'Book', 4, 4),
('Computer Networks', 'Andrew Tanenbaum', '978-0132126953', 'Book', 6, 5);
GO

-- ============================================================
-- LibraryIssues
-- ============================================================
INSERT INTO LibraryIssues (ItemID, StudentID, FacultyID, IssueDate, DueDate, ReturnDate, FineAmount) VALUES
(1, 1, NULL, '2026-06-01', '2026-06-15', NULL, 0),
(4, 2, NULL, '2026-05-20', '2026-06-03', '2026-06-10', 70.00);
GO

-- ============================================================
-- Hostels
-- ============================================================
INSERT INTO Hostels (HostelName, TotalRooms, Type) VALUES
('Iqbal Hostel', 100, 'Boys'),
('Fatima Hostel', 80, 'Girls');
GO

-- ============================================================
-- HostelAllotments
-- ============================================================
INSERT INTO HostelAllotments (StudentID, HostelID, RoomNumber, Status) VALUES
(2, 1, 'B-204', 'Active'),
(3, 2, 'F-110', 'Active');
GO

-- ============================================================
-- UserAccounts
-- ============================================================
-- NOTE: PasswordHash values below are placeholders for seed data only.
-- Real password hashing will be handled by ASP.NET Core Identity once the app is built.
INSERT INTO UserAccounts (Username, PasswordHash, Role, LinkedStudentID, LinkedFacultyID, LinkedStaffID, IsActive) VALUES
('maaz.ahmed', 'PLACEHOLDER_HASH_1', 'Student', 1, NULL, NULL, 1),
('shamshad.bibi', 'PLACEHOLDER_HASH_2', 'Faculty', NULL, 1, NULL, 1),
('nadia.yousaf', 'PLACEHOLDER_HASH_3', 'Finance', NULL, NULL, 2, 1),
('admin', 'PLACEHOLDER_HASH_4', 'Admin', NULL, NULL, 3, 1);
GO

-- ============================================================
-- Verify row counts across all tables
-- ============================================================
SELECT 'Departments' AS TableName, COUNT(*) AS Rows FROM Departments
UNION ALL SELECT 'Programs', COUNT(*) FROM Programs
UNION ALL SELECT 'Faculty', COUNT(*) FROM Faculty
UNION ALL SELECT 'Staff', COUNT(*) FROM Staff
UNION ALL SELECT 'Students', COUNT(*) FROM Students
UNION ALL SELECT 'Courses', COUNT(*) FROM Courses
UNION ALL SELECT 'Sections', COUNT(*) FROM Sections
UNION ALL SELECT 'Enrollments', COUNT(*) FROM Enrollments
UNION ALL SELECT 'Grades', COUNT(*) FROM Grades
UNION ALL SELECT 'AttendanceRecords', COUNT(*) FROM AttendanceRecords
UNION ALL SELECT 'FeeStructure', COUNT(*) FROM FeeStructure
UNION ALL SELECT 'FeePayments', COUNT(*) FROM FeePayments
UNION ALL SELECT 'ExamSchedule', COUNT(*) FROM ExamSchedule
UNION ALL SELECT 'Results', COUNT(*) FROM Results
UNION ALL SELECT 'LibraryItems', COUNT(*) FROM LibraryItems
UNION ALL SELECT 'LibraryIssues', COUNT(*) FROM LibraryIssues
UNION ALL SELECT 'Hostels', COUNT(*) FROM Hostels
UNION ALL SELECT 'HostelAllotments', COUNT(*) FROM HostelAllotments
UNION ALL SELECT 'UserAccounts', COUNT(*) FROM UserAccounts
UNION ALL SELECT 'AuditLog', COUNT(*) FROM AuditLog;
GO
