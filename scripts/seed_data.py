"""
seed_data.py — Belly Library Management System
================================================
Generates realistic synthetic data and loads it into data/library.db

Run this ONCE after cloning the repo:
    pip install -r requirements.txt
    python scripts/seed_data.py

What this creates:
    10  categories   |  15 publishers   |   5 librarians
   200  members      | 500 books        | 2000 transactions
   ~600 fines        | 350 reservations
"""

import os
import sqlite3
import random
from datetime import date, timedelta
from faker import Faker

# ── Setup ─────────────────────────────────────────────────────────────────────
fake = Faker()
Faker.seed(42)
random.seed(42)

DB_PATH     = os.path.join("data", "library.db")
SCHEMA_PATH = os.path.join("sql", "schema.sql")

# ── Config ────────────────────────────────────────────────────────────────────
NUM_MEMBERS      = 200
NUM_BOOKS        = 500
NUM_LIBRARIANS   = 5
NUM_TRANSACTIONS = 2000
NUM_RESERVATIONS = 350
FINE_PER_DAY     = 0.50   # $0.50 per overdue day
LOAN_DAYS        = 14     # standard loan period
DATA_START       = date(2022, 1, 1)
TODAY            = date.today()

# ── Reference data ────────────────────────────────────────────────────────────
CATEGORIES = [
    "Fiction", "Science", "History", "Technology", "Philosophy",
    "Biography", "Children", "Mystery", "Self-Help", "Business",
]

PUBLISHERS = [
    ("Penguin Random House",    "New York, NY",       "info@penguinrandomhouse.com"),
    ("HarperCollins",           "New York, NY",       "info@harpercollins.com"),
    ("Simon & Schuster",        "New York, NY",       "info@simonandschuster.com"),
    ("Macmillan Publishers",    "New York, NY",       "info@macmillan.com"),
    ("Hachette Book Group",     "New York, NY",       "info@hachettebookgroup.com"),
    ("Oxford University Press", "Oxford, UK",         "info@oup.com"),
    ("Cambridge University Press","Cambridge, UK",    "info@cambridge.org"),
    ("Scholastic",              "New York, NY",       "info@scholastic.com"),
    ("Wiley",                   "Hoboken, NJ",        "info@wiley.com"),
    ("McGraw-Hill",             "New York, NY",       "info@mcgrawhill.com"),
    ("Pearson Education",       "London, UK",         "info@pearson.com"),
    ("Springer",                "Berlin, Germany",    "info@springer.com"),
    ("MIT Press",               "Cambridge, MA",      "info@mitpress.mit.edu"),
    ("Chronicle Books",         "San Francisco, CA",  "info@chroniclebooks.com"),
    ("Bloomsbury",              "London, UK",         "info@bloomsbury.com"),
]

TITLE_TEMPLATES = {
    "Fiction":    ["{adj} {noun}", "The Last {noun}", "When {noun} Falls", "A Story of {noun}"],
    "Science":    ["The Science of {noun}", "Understanding {noun}", "{noun} Explained", "Principles of {noun}"],
    "History":    ["The History of {noun}", "The Rise of {noun}", "Lost {noun}", "{noun}: A Chronicle"],
    "Technology": ["Mastering {noun}", "{noun} in Practice", "The {noun} Handbook", "Modern {noun}"],
    "Philosophy": ["On {noun}", "The Philosophy of {noun}", "Thinking About {noun}", "{noun} and Meaning"],
    "Biography":  ["The Life of {name}", "{name}: A Memoir", "Finding {name}", "In the Words of {name}"],
    "Children":   ["The Adventures of {noun}", "Little {noun}", "{noun} Goes to School", "My First {noun}"],
    "Mystery":    ["The {adj} Secret", "Murder at {place}", "The Case of the {adj} {noun}", "Missing {noun}"],
    "Self-Help":  ["The Power of {noun}", "{noun} Every Day", "Master Your {noun}", "Becoming {adj}"],
    "Business":   ["The {noun} Strategy", "Leading with {noun}", "{noun} in Business", "The Art of {noun}"],
}

ADJECTIVES = ["Hidden", "Lost", "Silent", "Ancient", "Golden", "Dark", "Broken", "Final", "Secret", "Forgotten"]
NOUNS      = ["Shadow", "River", "Mountain", "Storm", "Light", "Path", "Dream", "Fire", "Ocean", "Star"]
PLACES     = ["Millbrook", "Ashford", "Westgate", "Stonehaven", "Riverdale", "Clearwater"]

# ── Helpers ───────────────────────────────────────────────────────────────────

