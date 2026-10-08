-- Two more boards beside Gollux's: every ice wall the player has broken, in every world (the save's
-- `tally.walls`), and the level of the deepest tile they have charted, in any world (`deepest_level`).
-- Each moves like `floors`: only upwards, its `_at` set when it rises, the older of two equal scores first.
ALTER TABLE players ADD COLUMN walls INTEGER NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN walls_at INTEGER;
ALTER TABLE players ADD COLUMN deepest INTEGER NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN deepest_at INTEGER;

CREATE INDEX players_walls ON players (walls DESC, walls_at, id)
  WHERE hidden = 0 AND linked = 1 AND walls > 0 AND name IS NOT NULL;
CREATE INDEX players_deepest ON players (deepest DESC, deepest_at, id)
  WHERE hidden = 0 AND linked = 1 AND deepest > 0 AND name IS NOT NULL;
