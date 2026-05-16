-- =============================================================================
-- Query 06: Top Delinquent Members
-- =============================================================================
-- Business question: Which members have the highest unpaid fines and should
--                   have their borrowing privileges suspended?
-- Used by: Staff for collections outreach; policy enforcement
-- Techniques: CTE, RANK() window function, HAVING clause, CASE WHEN flags
-- =============================================================================

WITH unpaid_summary AS (
    SELECT
        f.Member_ID,
        COUNT(*)                        AS Unpaid_Fine_Count,
        ROUND(SUM(f.Fine_Amount), 2)    AS Total_Unpaid,
        ROUND(AVG(f.Fine_Amount), 2)    AS Avg_Fine_Amount,
        ROUND(MAX(f.Fine_Amount), 2)    AS Largest_Single_Fine,
        MIN(t.Due_Date)                 AS Earliest_Overdue_Date
    FROM Fines f
    JOIN Transactions t ON f.Transaction_ID = t.Transaction_ID
    WHERE f.Fine_Status = 'Unpaid'
    GROUP BY f.Member_ID
    HAVING SUM(f.Fine_Amount) > 0
)

SELECT
    m.First_Name || ' ' || m.Last_Name  AS Member_Name,
    m.Email,
    m.Membership_Status,
    u.Unpaid_Fine_Count,
    u.Total_Unpaid,
    u.Avg_Fine_Amount,
    u.Largest_Single_Fine,
    u.Earliest_Overdue_Date,
    CASE
        WHEN u.Total_Unpaid > 20 THEN 'Suspend immediately'
        WHEN u.Total_Unpaid > 10 THEN 'Borrowing blocked'
        WHEN u.Total_Unpaid >  5 THEN 'Send final notice'
        ELSE 'Send reminder'
    END                                  AS Recommended_Action,
    RANK() OVER (ORDER BY u.Total_Unpaid DESC)  AS Delinquency_Rank
FROM unpaid_summary u
JOIN Members m ON u.Member_ID = m.Member_ID
ORDER BY u.Total_Unpaid DESC
LIMIT 20;
