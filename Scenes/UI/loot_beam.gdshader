shader_type canvas_item;
// The loot beam: a column of light standing up through the find and pinching in above it to a thin
// pillar of a rarity's colour with a white-hot core that tapers to a point, over a glowing ring on the
// ground -- and, the better the find, ribbons spiralling up round the beam, a second ring pulsing out
// and sparks. Drawn twice by `LootBeam`: the back layer under the find (the pillar, the column's far
// wall, the far half of the rings, whatever of a ribbon is behind the beam) and the `front` layer over
// it (the column's near wall, the near half of the rings, the near turns, the sparks), so the find
// stands inside the light. Whole pixels of the node it is drawn on. The origin is the find's foot.

uniform vec4 colour : source_color = vec4(1.0);
// How tall the pillar is above the foot, and its half-width, in the node's pixels.
uniform float height = 80.0;
uniform float width = 1.5;
// The find it stands round: its half-width and its height. The ring is sized off the half-width.
uniform vec2 cover = vec2(19.0, 38.0);
// How many rings (1, or 2 with the second pulsing out), ribbons (0 to 2) and whether sparks rise.
uniform int rings = 1;
uniform int ribbons = 0;
uniform bool sparks = false;
uniform bool front = false;
// How much of it is up, 0 to 1: `LootBeam` tweens it as the find lands.
uniform float grow = 1.0;
// 1 animates, 0 holds it still (animations turned down).
uniform float speed = 1.0;
// 0 to 1, a beam's own: shifts its clock and its sparks, so two beams side by side are not in step.
uniform float seed = 0.0;

// How flat the ring lies: its height as a share of its width.
const float FLAT = 0.3;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// How far `px` is from the ellipse of half-width `r` lying flat round the foot, in pixels (roughly).
float ring_distance(vec2 px, float r) {
	vec2 radii = vec2(r, r * FLAT);
	vec2 q = px / radii;
	float e = length(q);
	vec2 slope = px / (radii * radii) / max(e, 0.001);
	return abs(e - 1.0) / max(length(slope), 0.001);
}

// Lays `add` (a colour and its alpha) over what is there already.
vec4 over(vec4 under, vec4 add) {
	float a = add.a + under.a * (1.0 - add.a);
	return vec4((add.rgb * add.a + under.rgb * under.a * (1.0 - add.a)) / max(a, 0.001), a);
}

