// Kobold Clicker's backend: signing in with Google or Discord, cloud saves, and the leaderboards
// (Gollux, walls broken, deepest tile), scored from those saves. A save is taken at its word: the player is trusted not to
// cheat. The API, the sign-in flow and how it is deployed: ../README.md.

const NAME = /^[A-Za-z0-9 _-]{3,16}$/;
// Something@something.something, no spaces, at most the 254 characters an address may be.
const EMAIL = /^[^\s@]{1,64}@[^\s@]+\.[^\s@]+$/;
const TOP = 100;
const LOGIN_MS = 10 * 60 * 1000;
// Revisions kept a player, for putting an older one back by hand.
const KEEP_REVISIONS = 10;
// A save is ~140 KB of JSON; a body past this is not one.
const MOST_BODY = 4_000_000;
// The boards: each a column of `players` it ranks by, the column of when that last rose, and how a save
// gives its score. Only these names reach the SQL.
const BOARDS = {
  gollux: { score: "floors", at: "reached_at", of: (save) => number(save, "dungeon_floors") },
  walls: { score: "walls", at: "walls_at", of: (save) => number(Object(save.tally), "walls") },
  deepest: { score: "deepest", at: "deepest_at", of: (save) => number(save, "deepest_level") },
};
// The four letters both screens show. No 0/O, 1/I/L, 2/Z, 5/S, 6/G, 8/B to mix up.
const CHECK_LETTERS = "ACDEFHJKMNPRTUVWXY3479";

// What each provider is asked. Only its own id for the player comes back: never an email or a name.
const PROVIDERS = {
  google: {
    name: "Google",
    authorize: "https://accounts.google.com/o/oauth2/v2/auth",
    token: "https://oauth2.googleapis.com/token",
    user: "https://openidconnect.googleapis.com/v1/userinfo",
    scope: "openid",
    subject: (user) => user.sub,
  },
  discord: {
    name: "Discord",
    authorize: "https://discord.com/oauth2/authorize",
    token: "https://discord.com/api/oauth2/token",
    user: "https://discord.com/api/users/@me",
    scope: "identify",
    subject: (user) => user.id,
  },
};

const ROUTES = {
  "POST /logins": startLogin,
  "GET /login": loginPage,
  "POST /logins/poll": pollLogin,
  "GET /me": signedIn(getMe),
  "PUT /me/name": signedIn(setName),
  "DELETE /me": signedIn(deleteMe),
  "DELETE /sessions/me": signedIn(signOut),
  "GET /save": signedIn(getSave),
  "PUT /save": signedIn(putSave),
  "DELETE /save": signedIn(deleteSave),
  "GET /leaderboard": board,
  "GET /privacy": privacy,
  "POST /waitlist": joinWaitlist,
};

// The web build is served from another origin (../web). Sessions are bearer tokens, never cookies,
// so any page may call: a stolen token is no more use from one origin than another.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const ip = request.headers.get("CF-Connecting-IP") ?? "local";
    const url = new URL(request.url);
    try {
      if (!(await allowed(env.REQUEST_LIMIT, ip))) {
        return json({ error: "Too many requests, try again in a minute" }, 429);
      }
      const route = ROUTES[`${request.method} ${url.pathname}`];
      if (route) return await route(request, env, url, ip);
      const auth = url.pathname.match(/^\/auth\/(google|discord)(\/callback)?$/);
      if (auth && request.method === "GET") {
        return await (auth[2] ? callback : toProvider)(request, env, url, auth[1]);
      }
      return json({ error: "Not found" }, 404);
    } catch (error) {
      // A body that could not be read has its answer thrown (`bodyOf`).
      if (error instanceof Response) return error;
      console.error(error);
      return json({ error: "Server error" }, 500);
    }
  },
};

// ---------------------------------------------------------------------------------------------------
// Signing in. The game starts a login and opens the browser at its page; the player picks a provider
// and signs in there; the callback finds (or makes) their account and marks the login done; the game,
// polling with its code, is handed a new session's token. The check letters on both screens are what
// stop a sign-in link someone else sent from signing *their* game in as you.
//
// A login has two secrets. The game's `code` collects the session, and is only ever sent in the body
// of a poll. The browser gets the page's own id: an address bar, a history or a stream shows nothing
// that can take the session. And the page leaves a cookie, so only a browser that was shown the check
// letters can go on to a provider or come back from one (`sameBrowser`).

