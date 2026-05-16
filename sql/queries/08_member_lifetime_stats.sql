-- =============================================================================
-- Query 08: Member Lifetime Stats
-- =============================================================================
-- Business question: What is the complete borrowing and financial history
--                   for every member — useful for loyalty tiers and audits.
-- Used by: Member services; full member 360-view
-- Techniques: Multiple CTEs, COALESCE for NULLs, julianday() for avg duration,
--             two separate LEFT JOINs on aggregated CTEs
-- =============================================================================

WITH borrow_stats AS (
    SELECT
        Member_ID,
        COUNT(*)                                                           AS Total_Borrows,
        SUM(CASE WHEN Return_Date IS NOT NULL THEN 1 ELSE 0 END)          AS Books_Returned,
        SUM(CASE WHEN Return_Date IS NULL
                  AND Due_Date < date('now') THEN 1 ELSE 0 END)           AS Currently_Overdue,
        -- Average how long members actually keep books
        ROUND(AVG(
            CASE WHEN Return_Date IS NOT NULL
            THEN julianday(Return_Date) - julianday(Borrow_Date)
            END
        ), 1)                                                              AS Avg_Loan_Duration_Days,
        MIN(Borrow_Date)                                                   AS First_Borrow_Date,
        MAX(Borrow_Date)                                                   AS Last_Borrow_Date
    FROM Transactions
    GROUP BY Member_ID
),
fine_stats AS (
    SELECT
        Member_ID,
        COUNT(*)                                                                   AS Total_Fine_Events,
        ROUND(SUM(CASE WHEN Fine_Status = 'Paid'   THEN Fine_Amount ELSE 0 END), 2) AS Total_Paid,
        ROUND(SUM(CASE WHEN Fine_Status = 'Unpaid' THEN Fine_Amount ELSE 0 END), 2) AS Total_Unpaid,
        ROUND(SUM(CASE WHEN Fine_Status = 'Waived' THEN Fine_Amount ELSE 0 END), 2) AS Total_Waived
    FROM Fines
    GROUP BY Member_ID
)

SELECT
    m.First_Name || ' ' || m.Last_Name   AS Member_Name,
    m.Membership_Status,
    m.Join_Date,

    COALESCE(bs.Total_Borrows,          0)   AS Total_Borrows,
    COALESCE(bs.Books_Returned,         0)   AS Books_Returned,
    COALESCE(bs.Currently_Overdue,      0)   AS Currently_Overdue,
    COALESCE(bs.Avg_Loan_Duration_Days, 0)   AS Avg_Loan_Days,
    bs.First_Borrow_Date,
    bs.Last_Borrow_Date,

    COALESCE(fs.Total_Fine_Events,      0)   AS Fine_Events,
    COALESCE(fs.Total_Paid,             0)   AS Fines_Paid,
    COALESCE(fs.Total_Unpaid,           0)   AS Fines_Unpaid,
    COALESCE(fs.Total_Waived,           0)   AS Fines_Waived

FROM Members m
LEFT JOIN borrow_stats bs ON m.Member_ID = bs.Member_ID
LEFT JOIN fine_stats   fs ON m.Member_ID = fs.Member_ID
ORDER BY COALESCE(bs.Total_Borrows, 0) DESC;
