// The Worker end to end on a local D1 made fresh each run: `npm test`.
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { rmSync } from "node:fs";
import { after, before, test } from "node:test";
import { unstable_dev } from "wrangler";

const STATE = ".wrangler/test";
let worker;

before(async () => {
  rmSync(STATE, { recursive: true, force: true });
  execSync(`npx wrangler d1 migrations apply DB --local --persist-to ${STATE}`, { stdio: "ignore" });
  worker = await unstable_dev("src/index.js", {
    persistTo: STATE,
    experimental: { disableExperimentalWarning: true },
  });
});

after(() => worker?.stop());

// Each call from its own address unless told otherwise, so the registration limit bites only where
// a test means it to.
let address = 0;
function call(path, { method = "GET", body, token, ip = `10.0.0.${++address}` } = {}) {
  const headers = { "CF-Connecting-IP": ip };
  if (token) headers.Authorization = `Bearer ${token}`;
  return worker.fetch(path, { method, headers, body: body && JSON.stringify(body) });
}

async function join(name) {
  const response = await call("/players", { method: "POST", body: { name } });
  assert.equal(response.status, 201);
  return (await response.json()).token;
}

async function send(token, floors) {
  return (await call("/scores", { method: "POST", token, body: { floors } })).json();
}

test("ranks by floors, then by who reached them first", async () => {
  const ada = await join("Ada");
  const bo = await join("Bob");
  const cy = await join("Cyd");
  await send(bo, 44); // 3.14
  await send(ada, 44); // the same score, later
  await send(cy, 45); // 4.00: depth 3's Gollux
  const { top } = await (await call("/leaderboard")).json();
  assert.deepEqual(top.map((row) => [row.rank, row.name, row.floors]),
    [[1, "Cyd", 45], [2, "Bob", 44], [3, "Ada", 44]]);
});

test("a repeated or lower score keeps its place", async () => {
  const early = await join("Early");
  const late = await join("Late");
  await send(early, 1000);
  await send(late, 1000);
  await send(early, 1000); // a retry must not make Early later than Late
  const worse = await send(early, 3);
  assert.equal(worse.floors, 1000);
  const me = (await (await call("/leaderboard", { token: late })).json()).me;
  assert.deepEqual([me.name, me.rank], ["Late", 2]);
});

test("a player with no floor is not on the board", async () => {
  const token = await join("Nobody");
  const { top, me } = await (await call("/leaderboard", { token })).json();
  assert.equal(me.rank, null);
  assert.ok(!top.some((row) => row.name === "Nobody"));
});

test("names are unique whatever their case, and checked", async () => {
  await join("Gollux Fan");
  assert.equal((await call("/players", { method: "POST", body: { name: "gollux fan" } })).status, 409);
  for (const name of ["ab", "x".repeat(17), "<script>", ""]) {
    assert.equal((await call("/players", { method: "POST", body: { name } })).status, 400, name);
  }
});

test("a bad token or score is refused", async () => {
  assert.equal((await call("/scores", { method: "POST", token: "nope", body: { floors: 5 } })).status, 401);
  assert.equal((await call("/leaderboard", { token: "nope" })).status, 401);
  const token = await join("Honest");
  for (const floors of [-1, 1.5, "9", 2_000_000]) {
    assert.equal((await call("/scores", { method: "POST", token, body: { floors } })).status, 400, String(floors));
  }
});

test("one address may make three players a minute", async () => {
  const statuses = [];
  for (const name of ["Spam1", "Spam2", "Spam3", "Spam4"]) {
    statuses.push((await call("/players", { method: "POST", body: { name }, ip: "10.9.9.9" })).status);
  }
  assert.deepEqual(statuses, [201, 201, 201, 429]);
});
