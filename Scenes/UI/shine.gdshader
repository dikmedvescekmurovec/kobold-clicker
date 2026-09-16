// A glint sweeping diagonally across an icon every few seconds, in hard pixel steps. Worked from the
// node's own pixels rather than UV, because an icon may be a region of an atlas.
shader_type canvas_item;

uniform float side = 32.0;
uniform float period = 3.0;
uniform float strength = 0.55;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// Snapped to whole source pixels so the band is pixel art, not a smear.
	vec2 p = floor(local) / side;
	// Sweeps from off the top-left to off the bottom-right over the first third of the period.
	float head = fract(TIME / period) * 3.0 * 2.0 - 0.5;
	float band = step(abs(p.x + p.y - head), 0.12);
	COLOR = vec4(mix(base.rgb, vec3(1.0), band * strength), base.a);
}
