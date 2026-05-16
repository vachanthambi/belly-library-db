"""
export_for_powerbi.py — Belly Library Management System
=========================================================
Exports data from library.db into clean CSV files for Power BI.

Run from the project root folder:
    py scripts/export_for_powerbi.py

Output: powerbi_data/ folder with 7 CSV files
Re-run any time to refresh the data.
"""

import os
import sqlite3
import csv

DB_PATH    = os.path.join("data", "library.db")
OUTPUT_DIR = "powerbi_data"

# ── Helper ────────────────────────────────────────────────────────────────────

def export_query(conn, filename, sql, description):
    """Run a SQL query and write results to a CSV file."""
    cur = conn.cursor()
    cur.execute(sql)
    rows    = cur.fetchall()
    headers = [d[0] for d in cur.description]

    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    print(f"  ✓ {filename:<35} {len(rows):>5} rows  — {description}")

# ── Export definitions ────────────────────────────────────────────────────────

def main():
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(
            f"Database not found: {DB_PATH}\n"
            "Run scripts/seed_data.py first."
        )

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")

    print("\nBelly Library — Power BI Export")
    print("=" * 55)
    print(f"Exporting to: {OUTPUT_DIR}/\n")

    # ── 1. Books (with category + publisher names) ────────────────────────────
    export_query(conn, "books.csv", """
        SELECT
            b.Book_ID,
            b.Title,
            b.Author,
            b.ISBN,
            b.Edition,
            b.Year            AS Publication_Year,
            c.Category_Name,
            p.Publisher_Name,
            b.Availability
        FROM Books b
        JOIN Categories  c ON b.Category_ID  = c.Category_ID
        JOIN Publishers  p ON b.Publisher_ID  = p.Publisher_ID
        ORDER BY b.Book_ID
    """, "book catalog with category & publisher")

    # ── 2. Members ────────────────────────────────────────────────────────────
    export_query(conn, "members.csv", """
        SELECT
            Member_ID,
            First_Name || ' ' || Last_Name  AS Member_Name,
            Email,
            Membership_Status,
            Outstanding_Fines,
            Join_Date,
            CASE
                WHEN Outstanding_Fines > 10 THEN 'Blocked'
                WHEN Outstanding_Fines > 0  THEN 'Has Balance'
                ELSE 'Clear'
            END                             AS Borrowing_Status
        FROM Members
        ORDER BY Member_ID
    """, "member roster with eligibility flag")

    # ── 3. Transactions (full detail) ─────────────────────────────────────────
    export_query(conn, "transactions.csv", """
        SELECT
            t.Transaction_ID,
            m.First_Name || ' ' || m.Last_Name   AS Member_Name,
            b.Title                               AS Book_Title,
            c.Category_Name,
            li.First_Name || ' ' || li.Last_Name AS Librarian_Name,
            t.Borrow_Date,
            t.Due_Date,
            t.Return_Date,
            CASE WHEN t.Return_Date IS NULL THEN 'Active' ELSE 'Returned' END
                                                  AS Loan_Status,
            t.Return_Condition,
            t.Fine_Amount,
            CASE
                WHEN t.Return_Date IS NULL AND t.Due_Date < date('now')
                THEN CAST(julianday('now') - julianday(t.Due_Date) AS INTEGER)
                WHEN t.Return_Date > t.Due_Date
                THEN CAST(julianday(t.Return_Date) - julianday(t.Due_Date) AS INTEGER)
                ELSE 0
            END                                   AS Days_Overdue,
            strftime('%Y', t.Borrow_Date)         AS Borrow_Year,
            strftime('%Y-%m', t.Borrow_Date)      AS Borrow_Month
        FROM Transactions t
        JOIN Members    m  ON t.Member_ID    = m.Member_ID
        JOIN Books      b  ON t.Book_ID      = b.Book_ID
        JOIN Categories c  ON b.Category_ID  = c.Category_ID
        JOIN Librarians li ON t.Librarian_ID = li.Librarian_ID
        ORDER BY t.Borrow_Date DESC
    """, "all transactions with names & dates")

    # ── 4. Fines (detail) ─────────────────────────────────────────────────────
    export_query(conn, "fines.csv", """
        SELECT
            f.Fine_ID,
            m.First_Name || ' ' || m.Last_Name   AS Member_Name,
            m.Email,
            b.Title                               AS Book_Title,
            c.Category_Name,
            f.Fine_Amount,
            f.Fine_Status,
            f.Fine_Type,
            f.Payment_Date,
            t.Due_Date,
            t.Return_Date
        FROM Fines f
        JOIN Members      m  ON f.Member_ID      = m.Member_ID
        JOIN Transactions t  ON f.Transaction_ID = t.Transaction_ID
        JOIN Books        b  ON t.Book_ID        = b.Book_ID
        JOIN Categories   c  ON b.Category_ID    = c.Category_ID
        ORDER BY f.Fine_Amount DESC
    """, "fine ledger with member & book detail")

    # ── 5. Monthly trend (pre-aggregated) ─────────────────────────────────────
    export_query(conn, "monthly_trends.csv", """
        SELECT
            strftime('%Y-%m', Borrow_Date)                  AS Month,
            COUNT(*)                                         AS Total_Borrows,
            SUM(CASE WHEN Return_Date IS NOT NULL THEN 1
                     ELSE 0 END)                             AS Returned,
            SUM(CASE WHEN Return_Date IS NULL
                      AND Due_Date < date('now') THEN 1
                     ELSE 0 END)                             AS Overdue,
            ROUND(SUM(Fine_Amount), 2)                       AS Fines_Generated
        FROM Transactions
        GROUP BY strftime('%Y-%m', Borrow_Date)
        ORDER BY Month
    """, "monthly KPIs for trend chart")

    # ── 6. Category summary ───────────────────────────────────────────────────
    export_query(conn, "category_summary.csv", """
        SELECT
            c.Category_Name,
            COUNT(DISTINCT b.Book_ID)                                           AS Total_Books,
            SUM(CASE WHEN b.Availability = 'Available' THEN 1 ELSE 0 END)      AS Available,
            SUM(CASE WHEN b.Availability = 'Borrowed'  THEN 1 ELSE 0 END)      AS Borrowed,
            SUM(CASE WHEN b.Availability = 'Reserved'  THEN 1 ELSE 0 END)      AS Reserved,
            SUM(CASE WHEN b.Availability = 'Lost'      THEN 1 ELSE 0 END)      AS Lost,
            ROUND(
                SUM(CASE WHEN b.Availability = 'Available' THEN 1.0 ELSE 0 END)
                * 100.0 / COUNT(b.Book_ID), 1
            )                                                                   AS Availability_Pct,
            COUNT(t.Transaction_ID)                                             AS Total_Borrows
        FROM Categories  c
        LEFT JOIN Books        b ON c.Category_ID = b.Category_ID
        LEFT JOIN Transactions t ON b.Book_ID     = t.Book_ID
        GROUP BY c.Category_Name
        ORDER BY Total_Borrows DESC
    """, "inventory health per category")

    # ── 7. Reservations (with book & member) ──────────────────────────────────
    export_query(conn, "reservations.csv", """
        SELECT
            r.Reservation_ID,
            m.First_Name || ' ' || m.Last_Name  AS Member_Name,
            b.Title                             AS Book_Title,
            c.Category_Name,
            r.Reservation_Date,
            r.Expiry_Date,
            r.Status,
            r.Queue_Position
        FROM Reservations r
        JOIN Members    m ON r.Member_ID    = m.Member_ID
        JOIN Books      b ON r.Book_ID      = b.Book_ID
        JOIN Categories c ON b.Category_ID  = c.Category_ID
        ORDER BY r.Reservation_Date DESC
    """, "reservation queue with names")

    conn.close()

    print("\n" + "=" * 55)
    print(f"All files saved to: {OUTPUT_DIR}/")
    print("Next step: Open Power BI Desktop and connect to this folder.")
    print("=" * 55 + "\n")

if __name__ == "__main__":
    main()