const LOGIN_COOKIE = "__Host-login";

async function startLogin(request, env, url, ip) {
  if (!(await allowed(env.LOGIN_LIMIT, ip))) {
    return json({ error: "Too many sign-ins from here, try again in a minute" }, 429);
  }
  await env.DB.prepare("DELETE FROM logins WHERE created_at < ?").bind(Date.now() - LOGIN_MS).run();
  const code = randomHex();
  const pageId = randomHex();
  const check = [...crypto.getRandomValues(new Uint8Array(4))]
    .map((byte) => CHECK_LETTERS[byte % CHECK_LETTERS.length]).join("");
  // A device with an anonymous board name from before accounts sends its old token, to keep the name.
  const legacy = await authed(request, env);
  await env.DB.prepare(
    "INSERT INTO logins (code_hash, page_hash, check_code, player_id, created_at) VALUES (?, ?, ?, ?, ?)",
  ).bind(await sha256(code), await sha256(pageId), check, legacy?.id ?? null, Date.now()).run();
  return json({ code, check, url: `${url.origin}/login?page=${pageId}` }, 201);
}

// A login still waiting for its player, found by its page's id or by the provider's state.
async function pendingLogin(env, column, value) {
  return env.DB.prepare(
    `SELECT * FROM logins WHERE ${column} = ? AND done = 0 AND created_at >= ?`,
  ).bind(value, Date.now() - LOGIN_MS).first();
}

async function loginPage(request, env, url) {
  const pageId = url.searchParams.get("page") ?? "";
  const login = await pendingLogin(env, "page_hash", await sha256(pageId));
  if (!login) return expired();
  const buttons = Object.entries(PROVIDERS)
    .filter(([key]) => env[`${key.toUpperCase()}_CLIENT_ID`])
    .map(([key, provider]) => `<a class="button" href="/auth/${key}?page=${encodeURIComponent(pageId)}">Continue with ${provider.name}</a>`)
    .join("");
  return page("Sign in to Kobold Clicker",
    `<p>Check that your game shows these letters:</p><p class="check">${login.check_code}</p>
     <p>If it does not, or you did not start this, close this page.</p>${buttons}
     <p class="small">Only your account's id is kept, never your email or name. <a href="/privacy">Privacy</a></p>`,
    200, {
      // `__Host-`: only this very host can have set it, over HTTPS. Lax, so that it comes back with the
      // provider's redirect.
      "Set-Cookie": `${LOGIN_COOKIE}=${login.page_hash}; Max-Age=${LOGIN_MS / 1000}; Path=/; Secure; HttpOnly; SameSite=Lax`,
    });
}

// Whether this browser is the one `login`'s page was last opened in, and so one that was shown its
// check letters. A link straight to a provider, sent by someone else, comes without the cookie.
function sameBrowser(request, login) {
  return login.page_hash !== null
    && (request.headers.get("Cookie") ?? "").split(/;\s*/).includes(`${LOGIN_COOKIE}=${login.page_hash}`);
}

async function toProvider(request, env, url, key) {
  const login = await pendingLogin(env, "page_hash", await sha256(url.searchParams.get("page") ?? ""));
  if (!login) return expired();
  if (!sameBrowser(request, login)) return elsewhere();
  const clientId = env[`${key.toUpperCase()}_CLIENT_ID`];
  if (!clientId) return page("Not available", "<p>This way of signing in is not set up yet.</p>", 404);
  const state = randomHex();
  await env.DB.prepare("UPDATE logins SET state = ? WHERE code_hash = ?").bind(state, login.code_hash).run();
  const provider = PROVIDERS[key];
  const to = new URL(provider.authorize);
  to.search = new URLSearchParams({
    client_id: clientId,
    redirect_uri: `${url.origin}/auth/${key}/callback`,
    response_type: "code",
    scope: provider.scope,
    state,
    prompt: key === "google" ? "select_account" : "consent",
  });
  return Response.redirect(to.toString(), 302);
}

