-- =============================================================================
-- Query 05: Fine Collection Analysis
-- =============================================================================
-- Business question: How much money is owed vs collected vs waived?
--                   What types of fines are most common?
-- Used by: Finance team for revenue reporting and Power BI KPI cards
-- Techniques: CTE, CASE WHEN aggregation, cross-join for percentages,
--             multiple GROUP BY dimensions
-- =============================================================================

WITH fine_breakdown AS (
    SELECT
        Fine_Status,
        Fine_Type,
        COUNT(*)                        AS Fine_Count,
        ROUND(SUM(Fine_Amount),  2)     AS Total_Amount,
        ROUND(AVG(Fine_Amount),  2)     AS Avg_Fine,
        ROUND(MAX(Fine_Amount),  2)     AS Largest_Fine,
        ROUND(MIN(Fine_Amount),  2)     AS Smallest_Fine
    FROM Fines
    GROUP BY Fine_Status, Fine_Type
),
grand_total AS (
    SELECT ROUND(SUM(Fine_Amount), 2) AS All_Fines_Total
    FROM Fines
)

SELECT
    fb.Fine_Status,
    fb.Fine_Type,
    fb.Fine_Count,
    fb.Total_Amount,
    fb.Avg_Fine,
    fb.Largest_Fine,
    ROUND(fb.Total_Amount * 100.0 / gt.All_Fines_Total, 1)  AS Pct_Of_Total
FROM fine_breakdown fb
CROSS JOIN grand_total gt
ORDER BY fb.Fine_Status, fb.Total_Amount DESC;
