-- ============================================================
-- HiSUP_DB_Script.sql
-- HITEC Smart University Portal - Full Schema
-- Run this against HiSUP_DB in SSMS
-- Tables are ordered to respect foreign key dependencies
-- ============================================================

USE HiSUP_DB;
GO

-- Drop tables if re-running this script (children first, then parents)
-- Safe to ignore errors on first run when nothing exists yet
IF OBJECT_ID('AuditLog', 'U') IS NOT NULL DROP TABLE AuditLog;
IF OBJECT_ID('UserAccounts', 'U') IS NOT NULL DROP TABLE UserAccounts;
IF OBJECT_ID('HostelAllotments', 'U') IS NOT NULL DROP TABLE HostelAllotments;
IF OBJECT_ID('Hostels', 'U') IS NOT NULL DROP TABLE Hostels;
IF OBJECT_ID('LibraryIssues', 'U') IS NOT NULL DROP TABLE LibraryIssues;
IF OBJECT_ID('LibraryItems', 'U') IS NOT NULL DROP TABLE LibraryItems;
IF OBJECT_ID('Results', 'U') IS NOT NULL DROP TABLE Results;
IF OBJECT_ID('ExamSchedule', 'U') IS NOT NULL DROP TABLE ExamSchedule;
IF OBJECT_ID('FeePayments', 'U') IS NOT NULL DROP TABLE FeePayments;
IF OBJECT_ID('FeeStructure', 'U') IS NOT NULL DROP TABLE FeeStructure;
IF OBJECT_ID('AttendanceRecords', 'U') IS NOT NULL DROP TABLE AttendanceRecords;
IF OBJECT_ID('Grades', 'U') IS NOT NULL DROP TABLE Grades;
IF OBJECT_ID('Enrollments', 'U') IS NOT NULL DROP TABLE Enrollments;
IF OBJECT_ID('Sections', 'U') IS NOT NULL DROP TABLE Sections;
IF OBJECT_ID('Courses', 'U') IS NOT NULL DROP TABLE Courses;
IF OBJECT_ID('Students', 'U') IS NOT NULL DROP TABLE Students;
IF OBJECT_ID('Staff', 'U') IS NOT NULL DROP TABLE Staff;
IF OBJECT_ID('Faculty', 'U') IS NOT NULL DROP TABLE Faculty;
IF OBJECT_ID('Programs', 'U') IS NOT NULL DROP TABLE Programs;
IF OBJECT_ID('Departments', 'U') IS NOT NULL DROP TABLE Departments;
GO

-- ============================================================
-- LEVEL 0: No foreign key dependencies
-- ============================================================

