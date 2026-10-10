-- The highest revision any of a player's saves has had. `DELETE /save` empties `saves`, and the count
-- used to start again at 1: a device still at an old revision then took the reset game's for its own.
-- A revision is now never used twice.
ALTER TABLE players ADD COLUMN last_revision INTEGER NOT NULL DEFAULT 0;
UPDATE players SET last_revision = (SELECT MAX(revision) FROM saves WHERE saves.player_id = players.id)
  WHERE id IN (SELECT player_id FROM saves);
