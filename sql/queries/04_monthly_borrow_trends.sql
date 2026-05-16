-- =============================================================================
-- Query 04: Monthly Borrowing Trends + Rolling 3-Month Average
-- =============================================================================
-- Business question: Is borrowing activity growing or declining over time?
--                   What does the seasonal pattern look like?
-- Used by: Library director for operational planning and Power BI line charts
-- Techniques: CTE, strftime() date grouping, SUM() OVER running total,
--             AVG() OVER rolling window (3-month), ROWS BETWEEN
-- =============================================================================

WITH monthly AS (
    SELECT
        strftime('%Y-%m', Borrow_Date)               AS Month,
        COUNT(*)                                      AS Total_Borrows,
        COUNT(CASE WHEN Return_Date IS NULL
                    AND Due_Date < date('now')
               THEN 1 END)                            AS Overdue_This_Month,
        ROUND(SUM(Fine_Amount), 2)                    AS Fines_Generated
    FROM Transactions
    GROUP BY strftime('%Y-%m', Borrow_Date)
)

SELECT
    Month,
    Total_Borrows,
    Overdue_This_Month,
    Fines_Generated,

    -- Running cumulative total of all borrows since first month
    SUM(Total_Borrows)
        OVER (ORDER BY Month
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Borrows,

    -- 3-month rolling average (smooths seasonal spikes)
    ROUND(AVG(Total_Borrows)
        OVER (ORDER BY Month
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1)     AS Rolling_3mo_Avg,

    -- Month-over-month change
    Total_Borrows - LAG(Total_Borrows, 1)
        OVER (ORDER BY Month)                                    AS MoM_Change

FROM monthly
ORDER BY Month;
