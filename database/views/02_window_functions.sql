-- ============================================================
-- MODULE 6: WINDOW FUNCTIONS (at least 5 types required)
-- File: database/views/advanced_sql_window_functions.sql
-- Covers: RANK, DENSE_RANK, ROW_NUMBER, NTILE, LAG, LEAD,
--         SUM OVER (running total), AVG OVER (moving avg)
-- ============================================================

USE HiSUP_DB;
GO

-- ============================================================
-- PART A: RESULT REPORT — Rankings with RANK, DENSE_RANK, ROW_NUMBER
-- 
-- Viva difference to know:
--   ROW_NUMBER: 1,2,3,4 — no ties ever, unique per row
--   RANK:       1,2,2,4 — ties get same rank, next skips
--   DENSE_RANK: 1,2,2,3 — ties get same rank, next does NOT skip
-- ============================================================

WITH StudentGrades AS
(
    SELECT
        s.StudentID,
        s.FirstName + ' ' + s.LastName  AS StudentName,
        s.RegistrationNo,
        d.DeptName                      AS Department,
        dbo.fn_CalculateCGPA(s.StudentID) AS CGPA
    FROM dbo.Students s
    JOIN dbo.Programs p    ON s.ProgramID    = p.ProgramID
    JOIN dbo.Departments d ON p.DepartmentID = d.DepartmentID
    WHERE s.Status = 'Active'
)
SELECT
    StudentName,
    RegistrationNo,
    Department,
    CGPA,

    -- Global rankings across all students
    ROW_NUMBER()  OVER (ORDER BY CGPA DESC)                         AS GlobalRowNum,
    RANK()        OVER (ORDER BY CGPA DESC)                         AS GlobalRank,
    DENSE_RANK()  OVER (ORDER BY CGPA DESC)                         AS GlobalDenseRank,

    -- Rankings within each department (PARTITION BY = restart ranking per group)
    RANK()        OVER (PARTITION BY Department ORDER BY CGPA DESC) AS RankInDept,
    DENSE_RANK()  OVER (PARTITION BY Department ORDER BY CGPA DESC) AS DenseRankInDept,

    -- Divide students into 4 performance quartiles
    NTILE(4)      OVER (ORDER BY CGPA DESC)                         AS CGPAQuartile
    -- Quartile 1 = top 25%, Quartile 4 = bottom 25%

FROM StudentGrades
ORDER BY Department, RankInDept;
GO

-- ============================================================
-- PART B: FEE ANALYTICS — Running Total and Moving Average
-- SUM OVER and AVG OVER with ROWS BETWEEN frame
-- ============================================================

SELECT
    fp.PaymentID,
    s.RegistrationNo,
    s.FirstName + ' ' + s.LastName      AS StudentName,
    fp.AmountPaid,
    fp.PaymentDate,

    -- Running total of all payments so far (ordered by date)
    SUM(fp.AmountPaid)
        OVER (ORDER BY fp.PaymentDate
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS RunningTotal,

    -- Running total within each student (per-student cumulative)
    SUM(fp.AmountPaid)
        OVER (PARTITION BY fp.StudentID
              ORDER BY fp.PaymentDate
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS StudentRunningTotal,

    -- 3-payment moving average (last 2 rows + current)
    AVG(fp.AmountPaid)
        OVER (ORDER BY fp.PaymentDate
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)          AS Moving3Avg,

    -- Percentage of total fee collected (each payment as % of grand total)
    CAST(fp.AmountPaid * 100.0 /
         SUM(fp.AmountPaid) OVER ()
         AS DECIMAL(5,2))                                        AS PctOfTotal

FROM dbo.FeePayments fp
JOIN dbo.Students s ON fp.StudentID = s.StudentID
WHERE fp.Status = 'Completed'
ORDER BY fp.PaymentDate;
GO

-- ============================================================
-- PART C: LAG and LEAD — Fee Payment Trend Analysis
-- LAG = previous row's value, LEAD = next row's value
-- ============================================================

SELECT
    fp.PaymentID,
    s.RegistrationNo,
    fp.AmountPaid,
    fp.PaymentDate,

    -- Previous payment amount for this student
    LAG(fp.AmountPaid, 1, 0)
        OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate) AS PreviousPayment,

    -- Next payment amount for this student
    LEAD(fp.AmountPaid, 1, 0)
        OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate) AS NextPayment,

    -- Days since last payment (time gap)
    DATEDIFF(DAY,
        LAG(fp.PaymentDate)
            OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate),
        fp.PaymentDate)                                          AS DaysSinceLastPayment,

    -- Change vs previous payment (positive = paying more, negative = paying less)
    fp.AmountPaid -
        LAG(fp.AmountPaid, 1, fp.AmountPaid)
            OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate) AS PaymentChange

