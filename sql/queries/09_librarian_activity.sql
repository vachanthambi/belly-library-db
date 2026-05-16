-- =============================================================================
-- Query 09: Librarian Activity & Performance
-- =============================================================================
-- Business question: Which librarians process the most transactions?
--                   How many unique members and books has each handled?
-- Used by: Management for staffing decisions and performance reviews
-- Techniques: CTE, RANK() window function, COUNT DISTINCT, AVG with CASE
-- =============================================================================

WITH librarian_stats AS (
    SELECT
        l.Librarian_ID,
        l.First_Name || ' ' || l.Last_Name   AS Librarian_Name,
        l.Role,
        COUNT(t.Transaction_ID)               AS Total_Transactions,
        COUNT(CASE WHEN t.Return_Date IS NOT NULL THEN 1 END)   AS Returns_Processed,
        COUNT(CASE WHEN t.Return_Date IS NULL     THEN 1 END)   AS Active_Loans,
        COUNT(DISTINCT t.Member_ID)           AS Unique_Members_Served,
        COUNT(DISTINCT t.Book_ID)             AS Unique_Books_Handled,
        ROUND(AVG(
            CASE WHEN t.Return_Date IS NOT NULL
            THEN julianday(t.Return_Date) - julianday(t.Borrow_Date)
            END
        ), 1)                                 AS Avg_Loan_Duration_Days,
        ROUND(SUM(t.Fine_Amount), 2)          AS Total_Fines_On_Transactions
    FROM Librarians  l
    LEFT JOIN Transactions t ON l.Librarian_ID = t.Librarian_ID
    GROUP BY l.Librarian_ID, l.First_Name, l.Last_Name, l.Role
)

SELECT
    Librarian_Name,
    Role,
    Total_Transactions,
    Returns_Processed,
    Active_Loans,
    Unique_Members_Served,
    Unique_Books_Handled,
    Avg_Loan_Duration_Days,
    Total_Fines_On_Transactions,
    RANK() OVER (ORDER BY Total_Transactions DESC)  AS Activity_Rank
FROM librarian_stats
ORDER BY Activity_Rank;