async function callback(request, env, url, key) {
  const login = await pendingLogin(env, "state", url.searchParams.get("state") ?? "");
  if (!login) return expired();
  // The provider's own address, with a state from someone else's sign-in, would otherwise skip the page.
  if (!sameBrowser(request, login)) return elsewhere();
  if (!url.searchParams.get("code")) {
    return page("Not signed in", "<p>Signing in was cancelled. Start again from the game.</p>", 400);
  }
  const subject = await providerSubject(env, url, key);
  if (!subject) return page("Not signed in", "<p>The sign-in did not go through. Start again from the game.</p>", 502);
  const now = Date.now();
  const known = await env.DB.prepare("SELECT player_id FROM identities WHERE provider = ? AND subject = ?")
    .bind(key, subject).first();
  let playerId = known?.player_id;
  if (!playerId) {
    // The device's anonymous player keeps its name on its first sign-in, and its score starts again
    // from its first save.
    const legacy = login.player_id && !(await env.DB.prepare("SELECT 1 FROM identities WHERE player_id = ?")
      .bind(login.player_id).first()) ? login.player_id : null;
    if (legacy) {
      await env.DB.prepare("UPDATE players SET linked = 1, floors = 0, reached_at = NULL WHERE id = ?")
        .bind(legacy).run();
      playerId = legacy;
    } else {
      playerId = (await env.DB.prepare("INSERT INTO players (created_at, linked) VALUES (?, 1) RETURNING id")
        .bind(now).first()).id;
    }
    await env.DB.prepare("INSERT INTO identities (provider, subject, player_id, created_at) VALUES (?, ?, ?, ?)")
      .bind(key, subject, playerId, now).run();
  }
  // Done, and whose it is. The session itself is made when the game collects it (`pollLogin`): its
  // token is never kept, here or anywhere.
  await env.DB.prepare("UPDATE logins SET done = 1, player_id = ?, provider = ?, state = NULL WHERE code_hash = ?")
    .bind(playerId, key, login.code_hash).run();
  return page("Signed in", `<p>You are signed in with ${PROVIDERS[key].name}.</p>
    <p>Go back to Kobold Clicker. You can close this page.</p>`);
}

// The provider's own id for whoever just signed in there, or null. The code is swapped for an access
// token server to server, and that token asks who it belongs to; nothing else is asked or kept.
async function providerSubject(env, url, key) {
  const provider = PROVIDERS[key];
  const upper = key.toUpperCase();
  const exchanged = await fetch(endpoint(env, provider.token), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({
      client_id: env[`${upper}_CLIENT_ID`],
      client_secret: env[`${upper}_CLIENT_SECRET`],
      code: url.searchParams.get("code"),
      grant_type: "authorization_code",
      redirect_uri: `${url.origin}/auth/${key}/callback`,
    }),
  });
  if (!exchanged.ok) {
    console.error(`${key} token exchange failed: ${exchanged.status} ${await exchanged.text()}`);
    return null;
  }
  const { access_token: access } = await exchanged.json();
  const user = await fetch(endpoint(env, provider.user), {
    headers: { Authorization: `Bearer ${access}`, "User-Agent": "KoboldClicker (workers.dev, 1)" },
  });
  if (!user.ok) return null;
  const subject = provider.subject(await user.json());
  return subject ? String(subject) : null;
}

// A provider's endpoint, or the tests' stand-in for it (PROVIDER_ORIGIN, set only by test.mjs).
function endpoint(env, address) {
  return env.PROVIDER_ORIGIN ? new URL(new URL(address).pathname, env.PROVIDER_ORIGIN).toString() : address;
}

async function pollLogin(request, env) {
  const codeHash = await sha256(String((await bodyOf(request)).code ?? ""));
  const gone = () => json({ error: "The sign-in ran out of time. Start it again" }, 404);
  const login = await env.DB.prepare("SELECT done, created_at FROM logins WHERE code_hash = ?").bind(codeHash).first();
  if (!login || login.created_at < Date.now() - LOGIN_MS) return gone();
  if (!login.done) return json({ pending: true }, 202);
  // Handed out once: the poll that takes the login away is the one that makes the session. Its token
  // goes to the game and is kept nowhere, only its hash.
  const taken = await env.DB.prepare("DELETE FROM logins WHERE code_hash = ? RETURNING player_id, provider")
    .bind(codeHash).first();
  if (!taken) return gone();
  const token = randomHex();
  await env.DB.prepare("INSERT INTO sessions (token_hash, player_id, created_at) VALUES (?, ?, ?)")
    .bind(await sha256(token), taken.player_id, Date.now()).run();
  return json({ token, provider: taken.provider });
}

// ---------------------------------------------------------------------------------------------------
// The account.

