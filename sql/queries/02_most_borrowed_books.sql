-- =============================================================================
-- Query 02: Most Borrowed Books — Overall & By Category
-- =============================================================================
-- Business question: Which books are in highest demand? Which are the top
--                   books within each genre for acquisition decisions?
-- Used by: Acquisition team to decide which titles to buy more copies of
-- Techniques: CTE, RANK() window function, PARTITION BY category
-- =============================================================================

WITH borrow_counts AS (
    SELECT
        b.Book_ID,
        b.Title,
        b.Author,
        c.Category_Name,
        b.Availability,
        COUNT(t.Transaction_ID)  AS Borrow_Count
    FROM Books       b
    JOIN Categories  c ON b.Category_ID = c.Category_ID
    LEFT JOIN Transactions t ON b.Book_ID = t.Book_ID
    GROUP BY b.Book_ID, b.Title, b.Author, c.Category_Name, b.Availability
)

SELECT
    Title,
    Author,
    Category_Name,
    Availability,
    Borrow_Count,
    RANK() OVER (ORDER BY Borrow_Count DESC)                              AS Overall_Rank,
    RANK() OVER (PARTITION BY Category_Name ORDER BY Borrow_Count DESC)  AS Category_Rank
FROM borrow_counts
WHERE Borrow_Count > 0
ORDER BY Overall_Rank
LIMIT 25;
