-- =============================================================================
-- Query 03: Member Borrowing Leaderboard
-- =============================================================================
-- Business question: Who are our most active members? Who has the worst
--                   fine record? Useful for loyalty programs and risk flagging.
-- Used by: Member services team
-- Techniques: CTE, RANK() on multiple dimensions, CASE WHEN, LEFT JOIN
-- =============================================================================

WITH member_stats AS (
    SELECT
        m.Member_ID,
        m.First_Name || ' ' || m.Last_Name  AS Member_Name,
        m.Email,
        m.Membership_Status,
        m.Join_Date,
        COUNT(t.Transaction_ID)                                                        AS Total_Borrowed,
        SUM(CASE WHEN t.Return_Date IS NULL AND t.Due_Date < date('now') THEN 1
                 ELSE 0 END)                                                           AS Currently_Overdue,
        ROUND(SUM(COALESCE(t.Fine_Amount, 0)), 2)                                     AS Total_Fines_Incurred,
        m.Outstanding_Fines                                                            AS Unpaid_Balance,
        CASE
            WHEN m.Outstanding_Fines  > 10 THEN 'Blocked'
            WHEN m.Outstanding_Fines  > 0  THEN 'Has Balance'
            ELSE 'Clear'
        END                                                                            AS Borrowing_Eligibility
    FROM Members m
    LEFT JOIN Transactions t ON m.Member_ID = t.Member_ID
    GROUP BY m.Member_ID, m.First_Name, m.Last_Name, m.Email,
             m.Membership_Status, m.Join_Date, m.Outstanding_Fines
)

SELECT
    Member_Name,
    Membership_Status,
    Total_Borrowed,
    Currently_Overdue,
    Total_Fines_Incurred,
    Unpaid_Balance,
    Borrowing_Eligibility,
    RANK() OVER (ORDER BY Total_Borrowed      DESC)  AS Activity_Rank,
    RANK() OVER (ORDER BY Total_Fines_Incurred DESC) AS Fine_Risk_Rank
FROM member_stats
ORDER BY Activity_Rank
LIMIT 20;