void fragment() {
	// Nothing until the find has landed: at 0 the pillar and ribbons would still draw a row of pixels
	// at the foot, carried along the throw, and the column's smoothstep would have equal edges.
	if (grow <= 0.0) {
		discard;
	}
	vec2 px = floor(local) + 0.5;
	float t = TIME * speed + seed * 100.0;
	float y = -px.y;
	float tall = max(height * grow, 1.0);
	float up = y / tall;
	vec3 hot = mix(colour.rgb, vec3(1.0), 0.4);
	vec4 c = vec4(0.0);
	float ring_r = cover.x * 1.1 * grow;

	// The ground: a faint disc and the ring round it, the far half behind the find, the near in front.
	if ((px.y >= 0.0) == front) {
		float e = length(px / vec2(ring_r, ring_r * FLAT));
		if (e < 1.0) {
			c = over(c, vec4(colour.rgb, 0.3 * (0.5 + 0.5 * e)));
		}
		if (ring_distance(px, ring_r) < 0.75) {
			c = over(c, vec4(hot, 0.95));
		} else if (ring_distance(px, ring_r) < 1.8) {
			c = over(c, vec4(colour.rgb, 0.7));
		}
		if (rings > 1) {
			// The second ring pulses out from the first and fades as it goes.
			float wave = fract(t * 0.7);
			if (ring_distance(px, ring_r * (1.0 + 0.6 * wave)) < 0.75) {
				c = over(c, vec4(colour.rgb, 0.8 * (1.0 - wave)));
			}
		}
	}

	// The column round the find: a tube of light as wide as the ring, standing up through the find and
	// pinching in above it to the pillar. Its far wall is behind the find and its near wall in front,
	// each faint in the middle and bright towards its edges, which is what makes it read as round; its
	// foot follows the ring's far or near half. Streaks of light circle it, behind and then in front.
	float tube = ring_r * 0.85;
	float neck = smoothstep(cover.y * 0.8 * grow, cover.y * 1.7 * grow, y);
	float r = mix(tube, width * 2.0, neck);
	float across = abs(px.x) / max(r, 0.5);
	if (across <= 1.0 && neck < 1.0) {
		float lip = ring_r * FLAT * sqrt(1.0 - across * across) * 0.85;
		bool below = front ? px.y <= lip : px.y <= -lip;
		if (below) {
			// Brightest at the foot and dissolving as it climbs, so it is light rising rather than a jar.
			float rising = clamp(1.0 - (y + lip) / (cover.y * 1.5 * max(grow, 0.01)), 0.0, 1.0);
			float wall = mix(0.08, front ? 0.45 : 0.6, pow(across, 4.0)) * rising;
			c = over(c, vec4(colour.rgb, wall));
			if (across > 1.0 - 1.2 / max(r, 1.0)) {
				c = over(c, vec4(hot, 0.9 * rising * rising));
			}
			for (int k = 0; k < 3; k++) {
				float a = float(k) * 2.094 + t * 1.3;
				if ((cos(a) > 0.0) != front) {
					continue;
				}
				float climbing = fract((y + lip) / (cover.y * 1.5) - t * 0.6 + float(k) * 0.37);
				if (abs(px.x - r * sin(a)) < 0.6 && climbing < 0.45) {
					c = over(c, vec4(hot, 0.7 * rising * (0.4 + 0.6 * abs(cos(a)))));
				}
			}
		}
	}

	// The pillar, behind the find: narrowing to a point, pulses of light climbing it.
	if (!front && up >= 0.0 && up <= 1.0) {
		float d = abs(px.x);
		float w = width * sqrt(1.0 - up);
		float fade = 1.0 - up * up;
		float pulse = 0.8 + 0.2 * step(0.75, fract((y - t * 60.0) / 24.0));
		if (d <= w * 0.35 + 0.5) {
			c = over(c, vec4(vec3(1.0), fade));
		} else if (d <= w + 0.5) {
			c = over(c, vec4(hot, 0.95 * fade * pulse));
		} else if (d <= w * 2.2 + 1.0) {
			c = over(c, vec4(colour.rgb, 0.75 * fade * pulse));
		} else if (d <= w * 4.0 + 1.5) {
			c = over(c, vec4(colour.rgb, 0.35 * fade));
		}
	}

	// The ribbons: strands winding up round the beam, half a turn apart, on whichever layer the turn is.
	for (int k = 0; k < ribbons; k++) {
		float reach = tall * 0.7;
		float share = y / reach;
		if (share < 0.0 || share > 1.0) {
			continue;
		}
		float r = cover.x * 0.75 * (1.0 - 0.6 * share);
		float turn = 0.055;
		float a = y * turn - t * 4.0 + float(k) * TAU * 0.5;
		if ((cos(a) > 0.0) != front) {
			continue;
		}
		float x = r * sin(a);
		float slope = r * turn * cos(a);
		float dist = abs(px.x - x) / sqrt(1.0 + slope * slope);
		// Brightest where it runs across the front, and fading out towards its top.
		float lit = (1.0 - share * share) * (0.6 + 0.4 * abs(cos(a)));
		if (dist < 0.9) {
			c = over(c, vec4(hot, lit));
		} else if (dist < 1.9) {
			c = over(c, vec4(colour.rgb, 0.6 * lit));
		}
	}

	// Sparks: one column in three carries one, climbing at its own rate round the foot of the beam.
	if (sparks && front) {
		float lane = px.x + seed * 1000.0;
		float rise = fract(hash(vec2(lane, 2.0)) + t * (0.3 + 0.4 * hash(vec2(lane, 1.0))));
		float spark_y = rise * tall * 0.6;
		if (hash(vec2(lane, 3.0)) > 0.66 && abs(px.x) < cover.x * 1.2 && abs(y - spark_y) < 0.5) {
			c = over(c, vec4(hot, 1.0 - rise));
		}
	}

	if (c.a < 0.02) {
		discard;
	}
	COLOR = c;
}
