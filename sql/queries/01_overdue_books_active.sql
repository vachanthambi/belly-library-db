-- =============================================================================
-- Query 01: Active Overdue Books
-- =============================================================================
-- Business question: Which books are currently overdue, by how many days,
--                   and how much fine is accruing per member?
-- Used by: Library staff for daily follow-up calls and emails
-- Techniques: Multi-table JOIN, julianday() date math, computed columns
-- =============================================================================

SELECT
    m.First_Name || ' ' || m.Last_Name          AS Member_Name,
    m.Email,
    b.Title,
    c.Category_Name,
    t.Borrow_Date,
    t.Due_Date,
    CAST(julianday('now') - julianday(t.Due_Date) AS INTEGER)       AS Days_Overdue,
    ROUND((julianday('now') - julianday(t.Due_Date)) * 0.50, 2)    AS Accruing_Fine_USD,
    m.Outstanding_Fines                          AS Member_Total_Owed,
    li.First_Name || ' ' || li.Last_Name        AS Checked_Out_By
FROM Transactions t
JOIN Members     m  ON t.Member_ID    = m.Member_ID
JOIN Books       b  ON t.Book_ID      = b.Book_ID
JOIN Categories  c  ON b.Category_ID  = c.Category_ID
JOIN Librarians  li ON t.Librarian_ID = li.Librarian_ID
WHERE t.Return_Date IS NULL              -- still borrowed
  AND t.Due_Date    < date('now')        -- past due date
ORDER BY Days_Overdue DESC;
