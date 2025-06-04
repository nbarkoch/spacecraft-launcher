shader_type canvas_item;

uniform float star_density : hint_range(0.1, 1.0) = 0.4;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float twinkle_speed : hint_range(0.1, 3.0) = 1.0;
uniform float twinkle_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float star_size : hint_range(0.1, 2.0) = 1.0;

// Simple random function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Round star shape - pure star color, no dark areas
float round_star(vec2 uv, vec2 center, float size) {
    float dist = length(uv - center);
    float star = exp(-dist * dist / (size * size * 0.5));
    return clamp(star, 0.0, 1.0);
}

// Diamond star shape - pure star color, no dark areas  
float diamond_star(vec2 uv, vec2 center, float size) {
    vec2 d = uv - center;
    
    // Diamond body
    float diamond_dist = abs(d.x) + abs(d.y);
    float diamond = exp(-diamond_dist * diamond_dist / (size * size * 0.3));
    
    // Spikes
    float vertical = exp(-d.x * d.x / (size * size * 0.05)) * 
                    exp(-d.y * d.y / (size * size * 2.0));
    
    float horizontal = exp(-d.y * d.y / (size * size * 0.05)) * 
                      exp(-d.x * d.x / (size * size * 2.0));
    
    float star = max(diamond, max(vertical, horizontal) * 0.4);
    return clamp(star, 0.0, 1.0);
}

void fragment() {
    vec2 uv = UV;
    
    // Base blue color #0057B5
    vec3 base_color = vec3(0.0, 0.341, 0.710);
    vec3 light_color = vec3(0.4, 0.6, 1.0);
    
    vec3 color = vec3(0.0);
    
    // Create star field with good spacing
    vec2 grid_uv = uv * 10.0;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_local = fract(grid_uv);
    
    // Check if this cell should have a star
    float rand = random(grid_id);
    
    if (rand < star_density) {
        // Position star more centered to avoid cropping
        vec2 star_pos = vec2(random(grid_id + 1.0), random(grid_id + 2.0));
        star_pos = star_pos * 0.6 + 0.2; // Keep within 0.2 to 0.8 range in cell
        
        // Star properties
        float size_rand = random(grid_id + 3.0);
        float shape_rand = random(grid_id + 4.0);
        
        float star_scale = star_size * 0.04; // Smaller base size to prevent cropping
        float star_value = 0.0;
        vec3 final_color = base_color;
        
        if (size_rand > 0.8) {
            // Large stars (20%) - diamond shape with twinkling
            star_scale *= (1.5 + size_rand * 0.5); // Smaller max size
            star_value = diamond_star(grid_local, star_pos, star_scale);
            
            // Add twinkling
            float twinkle = 0.7 + 0.3 * sin(TIME * twinkle_speed + rand * 6.28);
            final_color = mix(base_color, light_color, twinkle * twinkle_intensity);
            
        } else if (size_rand > 0.4) {
            // Medium stars (40%)
            star_scale *= (1.0 + size_rand * 0.4); // Smaller max size
            
            if (shape_rand > 0.7) {
                star_value = diamond_star(grid_local, star_pos, star_scale);
            } else {
                star_value = round_star(grid_local, star_pos, star_scale);
            }
            
        } else {
            // Small stars (40%) - but still visible
            star_scale *= (0.6 + size_rand * 0.4); // Smaller max size
            
            if (shape_rand > 0.9) {
                star_value = diamond_star(grid_local, star_pos, star_scale);
            } else {
                star_value = round_star(grid_local, star_pos, star_scale);
            }
        }
        
        color += star_value * final_color;
    }
    
    // Apply brightness
    color *= star_brightness;
    
    // Only output the star color where there's actually a star
    // Use the star brightness directly as alpha - no dark areas
    float total_alpha = length(color);
    
    if (total_alpha > 0.65) {
        COLOR = vec4(color, total_alpha);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Completely transparent where no star
    }
}