FROM dbo.FeePayments fp
JOIN dbo.Students s ON fp.StudentID = s.StudentID
WHERE fp.Status = 'Completed'
ORDER BY fp.StudentID, fp.PaymentDate;
GO

-- ============================================================
-- PART D: Attendance ranking using window functions
-- Shows NTILE for attendance grouping
-- ============================================================

WITH AttendanceSummary AS
(
    SELECT
        s.StudentID,
        s.FirstName + ' ' + s.LastName AS StudentName,
        s.RegistrationNo,
        e.SectionID,
        COUNT(*) FILTER_TOTAL
            -- SQL Server doesn't support FILTER, use CASE instead:
        ,COUNT(CASE WHEN ar.Status = 'Present' THEN 1 END) AS PresentCount
        ,COUNT(ar.AttendanceID)                             AS TotalClasses
    FROM dbo.Students s
    JOIN dbo.Enrollments e       ON s.StudentID     = e.StudentID
    JOIN dbo.AttendanceRecords ar ON e.EnrollmentID = ar.EnrollmentID
    GROUP BY s.StudentID, s.FirstName, s.LastName, s.RegistrationNo, e.SectionID
)
SELECT
    StudentName,
    RegistrationNo,
    SectionID,
    PresentCount,
    TotalClasses,
    CAST(PresentCount * 100.0 / NULLIF(TotalClasses, 0) AS DECIMAL(5,2)) AS AttendancePct,

    RANK() OVER (PARTITION BY SectionID ORDER BY
        CAST(PresentCount * 100.0 / NULLIF(TotalClasses, 0) AS DECIMAL(5,2)) DESC
    ) AS AttendanceRankInSection,

    NTILE(3) OVER (ORDER BY
        CAST(PresentCount * 100.0 / NULLIF(TotalClasses, 0) AS DECIMAL(5,2)) DESC
    ) AS AttendanceTertile
    -- Tertile 1 = top third (best attendance), 3 = bottom third (at risk)

FROM AttendanceSummary
ORDER BY SectionID, AttendanceRankInSection;
GO

-- ============================================================
-- PART E: Create a view wrapping the key window function query
-- (vw_StudentDashboard was already built, this is the analytics view)
-- ============================================================

CREATE OR ALTER VIEW dbo.vw_FeeAnalytics
AS
    SELECT
        fp.PaymentID,
        s.StudentID,
        s.RegistrationNo,
        s.FirstName + ' ' + s.LastName      AS StudentName,
        fp.AmountPaid,
        fp.PaymentDate,
        fp.Status,
        SUM(fp.AmountPaid)
            OVER (ORDER BY fp.PaymentDate
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal,
        RANK()
            OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate) AS PaymentSequence,
        LAG(fp.AmountPaid, 1)
            OVER (PARTITION BY fp.StudentID ORDER BY fp.PaymentDate) AS PreviousAmount
    FROM dbo.FeePayments fp
    JOIN dbo.Students s ON fp.StudentID = s.StudentID
    WHERE fp.Status = 'Completed';
GO

SELECT * FROM dbo.vw_FeeAnalytics ORDER BY PaymentDate;
GO
