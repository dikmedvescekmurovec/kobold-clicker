# Kobold Clicker's backend: accounts, cloud saves and the leaderboards

One **Cloudflare Worker** (a small JavaScript program run on Cloudflare's servers) and one
**Cloudflare D1** database (managed SQLite) give the game three things:

- **Signing in with Google or Discord.** It's optional; the game plays exactly the same without it.
- **Cloud saves.** Play on one computer and carry on on another. If two devices both played offline,
  the player is asked which save to keep. A save is taken at its word: the player is trusted not to cheat.
- **Three leaderboards.** Gollux: each signed-in player's deepest descent as a depth and a floor
  (**Depth 3, floor 14** is depth 3 with 14 of its floors beaten). Walls: every ice wall they have
  broken, in every world. Deepest: the level of the deepest tile they have charted, in any world. Each is the best any
  of their saves reached; of two equal scores, whoever reached it first stands higher.

At this game's scale it costs **$0 a month**, with no servers to patch. The Worker is one JavaScript
file, the database a few short migrations (§7).

**Live:** `https://gollux-leaderboard.kobold-clicker.workers.dev`, on the Cloudflare account
*Dik.med.mur@gmail.com's Account*, workers.dev subdomain `kobold-clicker`. The Worker keeps the name
`gollux-leaderboard` it was first deployed under: shipped builds call that address forever
(`Cloud.URL`), so it is never renamed.

The diagrams are Mermaid. GitHub renders them as they are. In VS Code, install the *Markdown Preview
Mermaid Support* extension (`bierner.markdown-mermaid`) and open the preview (Ctrl+Shift+V).

---

## Contents

1. [How it fits together](#1-how-it-fits-together)
2. [Signing in](#2-signing-in)
3. [Cloud saves](#3-cloud-saves)
4. [Cheating](#4-cheating)
5. [The leaderboards](#5-the-leaderboards)
6. [The API](#6-the-api)
7. [The database](#7-the-database)
8. [The game's side](#8-the-games-side)
9. [Tools you need](#9-tools-you-need)
10. [Run it on your own machine](#10-run-it-on-your-own-machine)
11. [Set up the sign-in providers](#11-set-up-the-sign-in-providers)
12. [Deploy](#12-deploy)
13. [Running it: logs, cheaters, backups](#13-running-it-logs-cheaters-backups)
14. [What it costs](#14-what-it-costs)
15. [Security](#15-security)
16. [Customising it](#16-customising-it)
17. [Why this stack](#17-why-this-stack)
18. [Troubleshooting](#18-troubleshooting)
19. [Files](#19-files)

---

## 1. How it fits together

```mermaid
flowchart LR
    subgraph PC["Player's device"]
        Game["Godot game<br/>Cloud node (Scenes/cloud.gd)"]
        Files[("user://inventory.json<br/>user://map.json")]
        Cfg[("user://cloud.cfg<br/>token, revision, hash")]
        Browser["Web browser"]
        Game --- Files
        Game --- Cfg
        Game -. "opens the sign-in page" .-> Browser
    end

    subgraph CF["Cloudflare (free plan)"]
        Edge["Edge network<br/>HTTPS, DDoS protection"]
        RL["Rate limiters, per IP<br/>60 requests/min<br/>10 sign-ins/min<br/>5 waiting-list emails/min"]
        W["Worker<br/>src/index.js"]
        D1[("D1 database<br/>players, identities, sessions,<br/>logins, saves, waitlist")]
        Edge --> RL --> W --> D1
    end

    subgraph ID["Sign-in providers"]
        G["Google"]
        Dc["Discord"]
    end

    Game -- "HTTPS + JSON" --> Edge
    Browser -- "sign-in pages" --> Edge
    Browser <-- "sign in" --> ID
    W -- "code for the account id" --> ID
    You["You, with the Wrangler CLI"] -. "deploy, migrations, SQL, logs" .-> CF
```

- **The game** keeps its save files as it always has. The `Cloud` node moves them to and from the
  server and keeps its own small file, `cloud.cfg`. It uses Godot's built-in `HTTPRequest`, with no
  plugin or SDK.
- **The browser** is where the player signs in, so the game never sees a password. The same flow works
  on Windows, Mac, Linux, Android, iOS and the web.
- **The Worker** is the only thing that touches the database.
- **Google and Discord** only tell the Worker a stable id for the account. The Worker never asks for
  an email, a name or a picture.

---

## 2. Signing in

It works like signing in to a TV app: the game shows a code, the browser does the signing in, and the
game waits until the server says it's done.

```mermaid
sequenceDiagram
    actor P as Player
    participant G as Game (Cloud)
    participant B as Browser
    participant W as Worker
    participant Pr as Google or Discord

    P->>G: presses Sign in (settings or leaderboard)
    G->>W: POST /logins (with the old anonymous token, if any)
    W-->>G: code (secret, kept by the game), check letters K7RX, the page's address
    G->>B: opens /login?page=... (the page's own id, not the code)
    G-->>P: shows K7RX
    loop every 2 s, up to 10 min
        G->>W: POST /logins/poll with the code
        W-->>G: 202 still waiting
    end
    B->>W: GET /login?page=...
    W-->>B: page showing K7RX and Continue with Google / Discord, and a cookie
    P->>B: checks the letters match, picks Google
    B->>W: GET /auth/google?page=... (with the cookie)
    W-->>B: redirect to Google with a one-time state
    B->>Pr: signs in
    Pr-->>B: redirect to /auth/google/callback?code=...&state=...
    B->>W: callback (with the cookie)
    W->>Pr: swaps the code for an access token (server to server)
    W->>Pr: asks whose token it is
    Pr-->>W: the account id (Google sub, Discord id)
    W->>W: finds or makes the player, marks the login done
    W-->>B: You are signed in, go back to the game
    G->>W: POST /logins/poll
    W-->>G: 200 a new session's token (made now, handed out once, the login deleted)
    G->>G: token saved to cloud.cfg, first sync
```

- **The check letters** stop a phishing trick. Someone could start a sign-in on their own game and
  send you the link: if you signed in there, *their* game would be signed in as you. The page shows
  four letters, and the player only continues if their own game shows the same ones. The page says so.
  A link that skips the page cannot be followed: the page leaves a cookie (`__Host-login`, ten minutes,
  `Secure; HttpOnly; SameSite=Lax`), and both steps after it, on to the provider (`/auth/...`) and back
  from it (the callback), are refused without it (403). So neither a link straight to `/auth/...` nor
  the provider's own address with someone else's `state` signs anybody in.
- **A login has two secrets.** The game's `code` collects the session, and leaves the game only in the
  body of its own poll. The address the browser opens carries the page's own id, which collects
  nothing: a stream, a shared screen or a synced history shows nothing worth having.
- **A login lasts 10 minutes.** The session is made at the one poll that collects it and its token goes
  to the game; the login is deleted with it. No token is ever stored, only its SHA-256.
- **One account per provider identity.** Signing in with the same Google account on two devices is
  one player with two sessions (one per device). Google and Discord are separate accounts: there is
  no linking of the two.
- **The old anonymous leaderboard name** (from before accounts) goes to the device's first sign-in.
  Its old score starts again from zero, and the first upload sets it from the save.
- **Sign out** deletes this device's session only. **Delete cloud account** deletes the player, their
  identities, sessions and saves. Both keep the save files on the device.

---

## 3. Cloud saves

The save is the game's own two files, `inventory.json` and `map.json`: about 140 KB of JSON, about 20 KB
gzipped. The server keeps each player's **last 10 revisions**, and each upload says which revision it
grew from.

This device's side is kept in `cloud.cfg`:

- **`revision`**: the cloud revision this device's files grew from, or 0 for none.
- **`hash`**: the SHA-256 of the two files as they were at that revision.

So the game can tell whether **this device** changed (the files' hash differs from `hash`) and whether
**the cloud** changed (its newest revision differs from `revision`).

```mermaid
flowchart TD
    S["sync: GET /me"] --> E{"Cloud has a save?"}
    E -- "No" --> U0["Upload as a first save"]
    E -- "Yes" --> Q1{"This device changed?"}
    Q1 -- "No" --> Q2{"Cloud changed?"}
    Q2 -- "No" --> N["Nothing to do"]
    Q2 -- "Yes" --> D["Download over the files,<br/>then the scene reloads"]
    Q1 -- "Yes" --> Q3{"Cloud changed?"}
    Q3 -- "No" --> U["Upload, at most every 5 min<br/>(at once after a descent or on quit)"]
    Q3 -- "Yes" --> A["Ask: keep this device's<br/>or the cloud's?"]
```

When it syncs:

| When | What |
|---|---|
| Start-up | Right after the scene is built. It judges "this device changed" by the files **as the scene found them**, before start-up wrote anything (`Cloud.launched`). Otherwise a start-up's own writes (the map, a camp's pay) would make every change of device a question. While it still holds that judgement and the game is not calm (a start-up that stands a camp up), the first sync waits: it goes as the camp is struck. |
| Every 30 s while playing (`Cloud._tick`) | Uploads a changed save when due (at most every `UPLOAD_EVERY`, 5 min) straight to `PUT /save`, with no `/me` first: a save another device beat to the cloud is refused (409), and that makes a full sync owed. An unchanged save calls nobody. While a full sync is owed (none yet, a 409, or a download or question that waited) the tick makes one. A download or a question waits until the game is **calm**: not in a fight, walking to one, a camp, the black screen or another question. |
| The window or tab coming back into focus | A full sync: where a save made on another device is noticed. |
| After a descent | Uploads at once, so the board catches up. |
| Opening the leaderboard page | Uploads at once, then reads the board. |
| Closing the window | The scene closes (it banks the run and writes its saves), the upload goes with a 4 s timeout, then the game quits. On Android and iOS, when the app is paused. |

**A download** is read before it is written: an inventory that does not parse, or one (or a map) from
a newer build than this one, writes nothing and is said on the page (`Cloud.problem`). Then both files
go down through `SafeFile` and the main scene is told, which reloads without saving over them
(`_on_cloud_replaced` sets `_resetting`).

**A save this build refuses moves nothing.** When the main scene cannot read the inventory or the map
(`_refuse_save`) it sets `Cloud.blocked`, and neither `sync` nor `push` calls anyone: an unreadable
file never goes up over the cloud's readable one.

**The question** shows both saves (level, time played, when saved, deepest descent) and nothing is
replaced until the player picks:

- *Keep the cloud's*: the cloud's save is downloaded.
- *Keep this device's*: it's uploaded with `replace`, in the cloud's place.

```mermaid
sequenceDiagram
    participant A as Device A (PC)
    participant W as Worker
    participant B as Device B (laptop)

    A->>W: PUT /save base 4 (rev 5)
    B->>W: GET /me, cloud is 5, B has 4, B unchanged
    B->>W: GET /save
    W-->>B: rev 5, written over B's files, B reloads
    Note over A,B: both now play offline
    A->>A: plays, files change
    B->>B: plays, files change
    B->>W: PUT /save base 5 (rev 6)
    A->>W: GET /me, cloud is 6, A has 5, and A changed
    A-->>A: question: this device's or the cloud's?
    alt keep this device's
        A->>W: PUT /save base 5, replace (rev 7)
    else keep the cloud's
        A->>W: GET /save, rev 6 over A's files
    end
```

**Reset save** (settings) deletes the cloud's saves too, before the files, and the fresh game becomes
the cloud's first save. The question says so. A **transcension** is an ordinary save as far as the
cloud is concerned.

**A revision is never used twice.** After a reset the next upload is numbered on from the last
(`players.last_revision`), not from 1: another device still at an old revision finds the cloud
changed, and downloads or is asked, as after any other upload. Until that upload, a stale one from
such a device is a conflict with nothing to show (409, `summary: null`).

---

## 4. Cheating

**The server takes every save at its word** (since 2026-10-02): the player is trusted not to cheat. An
upload is turned away only when it isn't a save at all (400) or is far too big (413). The checks it once
made of a save against itself and against the one it grew from were removed: they turned down honest
saves.

What that leaves open: an edited save, its floors included, goes to the cloud and onto the board as it
is. The way to deal with a cheater is by hand: **take them off the board** (§13).

---

## 5. The leaderboards

Three boards, each a column of `players` and the column of when it last rose (`BOARDS` in
`src/index.js`), each read off an upload by the same rules below:

| Board | Score | Read from the save | When it rose |
|---|---|---|---|
| `gollux` | `floors` | `dungeon_floors` | `reached_at` |
| `walls` | `walls` | `tally.walls` (ice walls broken, every world) | `walls_at` |
| `deepest` | `deepest` | `deepest_level` (the deepest tile's land level, any world) | `deepest_at` |

A walls or deepest score fills in at a player's first upload after migration `0003_boards.sql`.

Gollux's score is a number of dungeon floors, shown as a depth and a floor. 44 is 2 × 15 + 14, shown as
**Depth 3, floor 14**, and killing depth 3's Gollux is 45, shown as **Depth 4, floor 0**.
`Cloud.score_text` writes it (it was `3.14` once, which read as a decimal).

**A player's score is the best any of their saves reached:** an upload's own number. It only ever
rises, so a restored backup or a reset never takes it down.

**Who is on one:** signed-in players with a board name and a score above 0, not `hidden`.

**Order:** score highest first, then `reached_at` (or the board's `_at`) earliest first, then `id`. It is the
**server's** clock, and it moves only when the score rises, so the same score sent again changes
nothing.

```mermaid
flowchart TD
    A["Two players, A and B"] --> Q1{"Same score?"}
    Q1 -- "No" --> R1["Higher score ranks higher"]
    Q1 -- "Yes" --> Q2{"Same reached_at<br/>to the millisecond?"}
    Q2 -- "No" --> R2["Earlier reached_at ranks higher"]
    Q2 -- "Yes" --> R3["Lower id ranks higher"]
```

---

## 6. The API

Every body is JSON, and every error is `{"error": "a sentence for the player"}`. The game shows that
sentence as it is. "Bearer" means `Authorization: Bearer <session token>`.

**The contract is [`contract.json`](contract.json):** every route with who may call it, the fields it
is sent, the fields it answers and its statuses. `npm test` walks it against the Worker ("every route
answers as contract.json says") and checks it lists every route of `src/index.js`, so it is the one
place a field is looked up or changed. What each route is for:

| Route | For |
|---|---|
| `POST /logins` | Starts a sign-in: the game's `code`, the check letters and the page's address. An old anonymous token, if sent, keeps its board name |
| `GET /login?page=` | The sign-in page (HTML). Leaves the cookie the next two need |
| `GET /auth/{google,discord}?page=` | On to the provider (302) |
| `GET /auth/{google,discord}/callback` | Back from the provider: the "Signed in" page |
| `POST /logins/poll` | The game asking whether it is done: 202 while it waits, then the session's token, once |
| `GET /me` | The player's standing (name, score, rank), providers and newest save's summary |
| `PUT /me/name` | Chooses or changes the board name |
| `DELETE /me` | Everything about the player gone |
| `DELETE /sessions/me` | This device's session gone |
| `GET /save` | The newest save: the two files as text |
| `PUT /save` | An upload, naming the revision it grew from. **409** when the cloud's newest is another one, with its `revision` and its newest save's `summary`: null when the cloud holds no save (it was reset), left out when two uploads raced |
| `DELETE /save` | The cloud's saves gone, the board untouched |
| `GET /leaderboard?board=&limit=` | A board's top and, with a token, the player's own row: `gollux` (left out: what builds before the other boards ask), `walls` or `deepest`. A row keeps `floors` beside its `score`, as those builds read it |
| `GET /privacy` | The privacy page (HTML) |
| `POST /waitlist` | An email for the waiting list; one already on it is taken again without complaint |

Rules:

- **Every route:** 60 requests a minute per IP address.
- **`POST /logins`:** 10 a minute per IP address. **`POST /waitlist`:** 5.
- A rate limiter that fails lets the call through, and logs it.
- **A body** is a JSON object of at most 4 MB. Anything else is 400, or 413.
- A sign-in polls 30 times a minute.
- A playing game makes about one request each 5 minutes (an upload), and an idle one none: `/me` is read
  only at start-up, on focus, after a descent or a camp, on the board page and after a 409.

---

## 7. The database

```mermaid
erDiagram
    PLAYERS ||--o{ IDENTITIES : "signs in as"
    PLAYERS ||--o{ SESSIONS : "is signed in on"
    PLAYERS ||--o{ SAVES : "keeps the last 10"
    PLAYERS ||--o{ LOGINS : "may be linking"
    PLAYERS {
        INTEGER id PK
        TEXT name UK "board name, NULL until chosen"
        INTEGER floors "board score, the deepest save"
        INTEGER reached_at "server ms when floors last rose"
        INTEGER walls "walls board: ice walls broken"
        INTEGER walls_at "server ms when walls last rose"
        INTEGER deepest "deepest board: the deepest tile's level"
        INTEGER deepest_at "server ms when deepest last rose"
        INTEGER created_at
        INTEGER hidden "1 is off the board, silently"
        INTEGER linked "1 once signed in"
        INTEGER last_revision "the highest revision its saves ever had"
        TEXT flag "unused: the last refusal, from when saves were checked"
    }
    IDENTITIES {
        TEXT provider PK "google or discord"
        TEXT subject PK "the provider's id for them"
        INTEGER player_id
        INTEGER created_at
    }
    SESSIONS {
        TEXT token_hash PK "SHA-256 of a device's token"
        INTEGER player_id
        INTEGER created_at
    }
    LOGINS {
        TEXT code_hash PK "SHA-256 of the game's code"
        TEXT page_hash UK "SHA-256 of the page's id"
        TEXT check_code "four letters"
        TEXT state UK "OAuth state at the provider"
        INTEGER done "1 once the provider has answered"
        INTEGER player_id "old anonymous player to link, then who signed in"
        TEXT provider
        TEXT token "unused: no token is stored"
        INTEGER created_at "gone after 10 minutes"
    }
    SAVES {
        INTEGER player_id PK
        INTEGER revision PK
        BLOB data "gzip of both files"
        TEXT summary "level, time, saved, floors"
        INTEGER uploaded_at
        INTEGER checked "unused, always 0"
        INTEGER vouched "unused, always 0"
    }
    WAITLIST {
        TEXT email PK "whatever its case"
        INTEGER joined_at
    }
```

- **`migrations/0001_players.sql`**: the anonymous leaderboard it started as.
- **`migrations/0002_accounts.sql`**: accounts and saves. It rebuilds `players` (a name may be NULL,
  the token moved to `sessions`) and keeps every old row.
- **`migrations/0003_boards.sql`**: the walls and deepest boards' columns on `players`.
- **`migrations/0004_waitlist.sql`**: the waiting list, apart from everything else.
- **`migrations/0005_login_pages.sql`**: a login's page id and its `done`; empties `logins` (§12).
- **`migrations/0006_revisions.sql`**: `players.last_revision`, filled from each player's newest save.

**Schema changes are migrations.** Add the next numbered file (`migrations/0007_<what>.sql`), and never
edit one that has been applied to the live database (`npx wrangler d1 migrations list DB --remote` shows which have been).

---

## 8. The game's side

| Piece | What it does |
|---|---|
| `Scenes/cloud.gd` (`Cloud`) | Everything above, from the game's side. Signing in, out and deleting (`sign_in`, `cancel_sign_in`, `sign_out`, `delete_account`), the board name (`choose_name`), the board (`refresh`), syncing (`sync`, `push`, `leave`, `keep_cloud`, `keep_device`, `forget_save`), and `decide`, `summary_of`, `hash_of`, `score_text`. One lives under the root (`NODE`), so it outlives the scene's reloads. Off (`path` empty) anywhere but the player's own save. |
| `Scenes/UI/cloud_question.gd` (`CloudQuestion`) | The question over the whole window: two saves side by side, and two answers. |
| `Scenes/UI/settings_page.gd` | **Cloud save** section: Sign in, the four letters and Cancel while signing in, then "Signed in with Google", when it last saved, Sign out, and Delete cloud account (asked in place). Reset's question says "here and in the cloud" while signed in. |
| `Scenes/UI/leaderboard_page.gd` | Sign in, a name to choose, or the player's row, over the board anyone may read. No explanatory sentences on the game's pages: what a button does is in its tooltip. |
| `Scenes/main_scene.gd` | `_find_cloud` (made or found again, `launched`, `calm`, the signals), a sync at the end of start-up and after a descent, `_on_cloud_replaced` (reload), `_on_cloud_asked` (the question), quitting through `Cloud.leave`, and Reset through `forget_save`. |

**Pointing the game at a server:** `Cloud.URL` is the live Worker. The environment variable
`LEADERBOARD_URL` overrides it, and the account then goes in `user://cloud_dev.cfg`, so testing never
touches the real one:

```powershell
$env:LEADERBOARD_URL = "http://127.0.0.1:8787"
& "C:\Users\Dik\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path .
```

---

## 9. Tools you need

| Tool | Why | Get it |
|---|---|---|
| **Cloudflare account** (free) | hosts the Worker and D1 | have it: *Dik.med.mur@gmail.com's Account* |
| **Node.js 20+** (you have 24) | runs Wrangler and the tests | <https://nodejs.org> |
| **Wrangler 4** | Cloudflare's CLI: dev server, deploy, D1, secrets, logs | `npm install` in this folder |
| **A Google Cloud project** (free) | Sign in with Google | §11 |
| **A Discord application** (free) | Sign in with Discord | §11 |
| Godot 4.7 | the game | set up already (root `CLAUDE.md`) |

Run every command below **from `backend/leaderboard/`**. `backend/.gdignore` keeps Godot out of
`node_modules`.

---

## 10. Run it on your own machine

No Cloudflare account and no provider is needed for any of this.

```sh
npm install                  # once
npm test                     # ~30 s
```

**`npm test`** starts the Worker on a fresh local database with a **stand-in for Google's and Discord's
servers**, so the real sign-in code runs end to end. The stand-in checks what the real ones do: the
client's id and secret, the redirect address registered for it, and a code of its own, good once. It
covers:

- sign-in, and one player across devices; the old name kept on the first sign-in;
- a login nobody started, cancelled, refused by the provider or played back;
- the game's code in no address and on no page, and nothing shown that collects the session;
- the cookie: a link that skips the sign-in page refused;
- no token stored while a login waits;
- names;
- a save round-tripping byte for byte; conflicts, and replace;
- a save taken at its word, and only a non-save or one too big turned away;
- a reset: the board kept, a stale upload a conflict, no revision used twice;
- a body that is not a JSON object;
- every signed-in route without a token and with a wrong one; one player's calls never touching another's;
- the three boards: their order, each only rising, and **the fields they read being the ones the game
  writes** (`tests/fixtures/inventory_golden.json`, a save as `Inventory.save` writes it: a field
  renamed there fails here, where it would otherwise score 0 for ever and nothing would say so);
- signing out and deleting, and every table with a `player_id` emptied by a deletion;
- the web build's calls from another origin;
- the waiting list;
- the three rate limits, and a limiter that fails;
- `contract.json`, route by route.

The stand-in is switched on only by `PROVIDER_ORIGIN`, which only the tests set.

**On Windows, keep the `--persist-to` path short.** Past about 135 characters the local rate limiter
throws `internal error` on every call. The Worker logs it and lets the call through, so it is the
rate-limit tests that fail. The tests use `.wrangler/test`, relative to this folder.

**A local server** for the game to talk to:

```sh
npx wrangler d1 migrations apply DB --local
npx wrangler dev --var GOOGLE_CLIENT_ID:<id> --var GOOGLE_CLIENT_SECRET:<secret>
```

Real sign-in on a local server also needs `http://127.0.0.1:8787/auth/google/callback` added to the
Google client's redirect URIs, and a browser that keeps the sign-in page's `Secure` cookie from
plain-http localhost (Chrome and Firefox treat localhost as secure; not tried here).

The game's side is covered by `python tests/run_all.py cloud`: decide, the summary, the score's
words, the account file and the question. `combat` and `inventory` cover the floors a descent banks.

---

## 11. Set up the sign-in providers

Both are free, and both only ever tell the Worker an id. Replace `<worker>` with
`https://gollux-leaderboard.kobold-clicker.workers.dev`.

### Google

1. Go to <https://console.cloud.google.com> and create a project, **Kobold Clicker**.
2. Open **Google Auth Platform** → **Get started**. App name **Kobold Clicker**, your support email,
   Audience **External**, your contact email.
3. Go to **Clients → Create client**, type **Web application**. Under *Authorized redirect URIs*, add
   `<worker>/auth/google/callback`, then create it. Keep the **Client ID** and **Client secret**.
4. Go to **Audience → Publish app**. Until then, only listed test users can sign in. The only scope
   asked for is `openid`, which needs no review.
5. *Optional:* under **Branding**, set the privacy policy link to `<worker>/privacy`.

### Discord

1. Go to <https://discord.com/developers/applications> → **New Application**, **Kobold Clicker**.
2. Open **OAuth2** → *Redirects* → add `<worker>/auth/discord/callback` → **Save Changes**.
3. Keep the **Client ID**. Click **Reset Secret** and keep the **Client Secret**. The only scope asked
   for is `identify`.

### Give them to the Worker

- **The client ids** aren't secret. They go in `wrangler.toml` under `[vars]`
  (`GOOGLE_CLIENT_ID`, `DISCORD_CLIENT_ID`) and are committed. An empty one hides that provider's button.
- **The secrets** never go in a file:

```sh
npx wrangler secret put GOOGLE_CLIENT_SECRET
npx wrangler secret put DISCORD_CLIENT_SECRET
npx wrangler secret list        # shows their names, never their values
```

---

## 12. Deploy

```mermaid
flowchart TD
    A["npm test"] --> B["npx wrangler d1 migrations apply DB --remote<br/>(answer y)"]
    B --> C["npx wrangler deploy"]
    C --> D["Smoke test: GET /leaderboard,<br/>open /login from a POST /logins"]
    D --> E["Sign in once from the game"]
```

```sh
npm run deploy      # = npm test, then migrations to the live database, then the Worker
```

- **`npm run deploy` runs `npm test` first** (`predeploy`) and stops there if anything is red.
- **A deploy switches over in seconds.** `npx wrangler rollback` puts the previous version back.
- **A migration can't be rolled back that way.** Restore the database with Time Travel (§13) if one goes
  wrong.
- **Never rename the Worker or drop a route a shipped build calls.** Add routes; don't change what old
  ones mean.

**What the deploy after 2026-10-10 does, and how to undo it.** In order:

1. `0005_login_pages.sql` adds `logins.page_hash` and `logins.done` and **empties `logins`**. A sign-in
   under way at that moment says it ran out of time and is started again. Nobody is signed out.
2. `0006_revisions.sql` adds `players.last_revision` and fills it from each player's newest save.
3. The Worker, with its third rate limiter (`WAITLIST_LIMIT`, made from `wrangler.toml`: nothing to
   create by hand).

For the seconds between 2 and 3 the old Worker runs on the new tables, which it can: the migrations
add columns and take none away. A sign-in started in that gap cannot be finished after it, and is
started again. **To undo,** `npx wrangler rollback` is enough: the old Worker ignores the new
columns, and when the new one comes back it numbers revisions from whichever is higher, the newest
save or `last_revision`. The columns stay; nothing needs restoring.

---

## 13. Running it: logs, cheaters, backups

**Live logs** (every request and every `console.error`, including a failed token exchange with a
provider):

```sh
npx wrangler tail
```

**Look at the data:**

```sh
npx wrangler d1 execute DB --remote --command "SELECT id, name, floors, linked, hidden FROM players ORDER BY floors DESC LIMIT 20"
npx wrangler d1 execute DB --remote --command "SELECT COUNT(*) AS players, SUM(linked) AS signed_in, SUM(floors > 0 AND name IS NOT NULL AND linked = 1) AS on_board FROM players"
```

**Take a player off the board** (a cheater, a rude name), silently:

```sh
npx wrangler d1 execute DB --remote --command "UPDATE players SET hidden = 1 WHERE name = 'xX_Cheater_Xx'"
```

**Give a name back:**

```sh
npx wrangler d1 execute DB --remote --command "UPDATE players SET name = NULL WHERE name = '...'"
```

The player then chooses another from the leaderboard page.

**A player's save history:**

```sh
npx wrangler d1 execute DB --remote --command "SELECT revision, summary, datetime(uploaded_at/1000,'unixepoch') FROM saves WHERE player_id = 12 ORDER BY revision"
```

**Backups:**

- **Time Travel:** restore the whole database to any minute of the last 7 days (free) or 30 days (paid).

  ```sh
  npx wrangler d1 time-travel info DB
  npx wrangler d1 time-travel restore DB --timestamp=2026-09-30T12:00:00Z
  ```

- **An export you keep:** `npx wrangler d1 export DB --remote --output=backup.sql`

---

## 14. What it costs

This is Cloudflare's free plan as published at the time of writing. Check
<https://developers.cloudflare.com/workers/platform/pricing/> and
<https://developers.cloudflare.com/d1/platform/pricing/>.

| Resource | Free plan | A player uses, per hour played |
|---|---|---|
| Worker requests | 100,000 / day | ~15: 12 uploads, and a `/me` at start-up and each focus |
| D1 rows written | 100,000 / day | ~50: an upload writes its row, prunes the 11th, notes its revision, may move the board |
| D1 rows read | 5 million / day | a few hundred |
| D1 storage | 5 GB | 10 revisions × ~20 KB = ~200 KB a player, so ~25,000 players |

That's about **6,000 player-hours a day** free; the limit that bites first is requests, from the
uploads. Past that, **Workers Paid is $5/month** for 10 million requests.

The dial that trades freshness for cost is `Cloud.UPLOAD_EVERY` (5 min): how much play a crash can keep
out of the cloud (never off the device). Until 2026-10-30 every 30 s tick read `/me` too (~130 requests
an hour played); now a device notices another's save on focus, at start-up or on a 409, not within 30 s.

When a free limit is hit, calls fail until midnight UTC. The game says "The cloud cannot be reached",
plays on, and syncs later. Nothing is lost, because the files on the device are the save.

---

## 15. Security

| Threat | Defence |
|---|---|
| Stealing a session | Tokens are 256 random bits, sent only over HTTPS, and stored only as SHA-256. A session is made at the poll that collects it, so not even a waiting login holds one: a leaked database holds no token. |
| A sign-in link sent by someone else | The four check letters on both screens; the page says to close it if they differ. A link that skips the page (straight to `/auth/...`, or the provider's own address) is refused: both steps need the cookie the page left. |
| The sign-in address seen by someone else (a stream, a shared screen, synced history) | It carries only the page's id. The code that collects the session leaves the game only in the body of its own poll, never in an address or a page. |
| Forged OAuth callbacks | The one-time `state`, bound to one login and gone once used. The code is swapped server to server with the client secret, which never leaves Cloudflare. |
| Replaying a login code | A login's session is made and handed out once, and the login deleted with it. Codes expire after 10 minutes. |
| The page's id leaking to the provider | Every page is sent with `Referrer-Policy: no-referrer`, a CSP of `default-src 'none'`, and `X-Frame-Options: DENY`. |
| Spam | Per-IP rate limits (every call, sign-ins, the waiting list) and Cloudflare's DDoS protection. The body limit is 4 MB. |
| Junk data | Names are whitelisted; saves are parsed; all SQL is parameterised. |
| Personal data | Only a provider's id, the chosen name, the save and its times are kept. `/privacy` says so, and **Delete cloud account** removes all of it (GDPR's right to erasure). |

Cheating is §4.

---

## 16. Customising it

The web build is served from another origin (`../web`, by `tools/web.py`), so every JSON reply carries
`Access-Control-Allow-Origin: *` and an `OPTIONS` preflight is answered before the rate limiter. Any
origin is safe: sessions are bearer tokens, never cookies (the one cookie, the sign-in page's, is read
only by the sign-in pages themselves).

| You want | Change |
|---|---|
| Apple sign-in (for iOS) | Needs the Apple Developer Program ($99/yr). Add an `apple` entry to `PROVIDERS` in `src/index.js`. Apple's client secret is a signed JWT (ES256, made from its key) rather than a string, and it answers with `id_token` instead of a user endpoint. Add the route to the regex, a button appears |
| Link Google and Discord into one account | A signed-in `POST /logins` that attaches the new identity to the caller's player instead of finding or making one |
| Rename from the game | `PUT /me/name` already renames. The leaderboard page only asks while there is no name |
| Replay descents on a server | Headless Godot in a container (level 3). Out of reach of Workers |
| Keep more revisions | `KEEP_REVISIONS` |
| Seasons | A `season` on `saves` or a `scores` table, and `?season=` on `/leaderboard` |

---

## 17. Why this stack

The brief was cloud-hosted, as simple as possible, cheap, and customisable.

| Option | Why not (or why) |
|---|---|
| **Cloudflare Workers + D1** ✅ | Real code and real SQL you own; no server; no cold starts; never pauses; local dev and tests run on the same runtime. |
| Supabase (Postgres + Auth) | Its free projects pause after a week idle. The rules would be SQL functions and row-level security instead of plain code. |
| Firebase (Auth + Firestore) | Billed per document read. Community-made Godot SDKs. The rules become a second language. |
| A rented server | ~$5/mo from day one, and you patch the OS, renew TLS and keep it running. It's needed only for level 3 (running the game). |
| Steam Cloud and leaderboards | Free and the right answer *if* the game ships on Steam, for Steam players only. |
| PlayFab, Nakama, SilentWolf | Faster to start, but the ranking and pricing are theirs. |

A hosted sign-in service (Auth0, Clerk, Firebase Auth) wasn't worth it for two providers asking only
for an id: the OAuth code is about 80 lines in `src/index.js`.

---

## 18. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| The sign-in page has no buttons | `GOOGLE_CLIENT_ID` / `DISCORD_CLIENT_ID` empty in `wrangler.toml`; deploy after setting them. |
| Google says `redirect_uri_mismatch` | The client's redirect URI must be exactly `<worker>/auth/google/callback`: https, no trailing slash. |
| Google says access blocked, app not verified | The app isn't published (§11 Google, step 4), or it asks for more than `openid`. |
| "The sign-in did not go through" | The token exchange failed: a wrong or missing secret. `npx wrangler tail` shows the provider's answer. |
| "Signing in ran out of time" | The browser step took over 10 minutes, or the page was closed. Start again. |
| The sign-in page says it was not opened in this browser | The cookie did not come back: cookies are blocked, or the page was opened in one browser and carried on in another. Start again from the game. |
| The same question every start-up | Something writes the save before `_find_cloud` runs `launched()`. Keep `launched()` ahead of every write in `_ready`. |
| Choose name does nothing | It did until 2026-10-10: every 409 was hidden. "That name is taken" is now shown; only a save's own 409 (the question) is not. |
| "The cloud cannot be reached" | Offline, or the free limit is used up for today. It syncs on its own later. |
| `no such table` | `npx wrangler d1 migrations apply DB --remote`. |
| `npm test` hangs on Windows | An old `wrangler dev` holds the port or `.wrangler`. Stop it and delete `.wrangler/test`. |
| Only the rate-limit tests fail, with `internal error` logged (Windows) | The `--persist-to` path is past about 135 characters (§10). |
| "the boards read the fields the game's own save has" fails | `tests/fixtures/inventory_golden.json` is missing, or the game's save no longer has a field a board reads (`BOARDS` in `src/index.js`). |

---

## 19. Files

```
backend/
├── .gdignore                  keeps Godot out of this folder
├── leaderboard/
│   ├── README.md              this file
│   ├── wrangler.toml          the Worker, the D1 binding, rate limits, client ids, logs
│   ├── package.json           wrangler + the test / deploy scripts
│   ├── contract.json          every route: auth, fields sent, fields answered, statuses
│   ├── migrations/
│   │   ├── 0001_players.sql      the anonymous leaderboard
│   │   ├── 0002_accounts.sql     accounts, sessions, sign-ins in progress, saves
│   │   ├── 0003_boards.sql       the walls and deepest boards
│   │   ├── 0004_waitlist.sql     the waiting list
│   │   ├── 0005_login_pages.sql  a login's page id, and done
│   │   └── 0006_revisions.sql    a player's highest revision
│   ├── src/
│   │   └── index.js           the routes: sign-in, account, saves, boards, waiting list, pages
│   └── test.mjs               end to end on a local D1 with stand-in providers (npm test)
└── web/                       the web build's own Worker, serving it out of R2 (tools/web.py)

Scenes/cloud.gd                        the game's client
Scenes/UI/cloud_question.gd            the question between two saves
Scenes/UI/leaderboard_page.gd          the board page
tests/test_cloud.gd                    the game's side
tests/fixtures/inventory_golden.json   a save as the game writes it, read by test.mjs
```
