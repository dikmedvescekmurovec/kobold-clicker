shader_type canvas_item;
// The Gollux cave felt from the hero (`CaveSense`): a band of red light hugging the edge of the map, at
// its thickest where the line from the hero toward the cave leaves it and thinning away along the edge
// either side, breathing slowly (the user's sketch: a glowing edge, not a spot). Dithered between a few
// steps one map pixel at a time, as the fog and the pit's own light are, and red throughout (the user's):
// ENDESGA 64's deep red where it fades and its bright red at the edge. Drawn on a rect over the map's
// part of the window; everything else is discarded.

// The rect's size, and the band's heart in its own pixels.
uniform vec2 area = vec2(1152.0, 648.0);
uniform vec2 focus = vec2(0.0);
// How far in from the edge the band reaches at its heart, and how far along the edge from there it
// runs out.
uniform float reach = 60.0;
uniform float span = 250.0;
// How opaque it is at the edge.
uniform float strength = 0.8;
// The map's pixel on screen, which the light is dithered in steps of.
uniform float pixel = 3.0;
// Breaths a second and how deep a breath is: 0 holds the light still.
uniform float breath = 0.25;
uniform float depth = 0.25;
uniform vec4 deep : source_color = vec4(0.537, 0.118, 0.169, 1.0);
uniform vec4 hot : source_color = vec4(0.918, 0.196, 0.235, 1.0);
// The faintest step's share of `strength`: high enough that the band's inner edge reads on the fog.
uniform float floor_alpha = 0.35;

const float STEPS = 4.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 cell = floor(local / pixel);
	vec2 px = (cell + 0.5) * pixel;
	float breathe = 1.0 - depth * 0.5 * (1.0 - sin(TIME * 6.2831853 * breath));
	float edge = min(min(px.x, area.x - px.x), min(px.y, area.y - px.y));
	float along = length(px - focus) / span;
	float thick = reach * breathe * (1.0 - along * along);
	if (thick <= 0.0) {
		discard;
	}
	float light = pow(clamp(1.0 - edge / thick, 0.0, 1.0), 1.4);
	float b = BAYER[int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0))] / 16.0;
	float level = floor(light * STEPS + b) / STEPS;
	if (level <= 0.0) {
		discard;
	}
	COLOR = vec4(mix(deep.rgb, hot.rgb, level), mix(floor_alpha, 1.0, level) * strength);
}
