-- =============================================================================
-- Query 07: Category Inventory Health
-- =============================================================================
-- Business question: Which categories have low availability? Where are
--                   books going missing (Lost status)?
-- Used by: Inventory management; Power BI stacked bar chart
-- Techniques: Conditional aggregation, ROUND, multiple CASE WHEN,
--             LEFT JOIN to include categories with zero transactions
-- =============================================================================

SELECT
    c.Category_Name,
    COUNT(b.Book_ID)                                                            AS Total_Books,

    SUM(CASE WHEN b.Availability = 'Available' THEN 1 ELSE 0 END)              AS Available,
    SUM(CASE WHEN b.Availability = 'Borrowed'  THEN 1 ELSE 0 END)              AS Borrowed,
    SUM(CASE WHEN b.Availability = 'Reserved'  THEN 1 ELSE 0 END)              AS Reserved,
    SUM(CASE WHEN b.Availability = 'Lost'      THEN 1 ELSE 0 END)              AS Lost,

    -- What % of stock is available right now
    ROUND(
        SUM(CASE WHEN b.Availability = 'Available' THEN 1.0 ELSE 0 END)
        * 100.0 / COUNT(b.Book_ID),
    1)                                                                          AS Availability_Pct,

    -- How many times has any book in this category been borrowed (all time)
    COUNT(t.Transaction_ID)                                                     AS Total_Borrows_Alltime,

    -- Average borrows per book in this category
    ROUND(COUNT(t.Transaction_ID) * 1.0 / COUNT(b.Book_ID), 1)                AS Avg_Borrows_Per_Book

FROM Categories  c
LEFT JOIN Books        b ON c.Category_ID = b.Category_ID
LEFT JOIN Transactions t ON b.Book_ID     = t.Book_ID
GROUP BY c.Category_ID, c.Category_Name
ORDER BY Total_Borrows_Alltime DESC;
