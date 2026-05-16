-- =============================================================================
-- Query 10: Reservation Fulfillment Rate by Category
-- =============================================================================
-- Business question: Which genres have the best/worst reservation success rate?
--                   High cancellation or expiry suggests stock shortages.
-- Used by: Acquisition team; Power BI bar chart for dashboard
-- Techniques: CTE, conditional aggregation, RANK() window function,
--             percentage calculation, multi-table JOIN chain
-- =============================================================================

WITH reservation_stats AS (
    SELECT
        c.Category_Name,
        COUNT(r.Reservation_ID)                                               AS Total_Reservations,
        SUM(CASE WHEN r.Status = 'Fulfilled' THEN 1 ELSE 0 END)              AS Fulfilled,
        SUM(CASE WHEN r.Status = 'Pending'   THEN 1 ELSE 0 END)              AS Pending,
        SUM(CASE WHEN r.Status = 'Cancelled' THEN 1 ELSE 0 END)              AS Cancelled,
        SUM(CASE WHEN r.Status = 'Expired'   THEN 1 ELSE 0 END)              AS Expired
    FROM Reservations r
    JOIN Books       b ON r.Book_ID      = b.Book_ID
    JOIN Categories  c ON b.Category_ID  = c.Category_ID
    GROUP BY c.Category_Name
)

SELECT
    Category_Name,
    Total_Reservations,
    Fulfilled,
    Pending,
    Cancelled,
    Expired,
    ROUND(Fulfilled  * 100.0 / Total_Reservations, 1)  AS Fulfillment_Rate_Pct,
    ROUND(Cancelled  * 100.0 / Total_Reservations, 1)  AS Cancellation_Rate_Pct,
    ROUND(Expired    * 100.0 / Total_Reservations, 1)  AS Expiry_Rate_Pct,
    RANK() OVER (ORDER BY Fulfilled * 100.0 / Total_Reservations DESC)   AS Fulfillment_Rank
FROM reservation_stats
ORDER BY Fulfillment_Rate_Pct DESC;
