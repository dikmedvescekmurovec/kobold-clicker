// A glint sweeping diagonally across an icon, in hard pixel steps. Worked from the
// node's own pixels rather than UV, because an icon may be a region of an atlas.
shader_type canvas_item;

uniform float side = 32.0;
// How far through one period the glint is; `ItemSlot` tweens it, and at rest (1) the band is off the icon.
uniform float progress = 1.0;
uniform float strength = 0.55;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	// COLOR already holds the texture times the node's modulate. Sampling TEXTURE again and multiplying
	// drew every rare-and-better icon with its colours squared -- darker and bluer than the same piece
	// in a common's square (two Opal Rings side by side, 2026-09-30).
	vec4 base = COLOR;
	// Snapped to whole source pixels so the band is pixel art, not a smear.
	vec2 p = floor(local) / side;
	// Sweeps from off the top-left to off the bottom-right over the first third of the period.
	float head = progress * 3.0 * 2.0 - 0.5;
	float band = step(abs(p.x + p.y - head), 0.12);
	COLOR = vec4(mix(base.rgb, vec3(1.0), band * strength), base.a);
}
