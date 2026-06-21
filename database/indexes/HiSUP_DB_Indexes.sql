-- ============================================================
-- HiSUP_DB Indexes
-- 6+ non-clustered indexes as required by Module 3, including
-- one filtered index and one covering index.
-- Primary key clustered indexes already exist automatically
-- on every table (created via PRIMARY KEY in the schema script).
-- ============================================================
USE HiSUP_DB;
GO

-- ---- 1. Enrollments.StudentID ----
CREATE NONCLUSTERED INDEX IX_Enrollments_StudentID
ON Enrollments (StudentID);
GO

-- ---- 2. Enrollments.SectionID ----
CREATE NONCLUSTERED INDEX IX_Enrollments_SectionID
ON Enrollments (SectionID);
GO

-- ---- 3. FeePayments.PaymentDate - explicitly required by the brief ----
CREATE NONCLUSTERED INDEX IX_FeePayments_PaymentDate
ON FeePayments (PaymentDate);
GO

-- ---- 4. LibraryIssues.ReturnDate - explicitly required by the brief ----
CREATE NONCLUSTERED INDEX IX_LibraryIssues_ReturnDate
ON LibraryIssues (ReturnDate);
GO

-- ---- 5. AttendanceRecords (EnrollmentID, AttendanceDate) -
--         explicitly required by the brief (grouped by student+date) ----
CREATE NONCLUSTERED INDEX IX_AttendanceRecords_Enrollment_Date
ON AttendanceRecords (EnrollmentID, AttendanceDate);
GO

-- ---- 6. FILTERED INDEX (required): only ACTIVE hostel allotments ----
CREATE NONCLUSTERED INDEX IX_HostelAllotments_Active
ON HostelAllotments (StudentID, HostelID)
WHERE Status = 'Active';
GO

-- ---- 7. COVERING INDEX (required): FeePayments lookups that
--         also need AmountPaid without a base-table lookup ----
CREATE NONCLUSTERED INDEX IX_FeePayments_Covering
ON FeePayments (StudentID, FeeStructureID, Status)
INCLUDE (AmountPaid);
GO

-- ---- 8. Courses.DepartmentID ----
CREATE NONCLUSTERED INDEX IX_Courses_DepartmentID
ON Courses (DepartmentID);
GO

-- ============================================================
-- Verify all indexes were created
-- ============================================================
SELECT
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc,
    i.is_unique,
    i.has_filter,
    i.filter_definition
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.name LIKE 'IX_%'
ORDER BY t.name, i.name;
GO
