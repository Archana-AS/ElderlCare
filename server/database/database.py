import sqlite3

class SQLiteDB:
    def __init__(self, db_name: str) -> None:
        self.db_name = db_name

    def _get_connection(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_name)

    def execute(self, query: str, *args):
        with self._get_connection() as con:
            cur = con.cursor()
            cur.execute(query, args)

    def fetchone(self, query: str, *args):
        with self._get_connection() as con:
            cur = con.cursor()
            cur.execute(query, args)
            return cur.fetchone()

    def fetchall(self, query: str, *args):
        with self._get_connection() as con:
            cur = con.cursor()
            cur.execute(query, args)
            return cur.fetchall()
        
db = SQLiteDB("database/db/data.db")

db.execute("""
CREATE TABLE IF NOT EXISTS reminders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task TEXT NOT NULL,
    time TEXT NOT NULL
);
""")

db.execute("""
INSERT INTO reminders (task, time)
VALUES ('Doctor appointment at 5:00 PM', '2025-09-29T11:30:00Z');
""")