CREATE TABLE Departments (
    DepartmentID    INT PRIMARY KEY IDENTITY(1,1),
    DeptName        NVARCHAR(100) NOT NULL UNIQUE,
    DeptCode        NVARCHAR(10) NOT NULL UNIQUE,
    EstablishedYear INT CHECK (EstablishedYear >= 1990),
    CreatedAt       DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE Hostels (
    HostelID    INT PRIMARY KEY IDENTITY(1,1),
    HostelName  NVARCHAR(50) NOT NULL,
    TotalRooms  INT CHECK (TotalRooms > 0),
    Type        NVARCHAR(10) CHECK (Type IN ('Boys','Girls'))
);
GO

-- ============================================================
-- LEVEL 1: Depend on Departments
-- ============================================================

CREATE TABLE Programs (
    ProgramID       INT PRIMARY KEY IDENTITY(1,1),
    ProgramName     NVARCHAR(100) NOT NULL,
    DepartmentID    INT NOT NULL,
    DurationYears   INT CHECK (DurationYears BETWEEN 2 AND 6),
    DegreeLevel     NVARCHAR(20) CHECK (DegreeLevel IN ('BS','MS','PhD')),
    CONSTRAINT FK_Programs_Departments FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

CREATE TABLE Faculty (
    FacultyID    INT PRIMARY KEY IDENTITY(1,1),
    FirstName    NVARCHAR(50) NOT NULL,
    LastName     NVARCHAR(50) NOT NULL,
    Email        NVARCHAR(100) NOT NULL UNIQUE,
    CNIC         NVARCHAR(15),
    DepartmentID INT NOT NULL,
    Designation  NVARCHAR(50),
    HireDate     DATE,
    CONSTRAINT FK_Faculty_Departments FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE Staff (
    StaffID      INT PRIMARY KEY IDENTITY(1,1),
    FirstName    NVARCHAR(50) NOT NULL,
    LastName     NVARCHAR(50) NOT NULL,
    Email        NVARCHAR(100) UNIQUE,
    DepartmentID INT NULL,
    Role         NVARCHAR(50),
    CONSTRAINT FK_Staff_Departments FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID) ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

-- ============================================================
-- LEVEL 2: Depend on Programs / Departments
-- ============================================================

CREATE TABLE Students (
    StudentID        INT PRIMARY KEY IDENTITY(1,1),
    RegistrationNo   NVARCHAR(20) NOT NULL UNIQUE,
    FirstName        NVARCHAR(50) NOT NULL,
    LastName         NVARCHAR(50) NOT NULL,
    Email            NVARCHAR(100) UNIQUE,
    CNIC             NVARCHAR(15),
    DateOfBirth      DATE,
    ProgramID        INT NOT NULL,
    EnrollmentYear   INT CHECK (EnrollmentYear >= 2015),
    CurrentSemester  INT CHECK (CurrentSemester BETWEEN 1 AND 12),
    Status           NVARCHAR(20) DEFAULT 'Active' CHECK (Status IN ('Active','Graduated','Dropped','Suspended')),
    CONSTRAINT FK_Students_Programs FOREIGN KEY (ProgramID)
        REFERENCES Programs(ProgramID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE Courses (
    CourseID             INT PRIMARY KEY IDENTITY(1,1),
    CourseCode           NVARCHAR(10) NOT NULL UNIQUE,
    CourseTitle          NVARCHAR(100) NOT NULL,
    CreditHours          INT CHECK (CreditHours BETWEEN 1 AND 6),
    DepartmentID         INT NOT NULL,
    PrerequisiteCourseID INT NULL,
    CONSTRAINT FK_Courses_Departments FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Courses_Prerequisite FOREIGN KEY (PrerequisiteCourseID)
        REFERENCES Courses(CourseID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE FeeStructure (
    FeeStructureID  INT PRIMARY KEY IDENTITY(1,1),
    ProgramID       INT NOT NULL,
    Semester        INT CHECK (Semester BETWEEN 1 AND 12),
    TuitionFee      DECIMAL(10,2) CHECK (TuitionFee >= 0),
    LabFee          DECIMAL(10,2) DEFAULT 0,
    OtherCharges    DECIMAL(10,2) DEFAULT 0,
    EffectiveYear   INT,
    CONSTRAINT FK_FeeStructure_Programs FOREIGN KEY (ProgramID)
        REFERENCES Programs(ProgramID) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

-- ============================================================
-- LEVEL 3: Depend on Courses / Faculty / Students / Hostels
-- ============================================================

CREATE TABLE Sections (
    SectionID    INT PRIMARY KEY IDENTITY(1,1),
    CourseID     INT NOT NULL,
    FacultyID    INT NOT NULL,
    Semester     NVARCHAR(20),
    SectionCode  NVARCHAR(5),
    MaxSeats     INT CHECK (MaxSeats > 0),
    SeatsFilled  INT DEFAULT 0 CHECK (SeatsFilled >= 0),
    RoomNumber   NVARCHAR(20),
    Schedule     NVARCHAR(50),
    CONSTRAINT FK_Sections_Courses FOREIGN KEY (CourseID)
        REFERENCES Courses(CourseID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_Sections_Faculty FOREIGN KEY (FacultyID)
        REFERENCES Faculty(FacultyID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE FeePayments (
    PaymentID       INT PRIMARY KEY IDENTITY(1,1),
    StudentID       INT NOT NULL,
    FeeStructureID  INT NOT NULL,
    AmountPaid      DECIMAL(10,2) CHECK (AmountPaid > 0),
    PaymentDate     DATETIME DEFAULT GETDATE(),
    PaymentMethod   NVARCHAR(20),
    BankAccount     NVARCHAR(30),
    TransactionRef  NVARCHAR(50) UNIQUE,
    Status          NVARCHAR(20) DEFAULT 'Completed' CHECK (Status IN ('Completed','Pending','Failed','Refunded')),
    CONSTRAINT FK_FeePayments_Students FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_FeePayments_FeeStructure FOREIGN KEY (FeeStructureID)
        REFERENCES FeeStructure(FeeStructureID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE Results (
    ResultID         INT PRIMARY KEY IDENTITY(1,1),
    StudentID        INT NOT NULL,
    Semester         INT,
    SemesterGPA      DECIMAL(3,2),
    CGPA             DECIMAL(3,2),
    TotalCreditHours INT,
    ResultStatus     NVARCHAR(20) CHECK (ResultStatus IN ('Pass','Fail','Probation')),
    PublishedDate    DATETIME,
    CONSTRAINT FK_Results_Students FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

CREATE TABLE LibraryItems (
    ItemID          INT PRIMARY KEY IDENTITY(1,1),
    Title           NVARCHAR(200) NOT NULL,
    Author          NVARCHAR(100) NOT NULL,
    ISBN            NVARCHAR(20) UNIQUE,
    ItemType        NVARCHAR(20) CHECK (ItemType IN ('Book','Journal','Magazine')),
    TotalCopies     INT CHECK (TotalCopies >= 0),
    AvailableCopies INT CHECK (AvailableCopies >= 0)
);
GO

CREATE TABLE HostelAllotments (
    AllotmentID   INT PRIMARY KEY IDENTITY(1,1),
    StudentID     INT NOT NULL,
    HostelID      INT NOT NULL,
    RoomNumber    NVARCHAR(10),
    AllotmentDate DATE DEFAULT GETDATE(),
    VacateDate    DATE NULL,
    Status        NVARCHAR(20) DEFAULT 'Active' CHECK (Status IN ('Active','Vacated')),
    CONSTRAINT FK_HostelAllotments_Students FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_HostelAllotments_Hostels FOREIGN KEY (HostelID)
        REFERENCES Hostels(HostelID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

CREATE TABLE UserAccounts (
    UserID          INT PRIMARY KEY IDENTITY(1,1),
    Username        NVARCHAR(50) NOT NULL UNIQUE,
    PasswordHash    NVARCHAR(255) NOT NULL,
    Role            NVARCHAR(20) CHECK (Role IN ('Admin','Student','Faculty','Finance')),
    LinkedStudentID INT NULL,
    LinkedFacultyID INT NULL,
    LinkedStaffID   INT NULL,
    IsActive        BIT DEFAULT 1,
    CreatedAt       DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_UserAccounts_Students FOREIGN KEY (LinkedStudentID)
        REFERENCES Students(StudentID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_UserAccounts_Faculty FOREIGN KEY (LinkedFacultyID)
        REFERENCES Faculty(FacultyID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_UserAccounts_Staff FOREIGN KEY (LinkedStaffID)
        REFERENCES Staff(StaffID) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ============================================================
-- LEVEL 4: Depend on Sections / LibraryItems
-- ============================================================

CREATE TABLE Enrollments (
    EnrollmentID   INT PRIMARY KEY IDENTITY(1,1),
    StudentID      INT NOT NULL,
    SectionID      INT NOT NULL,
    EnrollmentDate DATETIME DEFAULT GETDATE(),
    Status         NVARCHAR(20) DEFAULT 'Enrolled' CHECK (Status IN ('Enrolled','Dropped','Completed')),
    CONSTRAINT FK_Enrollments_Students FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_Enrollments_Sections FOREIGN KEY (SectionID)
        REFERENCES Sections(SectionID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_Enrollments_Student_Section UNIQUE (StudentID, SectionID)
);
GO

CREATE TABLE ExamSchedule (
    ExamScheduleID INT PRIMARY KEY IDENTITY(1,1),
    SectionID      INT NOT NULL,
    ExamType       NVARCHAR(20) CHECK (ExamType IN ('Midterm','Final','Quiz')),
    ExamDate       DATE,
    StartTime      TIME,
    EndTime        TIME,
    RoomNumber     NVARCHAR(20),
    CONSTRAINT FK_ExamSchedule_Sections FOREIGN KEY (SectionID)
        REFERENCES Sections(SectionID) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

CREATE TABLE LibraryIssues (
    IssueID     INT PRIMARY KEY IDENTITY(1,1),
    ItemID      INT NOT NULL,
    StudentID   INT NULL,
    FacultyID   INT NULL,
    IssueDate   DATETIME DEFAULT GETDATE(),
    DueDate     DATE NOT NULL,
    ReturnDate  DATE NULL,
    FineAmount  DECIMAL(8,2) DEFAULT 0,
    CONSTRAINT FK_LibraryIssues_Items FOREIGN KEY (ItemID)
        REFERENCES LibraryItems(ItemID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_LibraryIssues_Students FOREIGN KEY (StudentID)
        REFERENCES Students(StudentID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_LibraryIssues_Faculty FOREIGN KEY (FacultyID)
        REFERENCES Faculty(FacultyID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CHK_LibraryIssues_Borrower CHECK (
        (StudentID IS NOT NULL AND FacultyID IS NULL) OR
        (StudentID IS NULL AND FacultyID IS NOT NULL)
    )
);
GO

-- ============================================================
-- LEVEL 5: Depend on Enrollments
-- ============================================================

CREATE TABLE Grades (
    GradeID      INT PRIMARY KEY IDENTITY(1,1),
    EnrollmentID INT NOT NULL UNIQUE,
    MarksObtained DECIMAL(5,2),
    LetterGrade  NVARCHAR(2),
    GradePoints  DECIMAL(3,2),
    GradedDate   DATETIME,
    CONSTRAINT FK_Grades_Enrollments FOREIGN KEY (EnrollmentID)
        REFERENCES Enrollments(EnrollmentID) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

CREATE TABLE AttendanceRecords (
    AttendanceID    INT PRIMARY KEY IDENTITY(1,1),
    EnrollmentID    INT NOT NULL,
    AttendanceDate  DATE NOT NULL,
    Status          NVARCHAR(10) NOT NULL CHECK (Status IN ('Present','Absent','Leave')),
    CONSTRAINT FK_AttendanceRecords_Enrollments FOREIGN KEY (EnrollmentID)
        REFERENCES Enrollments(EnrollmentID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_Attendance_Enrollment_Date UNIQUE (EnrollmentID, AttendanceDate)
);
GO

-- ============================================================
-- LEVEL 6: AuditLog (standalone, referenced by triggers later, no FK needed)
-- ============================================================

CREATE TABLE AuditLog (
    AuditID    INT PRIMARY KEY IDENTITY(1,1),
    TableName  NVARCHAR(50) NOT NULL,
    Operation  NVARCHAR(10) CHECK (Operation IN ('INSERT','UPDATE','DELETE')),
    RecordID   INT,
    OldValue   NVARCHAR(MAX) NULL,
    NewValue   NVARCHAR(MAX) NULL,
    ChangedBy  NVARCHAR(100),
    ChangedAt  DATETIME DEFAULT GETDATE()
);
GO

-- ============================================================
-- Verify: list all tables created
-- ============================================================
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;
GO
