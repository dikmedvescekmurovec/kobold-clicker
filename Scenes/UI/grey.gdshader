// A piece the collection log knows of and the player has not found: its own lightness and none of its
// colour, so it can still be made out (the user found it darkened past recognising) without reading as held.
shader_type canvas_item;

void fragment() {
	COLOR = vec4(vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), COLOR.a);
}
