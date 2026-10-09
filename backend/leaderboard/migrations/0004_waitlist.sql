-- The waiting list: an email given on the game's landing page, to hear when the game comes out. Apart
-- from `players`: nobody signs in to give one. The same address twice, whatever its case, is one row.
CREATE TABLE waitlist (
  email TEXT PRIMARY KEY COLLATE NOCASE,
  joined_at INTEGER NOT NULL
);