async function getMe(request, env, url, player) {
  const [row, providers, save] = await Promise.all([
    standing(env, player.id),
    env.DB.prepare("SELECT provider FROM identities WHERE player_id = ?").bind(player.id).all(),
    env.DB.prepare("SELECT revision, summary, uploaded_at FROM saves WHERE player_id = ? ORDER BY revision DESC LIMIT 1")
      .bind(player.id).first(),
  ]);
  return json({
    ...row,
    providers: providers.results.map((row) => row.provider),
    save: save ? { revision: save.revision, uploaded_at: save.uploaded_at, summary: JSON.parse(save.summary) } : null,
  });
}

async function setName(request, env, url, player) {
  const name = String((await bodyOf(request)).name ?? "").trim().replace(/\s+/g, " ");
  if (!NAME.test(name)) return json({ error: "A name is 3 to 16 letters, digits, spaces, _ or -" }, 400);
  try {
    await env.DB.prepare("UPDATE players SET name = ? WHERE id = ?").bind(name, player.id).run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) return json({ error: "That name is taken" }, 409);
    throw error;
  }
  return json(await standing(env, player.id));
}

// Everything the server holds about the player, gone: the account, its sign-ins, sessions and saves.
async function deleteMe(request, env, url, player) {
  await env.DB.batch(["sessions", "identities", "saves", "logins"]
    .map((table) => env.DB.prepare(`DELETE FROM ${table} WHERE player_id = ?`).bind(player.id))
    .concat(env.DB.prepare("DELETE FROM players WHERE id = ?").bind(player.id)));
  return json({ deleted: true });
}

async function signOut(request, env, url, player) {
  await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(player.tokenHash).run();
  return json({ signed_out: true });
}

// ---------------------------------------------------------------------------------------------------
// Cloud saves. Every upload names the revision it grew from. One that is not the newest is a conflict
// the player settles (409), unless they already chose this device's save (`replace`).

async function getSave(request, env, url, player) {
  const row = await env.DB.prepare(
    "SELECT revision, data, summary, uploaded_at FROM saves WHERE player_id = ? ORDER BY revision DESC LIMIT 1",
  ).bind(player.id).first();
  if (!row) return json({ error: "There is no cloud save" }, 404);
  const files = JSON.parse(await gunzip(row.data));
  return json({ revision: row.revision, uploaded_at: row.uploaded_at, summary: JSON.parse(row.summary), ...files });
}

async function putSave(request, env, url, player) {
  const body = await bodyOf(request);
  const save = objectOf(body.inventory);
  if (!save) return json({ error: "That is not a save" }, 400);
  if (typeof body.map !== "string") return json({ error: "That save has no map" }, 400);
  const now = Date.now();
  // The newest save, if the cloud holds one, beside the highest revision any of the player's ever had.
  const latest = await env.DB.prepare(
    `SELECT p.last_revision, s.revision, s.summary FROM players p LEFT JOIN saves s ON s.player_id = p.id
     WHERE p.id = ? ORDER BY s.revision DESC LIMIT 1`,
  ).bind(player.id).first();
  const current = latest?.revision ?? 0;
  const baseRevision = Number.isInteger(body.base_revision) ? body.base_revision : 0;
  if (baseRevision !== current && body.replace !== true) {
    // No summary when the cloud holds no save at all: it was reset from another device.
    const newer = latest?.summary ? JSON.parse(latest.summary) : null;
    return json({ error: "The cloud has a newer save", revision: current, summary: newer }, 409);
  }
  // Past every revision there has been, even after `DELETE /save`: a number used twice would let a
  // device still at the old one take the new save for the save it grew from.
  const revision = Math.max(current, latest?.last_revision ?? 0) + 1;
  // `checked` and `vouched` are left from when uploads were checked, and no longer read.
  const writes = [
    env.DB.prepare(
      "INSERT INTO saves (player_id, revision, data, summary, uploaded_at, checked) VALUES (?, ?, ?, ?, ?, 0)",
    ).bind(player.id, revision, await gzip(JSON.stringify({ inventory: body.inventory, map: body.map })),
      JSON.stringify(summary(save)), now),
    env.DB.prepare("DELETE FROM saves WHERE player_id = ? AND revision <= ?")
      .bind(player.id, revision - KEEP_REVISIONS),
    env.DB.prepare("UPDATE players SET last_revision = ? WHERE id = ?").bind(revision, player.id),
  ];
  // A board moves only upwards, and only a rise moves its `_at`.
  for (const { score, at, of } of Object.values(BOARDS)) {
    writes.push(env.DB.prepare(`UPDATE players SET ${score} = ?, ${at} = ? WHERE id = ? AND ${score} < ?`)
      .bind(of(save), now, player.id, of(save)));
  }
  try {
    await env.DB.batch(writes);
  } catch (error) {
    // Two devices uploading at the same moment: the second is a conflict like any other.
    if (String(error).includes("UNIQUE")) return json({ error: "The cloud has a newer save", revision }, 409);
    throw error;
  }
  return json({ revision, ...(await standing(env, player.id)) });
}

