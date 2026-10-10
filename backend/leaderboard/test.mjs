// The Worker end to end on a local D1 made fresh each run (`npm test`), with a stand-in for Google's
// and Discord's servers so the real sign-in code runs.
import assert from "node:assert/strict";
import { exec, execSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { readFileSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { promisify } from "node:util";
import { unstable_dev } from "wrangler";
import app from "./src/index.js";

// Kept short: on Windows a `--persist-to` path past about 135 characters breaks the local rate limiter.
const STATE = ".wrangler/test";
const LEGACY_TOKEN = "legacy-token-from-before-accounts";
// Every route, and what it is sent and answers: the same file the README points at.
const CONTRACT = JSON.parse(readFileSync(new URL("contract.json", import.meta.url), "utf8"));
let worker;
let provider;
// Where the Worker believes it is served from: its sign-in addresses start with it.
let origin;

// Google and Discord as the Worker sees them, checking what the real ones check: the client's id and
// secret, the one redirect address registered for it, and a code of their own, good once.
const CLIENTS = {
  google: {
    id: "google-id", secret: "google-secret", scope: "openid", subject: "sub",
    authorize: "https://accounts.google.com/o/oauth2/v2/auth", token: "/token", user: "/v1/userinfo",
  },
  discord: {
    id: "discord-id", secret: "discord-secret", scope: "identify", subject: "id",
    authorize: "https://discord.com/oauth2/authorize", token: "/api/oauth2/token", user: "/api/users/@me",
  },
};
// The codes a provider has handed a browser, and the access tokens they were swapped for: each
// `{key, subject, redirect}`.
const codes = new Map();
const accesses = new Map();

// The player signing in at the provider as `subject`, sent there by the Worker's redirect `location`:
// where on the Worker the provider sends the browser back to.
function grant(key, location, subject) {
  const client = CLIENTS[key];
  const asked = new URL(location);
  const redirect = `${origin}/auth/${key}/callback`;
  assert.deepEqual(
    [asked.origin + asked.pathname, ...["client_id", "redirect_uri", "response_type", "scope"].map((name) => asked.searchParams.get(name))],
    [client.authorize, client.id, redirect, "code", client.scope], "what the provider is asked");
  const code = randomBytes(8).toString("hex");
  codes.set(code, { key, subject, redirect });
  return `/auth/${key}/callback?code=${code}&state=${asked.searchParams.get("state")}`;
}

function startProvider() {
  return new Promise((resolve) => {
    const server = createServer((request, response) => {
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        const answer = (status, data) => {
          response.writeHead(status, { "Content-Type": "application/json" });
          response.end(JSON.stringify(data));
        };
        const [key, client] = Object.entries(CLIENTS)
          .find(([, each]) => [each.token, each.user].includes(request.url)) ?? [];
        if (!client) return answer(404, {});
        if (request.url === client.user) {
          const access = accesses.get((request.headers.authorization ?? "").replace("Bearer ", ""));
          return access?.key === key ? answer(200, { [client.subject]: access.subject }) : answer(401, {});
        }
        const form = new URLSearchParams(body);
        const issued = codes.get(form.get("code"));
        codes.delete(form.get("code"));
        if (issued?.key !== key || form.get("client_id") !== client.id || form.get("client_secret") !== client.secret
          || form.get("redirect_uri") !== issued.redirect || form.get("grant_type") !== "authorization_code") {
          return answer(400, { error: "invalid_grant" });
        }
        const access = randomBytes(8).toString("hex");
        accesses.set(access, issued);
        return answer(200, { access_token: access });
      });
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

before(async () => {
  provider = await startProvider();
  rmSync(STATE, { recursive: true, force: true });
  execSync(`npx wrangler d1 migrations apply DB --local --persist-to ${STATE}`, { stdio: "ignore" });
  // A player from the anonymous leaderboard, before accounts: a name and a token, never signed in.
  const legacyHash = createHash("sha256").update(LEGACY_TOKEN).digest("hex");
  execSync(`npx wrangler d1 execute DB --local --persist-to ${STATE} --command "INSERT INTO players `
    + `(id, name, floors, reached_at, created_at) VALUES (900, 'Oldtimer', 44, 1, 1); INSERT INTO sessions `
    + `(token_hash, player_id, created_at) VALUES ('${legacyHash}', 900, 1)"`, { stdio: "ignore" });
  worker = await unstable_dev("src/index.js", {
    persistTo: STATE,
    vars: {
      GOOGLE_CLIENT_ID: CLIENTS.google.id, GOOGLE_CLIENT_SECRET: CLIENTS.google.secret,
      DISCORD_CLIENT_ID: CLIENTS.discord.id, DISCORD_CLIENT_SECRET: CLIENTS.discord.secret,
      PROVIDER_ORIGIN: `http://127.0.0.1:${provider.address().port}`,
    },
    experimental: { disableExperimentalWarning: true },
  });
  origin = new URL((await read("/logins", { method: "POST" })).data.url).origin;
});

after(() => {
  worker?.stop();
  provider?.close();
});

// Each call from its own address unless told otherwise, so a rate limit bites only where meant to.
// `body` goes as JSON, whatever it is; `cookie` is the browser's. Every answer is kept in `answered`,
// as `["GET /path", status]`, for the contract's test to go over at the end.
let address = 0;
const answered = [];
async function call(path, { method = "GET", body, token, cookie, ip = `10.0.${Math.floor(++address / 250)}.${address % 250}` } = {}) {
  const headers = { "CF-Connecting-IP": ip };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (cookie) headers.Cookie = cookie;
  const response = await worker.fetch(path, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body), redirect: "manual",
  });
  answered.push([`${method} ${path.split("?")[0].replace(/^\/auth\/(google|discord)/, "/auth/{provider}")}`, response.status]);
  return response;
}

async function read(path, options) {
  const response = await call(path, options);
  return { status: response.status, data: await response.json() };
}

// A page's status and its heading.
async function page(path, options) {
  const response = await call(path, options);
  return [response.status, (await response.text()).match(/<h1>(.*?)<\/h1>/)?.[1]];
}

// Rows straight from the local database while the Worker runs: a list of them a statement (~3 s a call).
// Not `execSync`: the connection to the Worker dies if nothing reads it for that long.
async function sql(...statements) {
  const { stdout } = await promisify(exec)(
    `npx wrangler d1 execute DB --local --persist-to ${STATE} --json --command "${statements.join("; ")}"`);
  return JSON.parse(stdout).map((result) => result.results);
}

// A sign-in as far as the provider's own page: the game has started it, and the player's browser has
// opened the sign-in page, kept its cookie and pressed a provider's button.
async function atProvider(key = "google", legacy = undefined) {
  const started = await read("/logins", { method: "POST", token: legacy });
  assert.equal(started.status, 201);
  const { code, check, url } = started.data;
  assert.match(check, /^[A-Z0-9]{4}$/);
  const opened = await call(url.slice(origin.length));
  const html = await opened.text();
  const setCookie = opened.headers.get("Set-Cookie") ?? "";
  const cookie = setCookie.split(";")[0];
  const button = html.match(new RegExp(`href="(/auth/${key}\\?page=[0-9a-f]{64})"`))?.[1];
  assert.ok(html.includes(check) && button, "the page shows the letters and the way on");
  const away = await call(button, { cookie });
  assert.equal(away.status, 302);
  const poll = () => read("/logins/poll", { method: "POST", body: { code } });
  return { code, url, html, setCookie, cookie, button, location: away.headers.get("Location"), poll };
}

// The whole sign-in, as the game and the player's browser do it; the session's token.
async function signIn(subject, key = "google", legacy = undefined) {
  const login = await atProvider(key, legacy);
  assert.equal((await login.poll()).status, 202, "pending");
  assert.deepEqual(await page(grant(key, login.location, subject), { cookie: login.cookie }), [200, "Signed in"]);
  const polled = await login.poll();
  assert.deepEqual([polled.status, polled.data.provider], [200, key]);
  assert.equal((await login.poll()).status, 404, "collected once");
  return polled.data.token;
}

// A save as the game writes it, with the numbers the server reads.
function save({ kills = 10, play = 1000, floors = 0, walls = 0, deepest = 0, uniques = ["headsman"],
  achievements = { headsman: 1 } } = {}) {
  return JSON.stringify({
    version: 32, level: 20, saved_at: Date.now() / 1000, kills, play_seconds: play,
    dungeon_depth: Math.floor(floors / 15), dungeon_floors: floors, farthest_land: 5, deepest_level: deepest,
    uniques_found: uniques, achievements, tally: { clicks: 5, walls }, items: [],
  });
}

async function upload(token, base, inventory, extra = {}) {
  return read("/save", { method: "PUT", token, body: { base_revision: base, inventory, map: "{\"map\":1}", ...extra } });
}

// The statuses of `count` calls to one route from one address. A limiter counts in fixed minutes, so
// a limit's worth of calls may straddle two of them: twice the limit and one more cannot.
async function statusesOf(count, path, options) {
  const statuses = [];
  for (let at = 0; at < count; at++) {
    const response = await call(path, options);
    await response.text();
    statuses.push(response.status);
  }
  return statuses;
}

function assertLimited(statuses, limit, ok) {
  const first = statuses.indexOf(429);
  assert.ok(first >= limit, `none refused before call ${limit + 1}, and one refused (${statuses})`);
  assert.ok(statuses.slice(0, first).every((status) => status === ok));
}

// Every field of a reply by name, as contract.json writes them: a dot goes inside an object, `[]` is
// each row of a list.
function fieldsOf(value, at = "") {
  if (Array.isArray(value)) return fieldsOf(value[0], `${at}[]`);
  if (typeof value === "object" && value !== null) {
    return Object.entries(value).flatMap(([key, inner]) => fieldsOf(inner, at ? `${at}.${key}` : key));
  }
  return [at];
}

test("signing in with the same account on two devices is one player", async () => {
  const first = await signIn("google-ada");
  const second = await signIn("google-ada");
  assert.notEqual(first, second, "a session a device");
  const me = await read("/me", { token: second });
  assert.deepEqual([me.data.providers, me.data.name, me.data.save], [["google"], null, null]);
  const other = await signIn("google-ada", "discord");
  assert.deepEqual((await read("/me", { token: other })).data.providers, ["discord"], "Discord's ada is someone else");
});

test("an anonymous board name is kept by its device's first sign-in, and its old score is not", async () => {
  const token = await signIn("google-oldtimer", "google", LEGACY_TOKEN);
  const me = (await read("/me", { token })).data;
  assert.deepEqual([me.name, me.floors, me.rank], ["Oldtimer", 0, null]);
});

test("a sign-in page for a login nobody started is refused", async () => {
  assert.equal((await call("/login?page=nothing")).status, 404);
  assert.equal((await call("/auth/google?page=nothing")).status, 404);
  assert.equal((await call("/auth/google/callback?code=x&state=nothing")).status, 404);
  assert.equal((await read("/logins/poll", { method: "POST", body: { code: "nothing" } })).status, 404);
});

test("nothing the browser is shown collects the session", async () => {
  const login = await atProvider();
  const shown = { page: new URL(login.url).searchParams.get("page"), state: new URL(login.location).searchParams.get("state") };
  for (const seen of [login.url, login.html, login.button, login.location]) {
    assert.ok(!seen.includes(login.code), "the game's code is in no address and on no page");
  }
  assert.deepEqual(await page(grant("google", login.location, "google-watched"), { cookie: login.cookie }), [200, "Signed in"]);
  for (const [what, value] of Object.entries(shown)) {
    assert.equal((await read("/logins/poll", { method: "POST", body: { code: value } })).status, 404, `polling with the ${what}`);
  }
  assert.equal((await login.poll()).status, 200, "the game's own code still does");
});

test("only the browser that was shown the check letters goes on to a provider, or comes back from one", async () => {
  const login = await atProvider();
  assert.match(login.setCookie, /^__Host-login=[0-9a-f]{64}; Max-Age=600; Path=\/; Secure; HttpOnly; SameSite=Lax$/);
  const other = await atProvider();
  for (const cookie of [undefined, other.cookie]) {
    assert.equal((await call(login.button, { cookie })).status, 403, "a link straight past the page");
    assert.deepEqual(await page(grant("google", login.location, "google-phished"), { cookie }), [403, "Not signed in"],
      "the provider's own link, sent by someone else");
  }
  assert.equal((await login.poll()).status, 202, "nobody was signed in");
  assert.deepEqual(await page(grant("google", login.location, "google-phished"), { cookie: login.cookie }), [200, "Signed in"]);
});

test("a finished sign-in holds no token: the session is made as the game collects it", async () => {
  const login = await atProvider();
  assert.deepEqual(await page(grant("google", login.location, "google-tokenless"), { cookie: login.cookie }), [200, "Signed in"]);
  const [[held], [sessions]] = await sql(
    "SELECT COUNT(*) AS n FROM logins WHERE token IS NOT NULL",
    "SELECT COUNT(*) AS n FROM sessions WHERE player_id = (SELECT player_id FROM identities WHERE subject = 'google-tokenless')");
  assert.deepEqual([held.n, sessions.n], [0, 0], "no token and no session while the login waits");
  const { token } = (await login.poll()).data;
  assert.deepEqual((await read("/me", { token })).data.providers, ["google"]);
});

test("a sign-in cancelled, refused by the provider or played back signs nobody in", async () => {
  const login = await atProvider();
  const state = new URL(login.location).searchParams.get("state");
  const cookie = login.cookie;
  assert.deepEqual(await page(`/auth/google/callback?error=access_denied&state=${state}`, { cookie }), [400, "Not signed in"]);
  assert.deepEqual(await page(`/auth/google/callback?code=never-issued&state=${state}`, { cookie }), [502, "Not signed in"]);
  assert.equal((await login.poll()).status, 202);
  const back = grant("google", login.location, "google-replayed");
  assert.deepEqual(await page(back, { cookie }), [200, "Signed in"]);
  assert.deepEqual(await page(back, { cookie }), [404, "Sign-in expired"], "the state is good once");
  // Nor is the provider's code good twice, under another login's state.
  const second = await atProvider();
  const replayed = back.replace(/state=.*/, `state=${new URL(second.location).searchParams.get("state")}`);
  assert.deepEqual(await page(replayed, { cookie: second.cookie }), [502, "Not signed in"]);
  assert.equal((await second.poll()).status, 202);
});

test("names are checked and unique whatever their case", async () => {
  const token = await signIn("google-namer");
  assert.equal((await read("/me/name", { method: "PUT", token, body: { name: "Kobold King" } })).status, 200);
  const rival = await signIn("google-rival");
  assert.equal((await read("/me/name", { method: "PUT", token: rival, body: { name: "kobold king" } })).status, 409);
  for (const name of ["ab", "x".repeat(17), "<b>", ""]) {
    assert.equal((await read("/me/name", { method: "PUT", token: rival, body: { name } })).status, 400, name);
  }
});

test("a save goes up and comes back byte for byte, and the board keeps the deepest", async () => {
  const token = await signIn("google-saver");
  await read("/me/name", { method: "PUT", token, body: { name: "Saver" } });
  const first = save({ floors: 44 });
  const put = await upload(token, 0, first);
  assert.deepEqual([put.status, put.data.revision, put.data.floors], [200, 1, 44], "a first save counts in full");
  const got = await read("/save", { token });
  assert.deepEqual([got.data.revision, got.data.inventory, got.data.map], [1, first, "{\"map\":1}"]);
  const shallower = await upload(token, 1, save({ floors: 40 }));
  assert.deepEqual([shallower.status, shallower.data.floors], [200, 44], "the board never goes down");
  const me = (await read("/me", { token })).data;
  assert.deepEqual([me.save.revision, me.save.summary.dungeon_floors], [2, 40]);
});

test("a stale save is a conflict until this device's is chosen", async () => {
  const token = await signIn("google-two-devices");
  await upload(token, 0, save({ kills: 10 }));
  await upload(token, 1, save({ kills: 20 })); // the other device
  const stale = await upload(token, 1, save({ kills: 15 }));
  assert.deepEqual([stale.status, stale.data.revision, stale.data.summary.level], [409, 2, 20]);
  const replaced = await upload(token, 1, save({ kills: 15 }), { replace: true });
  assert.deepEqual([replaced.status, replaced.data.revision], [200, 3]);
  // Two devices at the same moment: one is taken, and the other is a conflict like any other.
  const raced = await Promise.all([upload(token, 3, save()), upload(token, 3, save())]);
  assert.deepEqual(raced.map((reply) => reply.status).sort(), [200, 409]);
  assert.equal(raced.find((reply) => reply.status === 409).data.revision, 4);
});

test("a save is taken at its word, and only one that is not a save is turned away", async () => {
  const token = await signIn("google-trusted");
  await upload(token, 0, save({ kills: 100, play: 1000, floors: 15 }));
  const less = await upload(token, 1, save({ kills: 50, play: 10, floors: 1015, uniques: [], achievements: {} }));
  assert.deepEqual([less.status, less.data.floors], [200, 1015], "less of everything, and floors faster than time");
  for (const inventory of ["[]", "5", "null", "not json"]) {
    assert.equal((await upload(token, 2, inventory)).status, 400, inventory);
  }
  const big = await upload(token, 2, save(), { map: "x".repeat(4_000_001) });
  assert.deepEqual([big.status, big.data.error], [413, "That save is far too big"]);
});

test("a reset empties the cloud, keeps the board, and never gives a revision out twice", async () => {
  const token = await signIn("google-resetter");
  await read("/me/name", { method: "PUT", token, body: { name: "Resetter" } });
  await upload(token, 0, save({ floors: 30 }));
  await upload(token, 1, save({ floors: 31 }));
  assert.equal((await read("/save", { method: "DELETE", token })).status, 200);
  const me = (await read("/me", { token })).data;
  assert.deepEqual([me.save, me.floors, me.rank !== null], [null, 31, true], "no save, and the board as it was");
  // Another device, still at revision 2 and not yet told: a conflict with no save to show, not an error.
  const stale = await upload(token, 2, save({ floors: 31 }));
  assert.deepEqual([stale.status, stale.data.revision, stale.data.summary], [409, 0, null]);
  // The fresh game is a first save, numbered on from the last: at 2 again, that device would take it
  // for the save it grew from.
  const fresh = await upload(token, 0, save({ kills: 1, play: 10 }));
  assert.deepEqual([fresh.status, fresh.data.revision], [200, 3]);
  assert.equal((await upload(token, 2, save({ floors: 31 }))).status, 409, "and the other device is asked");
});

test("a body that is not a JSON object is turned away, not an error", async () => {
  const token = await signIn("google-garbler");
  const routes = [["POST", "/logins/poll"], ["PUT", "/me/name"], ["PUT", "/save"], ["POST", "/waitlist"]];
  for (const [method, path] of routes) {
    // Nothing at all, then JSON that is no object.
    for (const body of [undefined, null, 5, "text", [1]]) {
      assert.equal((await read(path, { method, token, body })).status, 400, `${method} ${path} ${JSON.stringify(body)}`);
    }
  }
});

test("every signed-in route turns away no token and a wrong one", async () => {
  const signedIn = CONTRACT.routes.filter((route) => route.auth === "bearer");
  assert.ok(signedIn.length >= 7);
  for (const { method, path } of signedIn) {
    for (const token of [undefined, "f".repeat(64)]) {
      assert.equal((await read(path, { method, token })).status, 401, `${method} ${path} with ${token}`);
    }
  }
  assert.equal((await read("/leaderboard", { token: "f".repeat(64) })).status, 401, "a board read as nobody known");
});

test("one player's calls never touch another's save, name or account", async () => {
  const [ada, bob] = [await signIn("google-apart-ada"), await signIn("google-apart-bob")];
  const bobs = save({ kills: 222, floors: 9 });
  await read("/me/name", { method: "PUT", token: bob, body: { name: "Apart Bob" } });
  await upload(bob, 0, bobs);
  // Everything a signed-in player can do, done by ada.
  const adas = save({ kills: 111 });
  await upload(ada, 0, save());
  assert.equal((await upload(ada, 0, adas, { replace: true })).status, 200);
  assert.equal((await read("/save", { token: ada })).data.inventory, adas, "ada reads her own");
  assert.equal((await read("/me/name", { method: "PUT", token: ada, body: { name: "apart bob" } })).status, 409);
  assert.equal((await read("/save", { method: "DELETE", token: ada })).status, 200);
  assert.equal((await read("/me", { method: "DELETE", token: ada })).status, 200);
  const [got, me] = [await read("/save", { token: bob }), await read("/me", { token: bob })];
  assert.deepEqual([got.status, got.data.revision, got.data.inventory], [200, 1, bobs]);
  assert.deepEqual([me.status, me.data.name, me.data.floors, me.data.save.revision], [200, "Apart Bob", 9, 1]);
});

test("the board is signed-in players with a name, by floors then by who got there first", async () => {
  // In order, so Early reaches 1000 before Late does.
  for (const [name, floors] of [["Early", 1000], ["Late", 1000], ["Deep", 1001]]) {
    const token = await signIn(`google-board-${name}`);
    await read("/me/name", { method: "PUT", token, body: { name } });
    await upload(token, 0, save({ floors }));
  }
  const { top } = (await read("/leaderboard")).data;
  const scores = top.filter((row) => ["Early", "Late", "Deep"].includes(row.name)).map((row) => [row.name, row.floors]);
  assert.deepEqual(scores, [["Deep", 1001], ["Early", 1000], ["Late", 1000]]);
  assert.ok(!top.some((row) => row.name === "Oldtimer" || row.name === null), "no anonymous or nameless rows");
});

test("the walls and deepest boards rank by their own score, each only rising", async () => {
  const token = await signIn("google-boards-climber");
  await read("/me/name", { method: "PUT", token, body: { name: "Climber" } });
  await upload(token, 0, save({ walls: 7, deepest: 12 }));
  await upload(token, 1, save({ walls: 3, deepest: 30 }));
  const walls = (await read("/leaderboard?board=walls", { token })).data;
  const deepest = (await read("/leaderboard?board=deepest", { token })).data;
  assert.deepEqual(walls.top.find((row) => row.name === "Climber").score, 7, "walls never go down");
  assert.deepEqual([deepest.top[0].name, deepest.top[0].score], ["Climber", 30]);
  assert.deepEqual([walls.me.score, walls.me.rank, deepest.me.score, deepest.me.rank], [7, 1, 30, 1]);
  assert.ok(!walls.top.some((row) => row.score === 0), "nobody on a board with nothing on it");
  assert.equal((await read("/leaderboard?board=constructor")).status, 404);
});

// The boards score a save by fields whose names are the game's (`Inventory.save`, in Godot). The
// golden save is one the game wrote: a field renamed there would score 0 here for ever, and nothing
// else would say so.
test("the boards read the fields the game's own save has (tests/fixtures/inventory_golden.json)", async () => {
  const golden = readFileSync(new URL("../../tests/fixtures/inventory_golden.json", import.meta.url), "utf8");
  const written = JSON.parse(golden);
  const expected = { gollux: written.dungeon_floors, walls: written.tally?.walls, deepest: written.deepest_level };
  const token = await signIn("google-golden");
  await read("/me/name", { method: "PUT", token, body: { name: "Golden" } });
  assert.equal((await upload(token, 0, golden)).status, 200);
  for (const [board, score] of Object.entries(expected)) {
    assert.ok(Number.isInteger(score) && score > 0, `${board}: the golden save's own number is above zero (${score})`);
    const { top } = (await read(`/leaderboard?board=${board}`)).data;
    assert.equal(top.find((row) => row.name === "Golden")?.score, score, `the ${board} board`);
  }
});

test("signing out and deleting the account end the session", async () => {
  const token = await signIn("google-leaver");
  assert.equal((await read("/sessions/me", { method: "DELETE", token })).status, 200);
  assert.equal((await read("/me", { token })).status, 401);
  const again = await signIn("google-leaver");
  await upload(again, 0, save());
  assert.equal((await read("/me", { method: "DELETE", token: again })).status, 200);
  assert.equal((await read("/me", { token: again })).status, 401);
  const fresh = await signIn("google-leaver");
  assert.equal((await read("/me", { token: fresh })).data.save, null, "a new account, with nothing left of the old");
});

// `deleteMe` names its tables. One added later with a `player_id` and not named there fails this.
test("deleting the account empties every table that keeps a player's rows", async () => {
  const token = await signIn("google-erased");
  await upload(token, 0, save());
  await read("/logins", { method: "POST", token }); // a sign-in under way, started as this player
  const [tables, [{ player_id: id }]] = await sql(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND instr(sql, 'player_id') > 0",
    "SELECT player_id FROM identities WHERE subject = 'google-erased'");
  const names = tables.map((table) => table.name);
  assert.ok(["sessions", "identities", "saves", "logins"].every((name) => names.includes(name)), `found ${names}`);
  const rows = async () => (await sql(...names.map((name) => `SELECT COUNT(*) AS n FROM ${name} WHERE player_id = ${id}`),
    `SELECT COUNT(*) AS n FROM players WHERE id = ${id}`)).map(([count]) => count.n);
  assert.ok((await rows()).every((count) => count > 0), "the player has a row in each, or this test proves nothing");
  assert.equal((await read("/me", { method: "DELETE", token })).status, 200);
  assert.deepEqual(await rows(), [...names, "players"].map(() => 0));
});

test("the web build, served from another origin, may call", async () => {
  const preflight = await call("/me", { method: "OPTIONS" });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get("Access-Control-Allow-Headers"), /Authorization/);
  assert.equal((await call("/leaderboard")).headers.get("Access-Control-Allow-Origin"), "*");
});

test("the waiting list takes an email, again without complaint, and turns away what is not one", async () => {
  const join = (email) => read("/waitlist", { method: "POST", body: { email } });
  assert.equal((await join("kobold@example.com")).status, 201);
  assert.equal((await join("KOBOLD@example.com")).status, 201);
  assert.equal((await join("not an email")).status, 400);
  assert.equal((await join(`${"a".repeat(250)}@b.cd`)).status, 400);
});

test("one address may start ten sign-ins a minute", async () => {
  assertLimited(await statusesOf(21, "/logins", { method: "POST", ip: "10.9.9.9" }), 10, 201);
});

test("one address may give the waiting list five emails a minute", async () => {
  assertLimited(await statusesOf(11, "/waitlist", { method: "POST", ip: "10.9.9.8", body: { email: "many@example.com" } }), 5, 201);
});

test("one address may call sixty times a minute", async () => {
  assertLimited(await statusesOf(121, "/privacy", { ip: "10.9.9.7" }), 60, 200);
});

// The Worker's own code with a limiter that throws, as Cloudflare's can: no route here needs more.
test("a rate limiter that fails lets the call through", async (context) => {
  const logged = context.mock.method(console, "error", () => {});
  const broken = { limit: async () => { throw new Error("internal error"); } };
  const response = await app.fetch(new Request("http://worker/privacy"), { REQUEST_LIMIT: broken });
  assert.deepEqual([response.status, logged.mock.callCount()], [200, 1], "answered, and the fault logged");
});

// The happy path of every route in contract.json, in its order: the status it lists first, exactly the
// reply fields it lists, sent exactly the fields it lists. Then every answer any test above was given:
// each a status its route lists. Last for that, and as it ends by deleting its account.
test("every route answers as contract.json says", async () => {
  const source = readFileSync(new URL("src/index.js", import.meta.url), "utf8");
  const routed = [...source.matchAll(/^  "([A-Z]+ \/[^"]*)": /gm)].map((match) => match[1]);
  const listed = CONTRACT.routes.map((route) => `${route.method} ${route.path}`);
  assert.deepEqual(listed.filter((key) => !key.includes("{provider}")).sort(), routed.sort(), "the routes of src/index.js");

  const other = await signIn("google-contract");
  const replies = {};
  const token = () => replies["POST /logins/poll"].data.token;
  const cookie = () => replies["GET /login"].headers.get("Set-Cookie").split(";")[0];
  const calls = {
    "POST /logins": () => ({}),
    "GET /login": () => ({ query: { page: new URL(replies["POST /logins"].data.url).searchParams.get("page") } }),
    "GET /auth/{provider}": () => ({ query: replies["GET /login"].sent.query, cookie: cookie() }),
    "GET /auth/{provider}/callback": () => ({
      query: Object.fromEntries(new URL(grant("google", replies["GET /auth/{provider}"].headers.get("Location"), "google-contract"),
        origin).searchParams),
      cookie: cookie(),
    }),
    "POST /logins/poll": () => ({ body: { code: replies["POST /logins"].data.code } }),
    "PUT /me/name": () => ({ token: token(), body: { name: "Contract" } }),
    "PUT /save": () => ({ token: token(), body: { base_revision: 0, inventory: save({ floors: 3 }), map: "{}" } }),
    "GET /me": () => ({ token: token() }),
    "GET /save": () => ({ token: token() }),
    "GET /leaderboard": () => ({ token: token(), query: { board: "gollux", limit: "5" } }),
    "DELETE /save": () => ({ token: token() }),
    "GET /privacy": () => ({}),
    "POST /waitlist": () => ({ body: { email: "contract@example.com" } }),
    "DELETE /sessions/me": () => ({ token: other }),
    "DELETE /me": () => ({ token: token() }),
  };
  for (const route of CONTRACT.routes) {
    const key = `${route.method} ${route.path}`;
    assert.ok(calls[key], `${key} is called here`);
    const sent = calls[key]();
    for (const part of ["query", "body"]) {
      const names = route[part] ?? [];
      assert.deepEqual(Object.keys(sent[part] ?? {}).filter((name) => !names.includes(`${name}?`)),
        names.filter((name) => !name.endsWith("?")), `${key} is sent its ${part}`);
    }
    const path = route.path.replace("{provider}", "google") + (sent.query ? `?${new URLSearchParams(sent.query)}` : "");
    const response = await call(path, { method: route.method, ...sent });
    const text = await response.text();
    const data = (response.headers.get("Content-Type") ?? "").startsWith("application/json") ? JSON.parse(text) : null;
    replies[key] = { sent, headers: response.headers, data };
    assert.equal(response.status, route.statuses[0], key);
    if (route.reply === "redirect") assert.ok(response.headers.get("Location"), key);
    else if (route.reply === "html") assert.match(text, /^<!doctype html>/, key);
    else assert.deepEqual(fieldsOf(data).sort(), [...route.reply].sort(), `${key} answers its fields`);
  }
  for (const [key, status] of answered.filter(([key]) => !key.startsWith("OPTIONS"))) {
    const route = CONTRACT.routes.find((each) => `${each.method} ${each.path}` === key);
    assert.ok(route?.statuses.concat(429).includes(status), `${key} answered ${status}, which contract.json does not list`);
  }
});
