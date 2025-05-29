shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.75;
uniform float glow_radius : hint_range(0.0, 2.0) = 0.48;  // Increased max range
uniform vec4 glow_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float glow_softness : hint_range(0.1, 1.0) = 0.5;
uniform float planet_size : hint_range(0.1, 1.0) = 0.3;  // Control planet core size

varying vec2 world_position;

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    // Sample texture, but clamp to prevent edge artifacts
    vec4 tex_color = texture(TEXTURE, clamp(UV, 0.0, 1.0));
    
    // Calculate distance from center
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Create glow that extends beyond texture bounds
    float glow_start = planet_size;  // Where glow starts
    float glow_end = glow_start + glow_radius;  // Where glow ends
    
    float glow_alpha = 1.0 - smoothstep(glow_start, glow_end, dist);
    glow_alpha *= glow_intensity;
    
    // Create the planet mask (only show texture within planet_size)
    float planet_mask = 1.0 - smoothstep(planet_size - 0.05, planet_size, dist);
    
    // Create glow
    vec4 glow = vec4(glow_color.rgb, glow_alpha * glow_color.a);
    
    // Combine: show planet texture in center, glow around it
    COLOR = mix(glow, tex_color, planet_mask * tex_color.a);
    COLOR.a = max(glow_alpha, planet_mask * tex_color.a);
}