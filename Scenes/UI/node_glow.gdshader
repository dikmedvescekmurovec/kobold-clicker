// The light behind a skill node a point can go into (`SkillTreeView._light`): the node's colour hugging
// its edge and falling away over `reach`, with nothing else to it -- the card's light (`orb_shine`), with
// its white-hot rim and thin halo, could not be seen on the cream at a node's size. Smooth, as that is.
// Drawn from `reach` past the node's top-left corner, in the node's own pixels.
shader_type canvas_item;

uniform vec4 colour : source_color = vec4(1.0);
// The node's box, and how far its corners are rounded: half its side makes it a disc.
uniform vec2 box = vec2(16.0);
uniform float corner = 0.0;
// How far past the node's edge the light gets.
uniform float reach = 8.0;
// How much of the light breathes away and back, 0 for a still one: the root, showing a new player where
// their first point goes.
uniform float pulse = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	// How far outside the node's edge, 0 on it and inside it (where the node covers it anyway).
	vec2 q = abs(local - box * 0.5) - box * 0.5 + corner;
	float d = max(length(max(q, 0.0)) - corner, 0.0);
	float fall = 1.0 - smoothstep(0.0, reach, d);
	float lit = 1.0 - pulse * (0.5 + 0.5 * sin(TIME * 4.0));
	COLOR = vec4(colour.rgb, colour.a * fall * lit);
}
