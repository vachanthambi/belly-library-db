-- =============================================================================
-- Belly Library Management System — Database Schema
-- DBMS: SQLite  |  Version: 1.0
-- =============================================================================

PRAGMA foreign_keys = ON;

-- Drop in reverse dependency order (clean re-runs)
DROP TABLE IF EXISTS Fines;
DROP TABLE IF EXISTS Reservations;
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Books;
DROP TABLE IF EXISTS Members;
DROP TABLE IF EXISTS Librarians;
DROP TABLE IF EXISTS Publishers;
DROP TABLE IF EXISTS Categories;

-- -----------------------------------------------------------------------------
-- CATEGORIES
-- Reference table — classifies books by genre
-- -----------------------------------------------------------------------------
CREATE TABLE Categories (
    Category_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
    Category_Name TEXT    NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- PUBLISHERS
-- Tracks book suppliers and procurement sources
-- -----------------------------------------------------------------------------
CREATE TABLE Publishers (
    Publisher_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
    Publisher_Name    TEXT    NOT NULL,
    Publisher_Address TEXT,
    Publisher_Contact TEXT
);

-- -----------------------------------------------------------------------------
-- LIBRARIANS
-- Staff accounts — linked to transactions for accountability
-- -----------------------------------------------------------------------------
CREATE TABLE Librarians (
    Librarian_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    First_Name   TEXT    NOT NULL,
    Last_Name    TEXT    NOT NULL,
    Role         TEXT    NOT NULL DEFAULT 'Staff'
                         CHECK(Role IN ('Admin', 'Staff')),
    Email        TEXT    NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- MEMBERS
-- Library users — borrowing eligibility enforced via status + outstanding fines
-- Business rule: members with Outstanding_Fines > $10 cannot borrow
-- Business rule: Inactive members cannot borrow or reserve
-- -----------------------------------------------------------------------------
CREATE TABLE Members (
    Member_ID         INTEGER PRIMARY KEY AUTOINCREMENT,
    First_Name        TEXT    NOT NULL,
    Last_Name         TEXT    NOT NULL,
    Email             TEXT    NOT NULL UNIQUE,
    Phone             TEXT,
    Address           TEXT,
    Membership_Status TEXT    NOT NULL DEFAULT 'Active'
                              CHECK(Membership_Status IN ('Active', 'Inactive')),
    Outstanding_Fines REAL    NOT NULL DEFAULT 0.0
                              CHECK(Outstanding_Fines >= 0),
    Join_Date         TEXT    NOT NULL   -- ISO-8601: YYYY-MM-DD
);

-- -----------------------------------------------------------------------------
-- BOOKS
-- Central inventory table — availability updated on every transaction
-- Business rule: max 5 books borrowed per member at one time
-- -----------------------------------------------------------------------------
CREATE TABLE Books (
    Book_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
    Title        TEXT    NOT NULL,
    Author       TEXT    NOT NULL,
    ISBN         TEXT    NOT NULL UNIQUE,
    Edition      INTEGER NOT NULL DEFAULT 1 CHECK(Edition >= 1),
    Year         INTEGER NOT NULL,
    Category_ID  INTEGER NOT NULL REFERENCES Categories(Category_ID),
    Publisher_ID INTEGER NOT NULL REFERENCES Publishers(Publisher_ID),
    Availability TEXT    NOT NULL DEFAULT 'Available'
                         CHECK(Availability IN ('Available','Borrowed','Reserved','Lost'))
);

-- -----------------------------------------------------------------------------
-- TRANSACTIONS
-- Core operational table — every borrow/return event
-- Fine_Amount populated by fine_engine.py (Phase 2)
-- -----------------------------------------------------------------------------
CREATE TABLE Transactions (
    Transaction_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
    Member_ID        INTEGER NOT NULL REFERENCES Members(Member_ID),
    Book_ID          INTEGER NOT NULL REFERENCES Books(Book_ID),
    Librarian_ID     INTEGER NOT NULL REFERENCES Librarians(Librarian_ID),
    Borrow_Date      TEXT    NOT NULL,   -- ISO-8601
    Due_Date         TEXT    NOT NULL,   -- Borrow_Date + 14 days
    Return_Date      TEXT,               -- NULL = still borrowed
    Return_Condition TEXT    DEFAULT 'Good'
                             CHECK(Return_Condition IN ('Good','Damaged','Lost')),
    Fine_Amount      REAL    NOT NULL DEFAULT 0.0
                             CHECK(Fine_Amount >= 0)
);

-- -----------------------------------------------------------------------------
-- RESERVATIONS
-- Queue system — first-come first-served, 24h window to collect on fulfillment
-- -----------------------------------------------------------------------------
CREATE TABLE Reservations (
    Reservation_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
    Member_ID        INTEGER NOT NULL REFERENCES Members(Member_ID),
    Book_ID          INTEGER NOT NULL REFERENCES Books(Book_ID),
    Reservation_Date TEXT    NOT NULL,
    Expiry_Date      TEXT    NOT NULL,   -- Reservation_Date + 7 days
    Status           TEXT    NOT NULL DEFAULT 'Pending'
                             CHECK(Status IN ('Pending','Fulfilled','Cancelled','Expired')),
    Queue_Position   INTEGER NOT NULL DEFAULT 1 CHECK(Queue_Position >= 1)
);

-- -----------------------------------------------------------------------------
-- FINES
-- Detailed penalty ledger — each fine linked to the transaction that caused it
-- Separate from Fine_Amount in Transactions for payment tracking
-- -----------------------------------------------------------------------------
CREATE TABLE Fines (
    Fine_ID        INTEGER PRIMARY KEY AUTOINCREMENT,
    Member_ID      INTEGER NOT NULL REFERENCES Members(Member_ID),
    Transaction_ID INTEGER NOT NULL REFERENCES Transactions(Transaction_ID),
    Fine_Amount    REAL    NOT NULL CHECK(Fine_Amount > 0),
    Fine_Status    TEXT    NOT NULL DEFAULT 'Unpaid'
                           CHECK(Fine_Status IN ('Paid','Unpaid','Waived')),
    Fine_Type      TEXT    NOT NULL DEFAULT 'Overdue'
                           CHECK(Fine_Type IN ('Overdue','Damage','Lost')),
    Payment_Date   TEXT    -- NULL until paid
);

-- =============================================================================
-- INDEXES
-- Added on all FK columns and frequently filtered/sorted fields
-- Significantly speeds up Phase 2 analytical queries
-- =============================================================================
CREATE INDEX idx_txn_member       ON Transactions(Member_ID);
CREATE INDEX idx_txn_book         ON Transactions(Book_ID);
CREATE INDEX idx_txn_borrow_date  ON Transactions(Borrow_Date);
CREATE INDEX idx_txn_due_date     ON Transactions(Due_Date);
CREATE INDEX idx_txn_return_date  ON Transactions(Return_Date);
CREATE INDEX idx_books_category   ON Books(Category_ID);
CREATE INDEX idx_books_publisher  ON Books(Publisher_ID);
CREATE INDEX idx_books_avail      ON Books(Availability);
CREATE INDEX idx_fines_member     ON Fines(Member_ID);
CREATE INDEX idx_fines_status     ON Fines(Fine_Status);
CREATE INDEX idx_reserv_member    ON Reservations(Member_ID);
CREATE INDEX idx_reserv_book      ON Reservations(Book_ID);
CREATE INDEX idx_reserv_status    ON Reservations(Status);
CREATE INDEX idx_member_status    ON Members(Membership_Status);
