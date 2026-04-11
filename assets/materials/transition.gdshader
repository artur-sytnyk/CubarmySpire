shader_type canvas_item;

uniform vec4 main_color : source_color = vec4(0.3725, 0.7529, 0.7059, 1.0);

void fragment() {
	float alpha = 1.0;
	
	if (UV.x < 0.15) {
		alpha = UV.x / 0.15;
	} else if (UV.x > 0.85) {
		alpha = (1.0 - UV.x) / 0.15;
	}
	
	COLOR = vec4(main_color.rgb, main_color.a * alpha);
}