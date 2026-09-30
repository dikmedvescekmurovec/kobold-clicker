-- Cloud saves and signing in with Google or Discord. A player row becomes an account: signed in once it
-- has an identity, and only then on the board. Rebuilt so a signed-in player may have no board name
-- yet, and with the anonymous era's one token per player moved into `sessions`, one a device.

CREATE TABLE players_new (
  id         INTEGER PRIMARY KEY,
  -- The board name, chosen after signing in. NULL until then (SQLite lets many NULLs be UNIQUE).
  name       TEXT    UNIQUE COLLATE NOCASE,
  -- The board's score: the most floors any of the player's saves had vouched for (saves.vouched).
  floors     INTEGER NOT NULL DEFAULT 0,
  reached_at INTEGER,
  created_at INTEGER NOT NULL,
  hidden     INTEGER NOT NULL DEFAULT 0,
  -- 1 once signed in with a provider. An anonymous player from before is never on the board.
  linked     INTEGER NOT NULL DEFAULT 0,
  -- Why the last refused upload was refused, and when: for a person to look at, never shown on the board.
  flag       TEXT
);
INSERT INTO players_new (id, name, floors, reached_at, created_at, hidden)
  SELECT id, name, floors, reached_at, created_at, hidden FROM players;

-- One row a signed-in device: the hash of the token it holds.
CREATE TABLE sessions (
  token_hash TEXT    PRIMARY KEY,
  player_id  INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
INSERT INTO sessions (token_hash, player_id, created_at) SELECT token_hash, id, created_at FROM players;

DROP TABLE players;
ALTER TABLE players_new RENAME TO players;
CREATE INDEX players_board ON players (floors DESC, reached_at, id)
  WHERE hidden = 0 AND linked = 1 AND floors > 0 AND name IS NOT NULL;
CREATE INDEX sessions_player ON sessions (player_id);

-- Who a player is at Google or Discord: that provider's own id for them, and nothing else about them.
CREATE TABLE identities (
  provider   TEXT    NOT NULL,
  subject    TEXT    NOT NULL,
  player_id  INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (provider, subject)
);
CREATE INDEX identities_player ON identities (player_id);

-- A sign-in under way: the game polls with its code while the player signs in in a browser. Gone ten
-- minutes on, or as soon as the game has collected its token.
CREATE TABLE logins (
  code_hash  TEXT    PRIMARY KEY,
  -- Four letters shown both in the game and on the sign-in page, so a link someone else sent is caught.
  check_code TEXT    NOT NULL,
  -- The OAuth state while the player is at the provider.
  state      TEXT    UNIQUE,
  -- The device's anonymous player, whose board name the first sign-in keeps.
  player_id  INTEGER,
  provider   TEXT,
  -- The new session's token, held only until the game collects it.
  token      TEXT,
  created_at INTEGER NOT NULL
);

-- The cloud saves: the last few revisions a player, the newest the current one. `data` is the gzip of
-- {"inventory": <inventory.json>, "map": <map.json>}, byte for byte as the game wrote them.
CREATE TABLE saves (
  player_id   INTEGER NOT NULL,
  revision    INTEGER NOT NULL,
  data        BLOB    NOT NULL,
  -- What the conflict question shows: level, play time, when it was saved, the dungeon.
  summary     TEXT    NOT NULL,
  uploaded_at INTEGER NOT NULL,
  -- 1 when it was checked against the save it grew from; 0 for a first save, which has nothing to follow.
  checked     INTEGER NOT NULL,
  -- How many of its dungeon floors were beaten under the checks: none of a first save's, then what each
  -- checked save added on top of the one it grew from. This, not the save's own count, is the board's.
  vouched     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (player_id, revision)
);