def rnd_title(category: str) -> str:
    template = random.choice(TITLE_TEMPLATES[category])
    return template.format(
        adj=random.choice(ADJECTIVES),
        noun=random.choice(NOUNS),
        name=fake.name(),
        place=random.choice(PLACES),
    )

def rnd_date(start: date, end: date) -> date:
    return start + timedelta(days=random.randint(0, max(0, (end - start).days)))

def pct(p: float) -> bool:
    """Return True with probability p (0.0–1.0)."""
    return random.random() < p

# ── Seeding functions ─────────────────────────────────────────────────────────

def seed_categories(cur):
    cur.executemany(
        "INSERT INTO Categories (Category_Name) VALUES (?)",
        [(c,) for c in CATEGORIES],
    )
    print(f"  ✓ {len(CATEGORIES)} categories")

def seed_publishers(cur):
    cur.executemany(
        "INSERT INTO Publishers (Publisher_Name, Publisher_Address, Publisher_Contact) VALUES (?,?,?)",
        PUBLISHERS,
    )
    print(f"  ✓ {len(PUBLISHERS)} publishers")

def seed_librarians(cur):
    rows = []
    for i in range(NUM_LIBRARIANS):
        role = "Admin" if i == 0 else "Staff"
        rows.append((fake.first_name(), fake.last_name(), role, f"librarian{i+1}@bellylibrary.org"))
    cur.executemany(
        "INSERT INTO Librarians (First_Name, Last_Name, Role, Email) VALUES (?,?,?,?)",
        rows,
    )
    print(f"  ✓ {NUM_LIBRARIANS} librarians")

def seed_members(cur):
    rows = []
    for _ in range(NUM_MEMBERS):
        status    = random.choices(["Active", "Inactive"], weights=[85, 15])[0]
        join_date = rnd_date(date(2019, 1, 1), date(2024, 6, 1)).isoformat()
        rows.append((
            fake.first_name(),
            fake.last_name(),
            fake.unique.email(),
            fake.phone_number()[:15],
            fake.address().replace("\n", ", "),
            status,
            0.0,      # Outstanding_Fines updated after transactions
            join_date,
        ))
    cur.executemany(
        """INSERT INTO Members
           (First_Name, Last_Name, Email, Phone, Address,
            Membership_Status, Outstanding_Fines, Join_Date)
           VALUES (?,?,?,?,?,?,?,?)""",
        rows,
    )
    print(f"  ✓ {NUM_MEMBERS} members")

def seed_books(cur):
    cat_ids = list(range(1, len(CATEGORIES) + 1))
    pub_ids = list(range(1, len(PUBLISHERS) + 1))
    rows = []
    for _ in range(NUM_BOOKS):
        cat_id   = random.choice(cat_ids)
        cat_name = CATEGORIES[cat_id - 1]
        avail    = random.choices(
            ["Available", "Borrowed", "Reserved", "Lost"],
            weights=[58, 32, 8, 2],
        )[0]
        rows.append((
            rnd_title(cat_name),
            fake.name(),
            fake.unique.isbn13(),
            random.randint(1, 5),
            random.randint(1980, 2024),
            cat_id,
            random.choice(pub_ids),
            avail,
        ))
    cur.executemany(
        """INSERT INTO Books
           (Title, Author, ISBN, Edition, Year, Category_ID, Publisher_ID, Availability)
           VALUES (?,?,?,?,?,?,?,?)""",
        rows,
    )
    print(f"  ✓ {NUM_BOOKS} books")

