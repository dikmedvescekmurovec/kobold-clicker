// What the server asks of a save before it keeps it. It cannot run the game, so it checks only what
// the game itself guarantees: a save agrees with itself (`consistent`), and a save grown from an
// earlier one lost nothing that is never lost and played no faster than time passed (`follows`).
// Everything here returns sentences, empty when the save is fine.

// Mirrors of the game's own numbers; tests/test_cloud.gd reads these two lines and fails if they drift.
// A depth is Encounter.DUNGEON.enemies floors, and no floor can fall faster than Encounter.DEATH.
export const FLOORS_PER_DEPTH = 15;
export const SECONDS_PER_FLOOR = 0.5;

// A save is written a moment after the frame that counted it, and clocks disagree.
const SLACK_SECONDS = 120;
// How much faster than real time the play clock may run: frame deltas add up a little long.
const CLOCK_RATE = 1.05;
// Carried through every transcension (Inventory.transcended), so they only ever rise.
const RISING = {
  kills: "Kills",
  play_seconds: "Time played",
  dungeon_depth: "The dungeon's depth",
  dungeon_floors: "The dungeon's floors",
  farthest_land: "The farthest land reached",
};
// Keyed counts that only ever rise, one key at a time.
const RISING_MAPS = { achievements: "An achievement's rank", tally: "A tally" };

// A number a save holds, 0 when it holds none (an older save that never had it).
function number(save, key) {
  return Number(save[key] ?? 0);
}

// What the question between two saves shows of each.
export function summary(save) {
  return {
    level: number(save, "level"),
    play_seconds: Math.floor(number(save, "play_seconds")),
    saved_at: Math.floor(number(save, "saved_at")),
    dungeon_floors: number(save, "dungeon_floors"),
  };
}

// A save on its own: the right shape, and nothing in it that it could not have done.
export function consistent(save, nowMs) {
  if (typeof save !== "object" || save === null || Array.isArray(save)) return ["It is not a save file"];
  const problems = [];
  for (const key of ["version", "level", "saved_at", ...Object.keys(RISING)]) {
    const value = number(save, key);
    if (!Number.isFinite(value) || value < 0) problems.push(`${key} is not a number`);
  }
  if (problems.length > 0) return problems;
  if (Math.floor(number(save, "dungeon_floors") / FLOORS_PER_DEPTH) !== number(save, "dungeon_depth")) {
    problems.push("The dungeon's depth and floors disagree");
  }
  if (number(save, "dungeon_floors") * SECONDS_PER_FLOOR > number(save, "play_seconds") + SLACK_SECONDS) {
    problems.push("More dungeon floors than the time played allows");
  }
  if (number(save, "saved_at") > nowMs / 1000 + SLACK_SECONDS) problems.push("It was saved in the future");
  return problems;
}

// `next` as the save `base` grew into over `elapsed` seconds of real time.
export function follows(base, next, elapsed) {
  const problems = [];
  for (const [key, label] of Object.entries(RISING)) {
    if (number(next, key) < number(base, key)) problems.push(`${label} went down`);
  }
  for (const [key, label] of Object.entries(RISING_MAPS)) {
    const before = base[key] ?? {};
    const after = next[key] ?? {};
    if (Object.keys(before).some((id) => Number(after[id] ?? -1) < Number(before[id]))) {
      problems.push(`${label} went down`);
    }
  }
  const found = new Set(next.uniques_found ?? []);
  if ((base.uniques_found ?? []).some((id) => !found.has(id))) problems.push("A unique found was lost");
  if (base.seeing_stone === true && next.seeing_stone !== true) problems.push("The Seeing Stone was lost");
  const played = number(next, "play_seconds") - number(base, "play_seconds");
  if (played > elapsed * CLOCK_RATE + SLACK_SECONDS) {
    problems.push(`${Math.round(played)} s were played in ${Math.round(elapsed)} s`);
  }
  const floors = number(next, "dungeon_floors") - number(base, "dungeon_floors");
  if (floors * SECONDS_PER_FLOOR > Math.max(played, 0) + SLACK_SECONDS) {
    problems.push("More dungeon floors than the time played allows");
  }
  return problems;
}
