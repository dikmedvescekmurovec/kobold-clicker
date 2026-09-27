// The Gollux leaderboard: anonymous accounts, one best score each, ranked by floors and then by who
// got there first. Three routes; see ../README.md for the API and how it is deployed.

const NAME = /^[A-Za-z0-9 _-]{3,16}$/;
// Far past any floor the game can reach (a floor's health is 1.2^floor); anything above is a forgery.
const MOST_FLOORS = 1_000_000;
const TOP = 100;

export default {
  async fetch(request, env) {
    const ip = request.headers.get("CF-Connecting-IP") ?? "local";
    if (!(await env.REQUEST_LIMIT.limit({ key: ip })).success) {
      return json({ error: "Too many requests, try again in a minute" }, 429);
    }
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;
    try {
      if (route === "POST /players") return await register(request, env, ip);
      if (route === "POST /scores") return await submit(request, env);
      if (route === "GET /leaderboard") return await board(request, env, url);
      return json({ error: "Not found" }, 404);
    } catch (error) {
      console.error(error);
      return json({ error: "Server error" }, 500);
    }
  },
};

// A new account: a name nobody has, and a token that is shown once and stored only as its hash.
async function register(request, env, ip) {
  if (!(await env.REGISTER_LIMIT.limit({ key: ip })).success) {
    return json({ error: "Too many new players from here, try again in a minute" }, 429);
  }
  const body = await request.json().catch(() => ({}));
  const name = String(body.name ?? "").trim().replace(/\s+/g, " ");
  if (!NAME.test(name)) {
    return json({ error: "A name is 3 to 16 letters, digits, spaces, _ or -" }, 400);
  }
  const token = hex(crypto.getRandomValues(new Uint8Array(32)));
  try {
    await env.DB.prepare("INSERT INTO players (name, token_hash, created_at) VALUES (?, ?, ?)")
      .bind(name, await sha256(token), Date.now())
      .run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) return json({ error: "That name is taken" }, 409);
    throw error;
  }
  return json({ name, token }, 201);
}

// The player's best, if `floors` beats it. Only a rise moves `reached_at`, so sending the same score
// again (the game retries after a failure) never costs a player their place in a tie.
async function submit(request, env) {
  const player = await authed(request, env);
  if (!player) return json({ error: "Unknown player" }, 401);
  const body = await request.json().catch(() => ({}));
  const floors = body.floors;
  if (!Number.isInteger(floors) || floors < 0 || floors > MOST_FLOORS) {
    return json({ error: "floors must be a whole number from 0" }, 400);
  }
  await env.DB.prepare("UPDATE players SET floors = ?, reached_at = ? WHERE id = ? AND floors < ?")
    .bind(floors, Date.now(), player.id, floors)
    .run();
  return json(await standing(env, player.id));
}

// The top of the board, and where the asking player stands on it when they send their token.
async function board(request, env, url) {
  const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit"), 10) || TOP, 1), TOP);
  let me = null;
  if (request.headers.has("Authorization")) {
    const player = await authed(request, env);
    if (!player) return json({ error: "Unknown player" }, 401);
    me = await standing(env, player.id);
  }
  const { results } = await env.DB.prepare(
    `SELECT name, floors, reached_at FROM players WHERE hidden = 0 AND floors > 0
     ORDER BY floors DESC, reached_at, id LIMIT ?`,
  ).bind(limit).all();
  return json({ top: results.map((row, at) => ({ rank: at + 1, ...row })), me });
}

// One player's row with their rank: one more than everyone ahead of them in `board`'s order. Null rank until they have
// beaten a floor. A hidden player is ranked among the others and never finds out.
// ponytail: the count scans every row ahead of the player, so it grows with the board; past ~10k
// players cache the board (Cache API, a minute) and store ranks instead of counting.
async function standing(env, id) {
  return env.DB.prepare(
    `SELECT p.name, p.floors, p.reached_at,
       CASE WHEN p.floors = 0 THEN NULL ELSE 1 + (
         SELECT COUNT(*) FROM players q WHERE q.hidden = 0 AND q.floors > 0
           AND (q.floors > p.floors OR (q.floors = p.floors AND (q.reached_at, q.id) < (p.reached_at, p.id)))
       ) END AS rank
     FROM players p WHERE p.id = ?`,
  ).bind(id).first();
}

// The player a bearer token belongs to, or null.
async function authed(request, env) {
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
  if (!token) return null;
  return env.DB.prepare("SELECT id FROM players WHERE token_hash = ?").bind(await sha256(token)).first();
}

async function sha256(text) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))));
}

function hex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function json(data, status = 200) {
  return Response.json(data, { status });
}
