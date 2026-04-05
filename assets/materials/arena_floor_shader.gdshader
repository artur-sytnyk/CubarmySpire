shader_type canvas_item;

uniform float noise_scale : hint_range(0.01, 0.1) = 0.1;
uniform sampler2D noise_texture : source_color;
uniform float noise_seed_offset : hint_range(0.0, 100.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.2;
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	//float noise_val = texture(noise_texture, UV * noise_scale).r;
	float noise_val = texture(noise_texture, UV * noise_scale + vec2(noise_seed_offset, noise_seed_offset)).r;
	
	// Brightness variation — darkens/lightens patches slightly.
	float brightness = 1.0 - brightness_variation + noise_val * brightness_variation * 2.0;
	tex.rgb *= brightness;
	
	// Cold stone tint.
	tex.rgb = mix(tex.rgb, tint_color.rgb, tint_strength);
	
	COLOR = tex * COLOR;
}