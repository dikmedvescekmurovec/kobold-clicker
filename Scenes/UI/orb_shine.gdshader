// The light behind an item card when an orb has just gone into its piece (`ItemCard.shine`), after the
// user's reference (Hearthstone's card back lit from behind as a pack opens): a halo hugging the card's
// edges, white-hot at the rim and the orb's colour further out, a soft glow round it, and -- the better
// the orb -- more rays reaching further out from behind it, turning slowly. Smooth, not pixel art (the
// user's word, 2026-10-01). Drawn from `reach` past the card's top-left corner, the card's own pixels.
shader_type canvas_item;

uniform vec4 colour : source_color = vec4(1.0);
// 0 for the least orb to 1 for the best.
uniform float power = 0.0;
// 0 to 1 and back: it swells in and dies away; `ItemCard` tweens it.
uniform float life = 0.0;
// The card's size, and the most the light reaches past its edges (`ItemCard.SHINE_REACH`).
uniform vec2 card = vec2(150.0);
uniform float reach = 64.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 q = local - card * 0.5;
	// How far outside the card's edge, 0 on it and inside it (where the card covers it anyway).
	float d = length(max(abs(q) - card * 0.5, 0.0));
	// How far this orb's light gets, growing a little as it swells and drawing back as it dies.
	float span = reach * mix(0.3, 1.0, power) * (0.6 + 0.4 * life);
	float fall = 1.0 - smoothstep(0.0, span, d);
	float halo = exp(-d / mix(2.0, 5.0, power));
	// Rays from the third orb in the tray up, a few more for each orb past it.
	float rays = power < 0.3 ? 0.0 : floor(mix(5.0, 10.0, power));
	float spoke = pow(0.5 + 0.5 * cos(atan(q.y, q.x) * rays + TIME * 0.8), mix(12.0, 8.0, power));
	float beam = rays > 0.0 ? spoke * fall * mix(0.35, 0.6, power) : 0.0;
	float light = clamp((halo + beam + fall * 0.2) * life * mix(0.6, 0.75, power), 0.0, 1.0);
	COLOR = vec4(mix(colour.rgb, vec3(1.0), clamp(halo * 0.5, 0.0, 1.0)), light);
}
