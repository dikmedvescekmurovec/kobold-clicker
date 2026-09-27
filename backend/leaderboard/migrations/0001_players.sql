-- One row a player: an anonymous account (a name and the hash of a secret token the game keeps) and
-- the best score it has sent. The score is `floors`, every floor of the dungeon ever beaten: depth
-- 3, floor 14 is 2 * 15 + 14 = 44. The game writes it as "3.14".
CREATE TABLE players (
  id         INTEGER PRIMARY KEY,
  name       TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  token_hash TEXT    NOT NULL UNIQUE,
  floors     INTEGER NOT NULL DEFAULT 0,
  -- Server clock, ms since 1970, set only when `floors` rises: of two equal scores, the older is first.
  reached_at INTEGER,
  created_at INTEGER NOT NULL,
  -- 1 takes a player off the board without telling them (a cheat, a rude name). Set it by hand.
  hidden     INTEGER NOT NULL DEFAULT 0
);

-- The board's order, holding only the rows that are on it.
CREATE INDEX players_board ON players (floors DESC, reached_at, id) WHERE hidden = 0 AND floors > 0;
