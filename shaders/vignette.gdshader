shader_type canvas_item;

void fragment() {
	float v = smoothstep(0.35, 0.85, length(UV - 0.5));
	COLOR = vec4(0.04, 0.03, 0.1, v * 0.55);
}
