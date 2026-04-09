shader_type canvas_item;

uniform vec4 lightColor : source_color = vec4(0.5, 0.75, 1.0, 0.75);
uniform vec2 lightOrigin = vec2(0.2, 0.0);
uniform float lightRadius = 0.3;
uniform float softness = 1.0;


void fragment() {
	vec4 baseColor = texture(TEXTURE, UV);

	// Distance from top-right corner
	float dist = distance(UV, lightOrigin);

	// Strong near corner, fades toward center/opposite side
	float lightMask = 1.0 - smoothstep(0.0, lightRadius, dist);
	lightMask = pow(lightMask, softness);

	vec3 finalRgb = baseColor.rgb + lightColor.rgb * lightColor.a * lightMask;

	COLOR = vec4(finalRgb, baseColor.a);
}