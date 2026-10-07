// The Worker end to end on a local D1 made fresh each run (`npm test`), with a stand-in for Google's
// and Discord's servers so the real sign-in code runs.
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { createHash } from "node:crypto";
import { rmSync } from "node:fs";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { unstable_dev } from "wrangler";

const STATE = ".wrangler/test";
const LEGACY_TOKEN = "legacy-token-from-before-accounts";
let worker;
let provider;

// Google and Discord as the Worker sees them: the code handed back is the account's id, the access
// token is the id again, and asking who it belongs to answers with it.
function startProvider() {
  return new Promise((resolve) => {
    const server = createServer((request, response) => {
      let body = "";
      request.on("data", (chunk) => { body += chunk; });
      request.on("end", () => {
        response.setHeader("Content-Type", "application/json");
        const bearer = (request.headers.authorization ?? "").replace("Bearer ", "");
        if (request.url.endsWith("/token")) {
          response.end(JSON.stringify({ access_token: new URLSearchParams(body).get("code") }));
        } else if (request.url === "/v1/userinfo") {
          response.end(JSON.stringify({ sub: bearer }));
        } else if (request.url === "/api/users/@me") {
          response.end(JSON.stringify({ id: bearer }));
        } else {
          response.statusCode = 404;
          response.end("{}");
        }
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
      GOOGLE_CLIENT_ID: "google-id", GOOGLE_CLIENT_SECRET: "google-secret",
      DISCORD_CLIENT_ID: "discord-id", DISCORD_CLIENT_SECRET: "discord-secret",
      PROVIDER_ORIGIN: `http://127.0.0.1:${provider.address().port}`,
    },
    experimental: { disableExperimentalWarning: true },
  });
});

after(() => {
  worker?.stop();
  provider?.close();
});

// Each call from its own address unless told otherwise, so a rate limit bites only where meant to.
let address = 0;
function call(path, { method = "GET", body, token, ip = `10.0.${Math.floor(++address / 250)}.${address % 250}` } = {}) {
  const headers = { "CF-Connecting-IP": ip };
  if (token) headers.Authorization = `Bearer ${token}`;
  return worker.fetch(path, { method, headers, body: body && JSON.stringify(body), redirect: "manual" });
}

async function read(path, options) {
  const response = await call(path, options);
  return { status: response.status, data: await response.json() };
}

// The whole sign-in, as the game and the player's browser do it; the session's token.
async function signIn(subject, key = "google", legacy = undefined) {
  const started = await read("/logins", { method: "POST", token: legacy });
  assert.equal(started.status, 201);
  const { code, check } = started.data;
  assert.match(check, /^[A-Z0-9]{4}$/);
  assert.equal((await read("/logins/poll", { method: "POST", body: { code } })).status, 202, "pending");
  const page = await (await call(`/login?code=${code}`)).text();
  assert.ok(page.includes(check) && page.includes(`/auth/${key}?code=`), "the page shows the letters");
  const away = await call(`/auth/${key}?code=${code}`);
  assert.equal(away.status, 302);
  const state = new URL(away.headers.get("Location")).searchParams.get("state");
  const back = await call(`/auth/${key}/callback?code=${encodeURIComponent(subject)}&state=${state}`);
  assert.ok((await back.text()).includes("signed in"), "the callback signs in");
  const polled = await read("/logins/poll", { method: "POST", body: { code } });
  assert.equal(polled.status, 200);
  assert.equal((await read("/logins/poll", { method: "POST", body: { code } })).status, 404, "collected once");
  return polled.data.token;
}

// A save as the game writes it, with the numbers the server reads.
function save({ kills = 10, play = 1000, floors = 0, uniques = ["headsman"], achievements = { headsman: 1 } } = {}) {
  return JSON.stringify({
    version: 30, level: 20, saved_at: Date.now() / 1000, kills, play_seconds: play,
    dungeon_depth: Math.floor(floors / 15), dungeon_floors: floors, farthest_land: 5,
    uniques_found: uniques, achievements, tally: { clicks: 5 }, items: [],
  });
}

async function upload(token, base, inventory, extra = {}) {
  return read("/save", { method: "PUT", token, body: { base_revision: base, inventory, map: "{\"map\":1}", ...extra } });
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

test("a sign-in page for a code nobody started is refused", async () => {
  assert.equal((await call("/login?code=nothing")).status, 404);
  assert.equal((await call("/auth/google?code=nothing")).status, 404);
  assert.equal((await call("/auth/google/callback?code=x&state=nothing")).status, 404);
  assert.equal((await read("/logins/poll", { method: "POST", body: { code: "nothing" } })).status, 404);
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
  assert.deepEqual([stale.status, stale.data.revision], [409, 2]);
  const replaced = await upload(token, 1, save({ kills: 15 }), { replace: true });
  assert.deepEqual([replaced.status, replaced.data.revision], [200, 3]);
});

test("a save is taken at its word, and only one that is not a save is turned away", async () => {
  const token = await signIn("google-trusted");
  await upload(token, 0, save({ kills: 100, play: 1000, floors: 15 }));
  const less = await upload(token, 1, save({ kills: 50, play: 10, floors: 1015, uniques: [], achievements: {} }));
  assert.deepEqual([less.status, less.data.floors], [200, 1015], "less of everything, and floors faster than time");
  for (const inventory of ["[]", "5", "null", "not json"]) {
    assert.equal((await upload(token, 2, inventory)).status, 400, inventory);
  }
  // Reset save: the cloud forgets, and the next upload is a first one again.
  assert.equal((await read("/save", { method: "DELETE", token })).status, 200);
  assert.equal((await upload(token, 0, save({ kills: 1, play: 10 }))).data.revision, 1);
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

test("the web build, served from another origin, may call", async () => {
  const preflight = await call("/me", { method: "OPTIONS" });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get("Access-Control-Allow-Headers"), /Authorization/);
  assert.equal((await call("/leaderboard")).headers.get("Access-Control-Allow-Origin"), "*");
});

// The limiter counts in fixed minutes, so ten calls may straddle two of them: 21 cannot.
test("one address may start ten sign-ins a minute", async () => {
  const statuses = [];
  for (let at = 0; at < 21; at++) statuses.push((await read("/logins", { method: "POST", ip: "10.9.9.9" })).status);
  const first = statuses.indexOf(429);
  assert.ok(first >= 10, `none refused before the tenth (${statuses})`);
  assert.ok(statuses.slice(0, first).every((status) => status === 201));
});