// A whole number a save holds, 0 when it holds none or something that is not one.
function number(save, key) {
  const value = Math.floor(Number(save[key] ?? 0));
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

// What the question between two saves shows of each.
function summary(save) {
  return {
    level: number(save, "level"),
    play_seconds: number(save, "play_seconds"),
    saved_at: number(save, "saved_at"),
    dungeon_floors: number(save, "dungeon_floors"),
  };
}

// Reset save, or Start over from this device: the cloud's saves go and the next upload is a first one,
// numbered on from the last (`last_revision`). The board keeps the best it already had.
async function deleteSave(request, env, url, player) {
  await env.DB.prepare("DELETE FROM saves WHERE player_id = ?").bind(player.id).run();
  return json({ deleted: true });
}

// ---------------------------------------------------------------------------------------------------
// The boards: signed-in players with a name, each board scored by the best of their saves (`BOARDS`).
// `?board=` picks one, Gollux's when it is left out (what builds before the other boards ask). A row
// keeps `floors` beside its `score`, as those builds read it.

async function board(request, env, url) {
  const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit"), 10) || TOP, 1), TOP);
  const key = url.searchParams.get("board") ?? "gollux";
  if (!Object.hasOwn(BOARDS, key)) return json({ error: "No such board" }, 404);
  const which = BOARDS[key];
  let me = null;
  if (request.headers.has("Authorization")) {
    const player = await authed(request, env);
    if (!player) return json({ error: "Unknown player" }, 401);
    me = await standing(env, player.id, which);
  }
  const { score, at } = which;
  const { results } = await env.DB.prepare(
    `SELECT name, floors, ${score} AS score, ${at} AS reached_at FROM players
     WHERE hidden = 0 AND linked = 1 AND ${score} > 0 AND name IS NOT NULL
     ORDER BY ${score} DESC, ${at}, id LIMIT ?`,
  ).bind(limit).all();
  return json({ top: results.map((row, place) => ({ rank: place + 1, ...row })), me });
}

// One player's row on a board with their rank: one more than everyone ahead of them in `board`'s
// order. Null rank until they are on it. A hidden player is ranked among the others and never finds out.
// ponytail: the count scans every row ahead of the player, so it grows with the board; past ~10k
// players cache the board (Cache API, a minute) and store ranks instead of counting.
async function standing(env, id, which = BOARDS.gollux) {
  const { score, at } = which;
  return env.DB.prepare(
    `SELECT p.name, p.floors, p.${score} AS score, p.${at} AS reached_at,
       CASE WHEN p.${score} = 0 OR p.name IS NULL OR p.linked = 0 THEN NULL ELSE 1 + (
         SELECT COUNT(*) FROM players q
         WHERE q.hidden = 0 AND q.linked = 1 AND q.${score} > 0 AND q.name IS NOT NULL
           AND (q.${score} > p.${score} OR (q.${score} = p.${score} AND (q.${at}, q.id) < (p.${at}, p.id)))
       ) END AS rank
     FROM players p WHERE p.id = ?`,
  ).bind(id).first();
}

// ---------------------------------------------------------------------------------------------------
// Plumbing.

// The player a bearer token's session belongs to, with the token's hash for signing out; or null.
async function authed(request, env) {
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  if (!token) return null;
  const tokenHash = await sha256(token);
  const row = await env.DB.prepare("SELECT player_id FROM sessions WHERE token_hash = ?").bind(tokenHash).first();
  return row ? { id: row.player_id, tokenHash } : null;
}

// A route that needs a signed-in player, handed them as its fourth argument.
function signedIn(route) {
  return async (request, env, url) => {
    const player = await authed(request, env);
    if (!player) return json({ error: "Not signed in" }, 401);
    return route(request, env, url, player);
  };
}

// Whether `limiter` has room for one more call from `key`. A limiter that fails lets the call through:
// a fault in it is no reason to turn every player away.
async function allowed(limiter, key) {
  try {
    return (await limiter.limit({ key })).success;
  } catch (error) {
    console.error(error);
    return true;
  }
}

// The object a request's JSON body holds. Any other body is answered here, thrown for `fetch` to send:
// 413 for one bigger than any save, 400 for one that is not a JSON object.
async function bodyOf(request) {
  const text = await request.text();
  if (text.length > MOST_BODY) throw json({ error: "That save is far too big" }, 413);
  const body = objectOf(text);
  if (!body) throw json({ error: "The server could not read that" }, 400);
  return body;
}

// The object a JSON text holds, or null when it is not JSON or holds anything else.
function objectOf(text) {
  try {
    const value = JSON.parse(text);
    return typeof value === "object" && value !== null && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------------------------------
// The waiting list, from the landing page. Joining twice is not an error: the first time is kept.

async function joinWaitlist(request, env, url, ip) {
  if (!(await allowed(env.WAITLIST_LIMIT, ip))) {
    return json({ error: "Too many requests, try again in a minute" }, 429);
  }
  const email = String((await bodyOf(request)).email ?? "").trim();
  if (email.length > 254 || !EMAIL.test(email)) return json({ error: "That is not an email address" }, 400);
  await env.DB.prepare("INSERT OR IGNORE INTO waitlist (email, joined_at) VALUES (?, ?)").bind(email, Date.now()).run();
  return json({ joined: true }, 201);
}

function privacy() {
  return page("Privacy", `<p>Kobold Clicker keeps, for each player who signs in:</p>
    <ul><li>the id Google or Discord gives your account (not your email, name or picture),</li>
    <li>the leaderboard name you choose,</li><li>your save, and when it was uploaded.</li></ul>
    <p>They are used for cloud saves and the leaderboards, and nothing else. Nothing is sold or
    shared. An email given to the waiting list is kept only to tell you when the game comes out.
    IP addresses are seen only to limit how often anyone may call, and are not kept. The sign-in page
    leaves one cookie in your browser for ten minutes, so that only that browser can finish signing in.</p>
    <p>To delete all of it, choose <b>Delete cloud account</b> in the game's settings.</p>`);
}

function expired() {
  return page("Sign-in expired", "<p>This sign-in link is used up or ran out of time. Start again from the game.</p>", 404);
}

// For a browser that was never shown the login's page (`sameBrowser`), or that keeps no cookies.
function elsewhere() {
  return page("Not signed in",
    "<p>This sign-in was not opened in this browser, or its cookies are off. Start again from the game.</p>", 403);
}

function page(title, body, status = 200, headers = {}) {
  const html = `<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<style>body{margin:0;background:#3a2521;font:17px/1.5 system-ui,sans-serif;color:#3e1f1d}
main{max-width:26rem;margin:10vh auto;padding:1.5rem 1.75rem;background:#e5d6a1;border:4px solid #714c2a;border-radius:6px}
h1{font-size:1.4rem;margin:0 0 .75rem}.check{font:700 2.2rem monospace;letter-spacing:.35em;text-align:center;margin:.25rem 0}
.button{display:block;margin:.6rem 0;padding:.7rem;text-align:center;background:#58a046;color:#14101e;font-weight:600;
text-decoration:none;border:2px solid #14101e;border-radius:4px}.small{font-size:.8rem;color:#603928}</style>
<main><h1>${title}</h1>${body}</main></html>`;
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'",
      "X-Frame-Options": "DENY",
      // The sign-in page's address carries the page's id: never hand it to the provider in a Referer.
      "Referrer-Policy": "no-referrer",
      ...headers,
    },
  });
}

async function gzip(text) {
  return new Response(new Blob([text]).stream().pipeThrough(new CompressionStream("gzip"))).arrayBuffer();
}

async function gunzip(data) {
  return new Response(new Blob([new Uint8Array(data)]).stream().pipeThrough(new DecompressionStream("gzip"))).text();
}

function randomHex() {
  return hex(crypto.getRandomValues(new Uint8Array(32)));
}

async function sha256(text) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))));
}

function hex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function json(data, status = 200) {
  return Response.json(data, { status, headers: { "Access-Control-Allow-Origin": "*" } });
}
