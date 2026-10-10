-- A sign-in's two secrets, kept apart. The game polls with its code (`code_hash`), and the browser is
-- sent to the sign-in page by another id (`page_hash`): nothing an address bar shows collects the session.
ALTER TABLE logins ADD COLUMN page_hash TEXT;
CREATE UNIQUE INDEX logins_page ON logins (page_hash);
-- 1 once the provider has said who signed in: `player_id` is then the player the login belongs to, and
-- the session is made as the game collects it. `token` is no longer written: no token is kept anywhere.
ALTER TABLE logins ADD COLUMN done INTEGER NOT NULL DEFAULT 0;
-- A sign-in under way was started the old way and cannot be finished the new one: it starts again (the
-- game says it ran out of time). This also drops any token an uncollected one still held.
DELETE FROM logins;