def seed_transactions_and_fines(cur):
    mem_ids = list(range(1, NUM_MEMBERS + 1))
    bk_ids  = list(range(1, NUM_BOOKS + 1))
    lib_ids = list(range(1, NUM_LIBRARIANS + 1))

    txn_rows  = []
    member_fine_totals = {m: 0.0 for m in mem_ids}

    for _ in range(NUM_TRANSACTIONS):
        member_id    = random.choice(mem_ids)
        book_id      = random.choice(bk_ids)
        librarian_id = random.choice(lib_ids)

        borrow_date = rnd_date(DATA_START, TODAY - timedelta(days=16))
        due_date    = borrow_date + timedelta(days=LOAN_DAYS)

        # 80% returned, 20% still out
        if pct(0.80):
            max_ret     = min(due_date + timedelta(days=20), TODAY - timedelta(days=1))
            return_date = rnd_date(borrow_date + timedelta(days=1), max(max_ret, borrow_date + timedelta(days=2)))
            condition   = random.choices(["Good", "Damaged", "Lost"], weights=[88, 9, 3])[0]
            overdue_days = max(0, (return_date - due_date).days)
        else:
            return_date  = None
            condition    = None
            overdue_days = max(0, (TODAY - due_date).days)

        fine = round(overdue_days * FINE_PER_DAY, 2)
        if fine > 0:
            member_fine_totals[member_id] = round(member_fine_totals[member_id] + fine, 2)

        txn_rows.append((
            member_id, book_id, librarian_id,
            borrow_date.isoformat(),
            due_date.isoformat(),
            return_date.isoformat() if return_date else None,
            condition,
            fine,
        ))

    cur.executemany(
        """INSERT INTO Transactions
           (Member_ID, Book_ID, Librarian_ID, Borrow_Date, Due_Date,
            Return_Date, Return_Condition, Fine_Amount)
           VALUES (?,?,?,?,?,?,?,?)""",
        txn_rows,
    )
    print(f"  ✓ {NUM_TRANSACTIONS} transactions")

    # ── Fines: one row per overdue/damaged transaction ─────────────────────────
    cur.execute(
        "SELECT Transaction_ID, Member_ID, Fine_Amount, Return_Condition "
        "FROM Transactions WHERE Fine_Amount > 0"
    )
    overdue_txns = cur.fetchall()
    fine_rows = []
    for txn_id, mem_id, fine_amt, condition in overdue_txns:
        status   = random.choices(["Paid", "Unpaid", "Waived"], weights=[48, 42, 10])[0]
        f_type   = "Lost" if condition == "Lost" else ("Damage" if condition == "Damaged" and pct(0.3) else "Overdue")
        pay_date = None
        if status == "Paid":
            pay_date = (TODAY - timedelta(days=random.randint(0, 90))).isoformat()
        fine_rows.append((mem_id, txn_id, fine_amt, status, f_type, pay_date))

    cur.executemany(
        """INSERT INTO Fines
           (Member_ID, Transaction_ID, Fine_Amount, Fine_Status, Fine_Type, Payment_Date)
           VALUES (?,?,?,?,?,?)""",
        fine_rows,
    )
    print(f"  ✓ {len(fine_rows)} fines generated")

    # ── Update member outstanding balances ────────────────────────────────────
    for mem_id, total in member_fine_totals.items():
        cur.execute(
            "UPDATE Members SET Outstanding_Fines = ? WHERE Member_ID = ?",
            (total, mem_id),
        )

    return fine_rows

def seed_reservations(cur):
    mem_ids = list(range(1, NUM_MEMBERS + 1))
    bk_ids  = list(range(1, NUM_BOOKS + 1))
    rows    = []
    for _ in range(NUM_RESERVATIONS):
        res_date = rnd_date(date(2023, 1, 1), TODAY)
        exp_date = res_date + timedelta(days=7)
        status   = random.choices(
            ["Pending", "Fulfilled", "Cancelled", "Expired"],
            weights=[25, 45, 15, 15],
        )[0]
        rows.append((
            random.choice(mem_ids),
            random.choice(bk_ids),
            res_date.isoformat(),
            exp_date.isoformat(),
            status,
            random.randint(1, 5),
        ))
    cur.executemany(
        """INSERT INTO Reservations
           (Member_ID, Book_ID, Reservation_Date, Expiry_Date, Status, Queue_Position)
           VALUES (?,?,?,?,?,?)""",
        rows,
    )
    print(f"  ✓ {NUM_RESERVATIONS} reservations")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("\nBelly Library — Database Seeder")
    print("=" * 40)

    # Ensure folders exist
    os.makedirs("data", exist_ok=True)

    # Load schema
    if not os.path.exists(SCHEMA_PATH):
        raise FileNotFoundError(f"Schema not found: {SCHEMA_PATH}\nRun from the project root folder.")

    with open(SCHEMA_PATH, "r") as f:
        schema_sql = f.read()

    # Connect and build schema
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(schema_sql)
    conn.execute("PRAGMA foreign_keys = ON")
    cur = conn.cursor()

    print("\nSeeding tables...")
    seed_categories(cur)
    seed_publishers(cur)
    seed_librarians(cur)
    seed_members(cur)
    seed_books(cur)
    fine_rows = seed_transactions_and_fines(cur)
    seed_reservations(cur)

    conn.commit()
    conn.close()

    print("\n" + "=" * 40)
    print("Database ready:", DB_PATH)
    print("Open with DB Browser for SQLite to explore.")
    print("=" * 40 + "\n")

if __name__ == "__main__":
    main()
