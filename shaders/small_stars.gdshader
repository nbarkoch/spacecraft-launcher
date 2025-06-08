shader_type canvas_item;

uniform float star_density : hint_range(0.1, 1.0) = 0.4;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float twinkle_speed : hint_range(0.1, 3.0) = 1.0;
uniform float twinkle_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float star_size : hint_range(0.1, 2.0) = 1.0;
uniform float shooting_star_frequency : hint_range(0.0, 1.0) = 0.3;
uniform float shooting_star_speed : hint_range(0.1, 2.0) = 1.0;

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

// Shooting star function - accelerating point with smooth trail
float shooting_star_with_trail(vec2 uv, vec2 start_pos, vec2 end_pos, float progress, float trail_intensity, float trail_length_factor) {
    // Much more dramatic easing - very slow start/end, very fast middle
    float eased_progress;
    if (progress < 0.4) {
        // Very slow start
        float t = progress / 0.4;
        eased_progress = t * t * t * 0.1; // Cubic ease in, only 10% distance
    } else if (progress < 0.6) {
        // Very fast middle
        float t = (progress - 0.4) / 0.2;
        eased_progress = 0.1 + t * 0.8; // 80% of distance in 20% of time
    } else {
        // Very slow end
        float t = (progress - 0.6) / 0.4;
        eased_progress = 0.9 + (1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)) * 0.1; // Cubic ease out
    }
    
    vec2 current_pos = mix(start_pos, end_pos, eased_progress);
    vec2 direction = normalize(end_pos - start_pos);
    
    float star_value = 0.0;
    
    // Main star point
    float dist_to_star = distance(uv, current_pos);
    star_value += exp(-dist_to_star * dist_to_star / (0.001 * 0.001));
    
    // Smooth continuous trail - with variable length
    if (trail_intensity > 0.0) {
        // Calculate trail as a line segment with variable length
        vec2 trail_start = current_pos - direction * 0.12 * trail_intensity * trail_length_factor;
        
        // Distance from point to line segment
        vec2 to_point = uv - trail_start;
        vec2 trail_vec = current_pos - trail_start;
        float trail_length = length(trail_vec);
        
        if (trail_length > 0.0) {
            vec2 trail_dir = trail_vec / trail_length;
            float projection = clamp(dot(to_point, trail_dir), 0.0, trail_length);
            vec2 closest_point = trail_start + trail_dir * projection;
            
            float dist_to_trail = distance(uv, closest_point);
            float trail_alpha = (projection / trail_length) * trail_intensity;
            
            star_value += exp(-dist_to_trail * dist_to_trail / (0.0008 * 0.0008)) * trail_alpha * 0.8;
        }
    }
    
    return star_value;
}

void fragment() {
    vec2 uv = UV;
    
    // Base blue color #0057B5
    vec3 base_color = vec3(0.0, 0.341, 0.710);
    vec3 light_color = vec3(0.4, 0.6, 1.0);
    
    vec3 color = vec3(0.0);
    
    // Get screen pixel size to determine content dimensions
    vec2 pixel_size = SCREEN_PIXEL_SIZE;
    vec2 texture_size = 1.0 / pixel_size;
    
    // Calculate grid size based on texture dimensions
    // Aim for roughly 40-60 pixel cells
    float target_cell_size = 50.0;
    vec2 grid_scale = texture_size / target_cell_size;
    
    // Ensure minimum and maximum grid density
    grid_scale = clamp(grid_scale, vec2(6.0, 6.0), vec2(20.0, 20.0));
    
    // Create star field with size-aware spacing
    vec2 grid_uv = uv * grid_scale;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_local = fract(grid_uv);
    
    // Multiple random values for better distribution
    float rand1 = random(grid_id);
    float rand2 = random(grid_id + vec2(7.0, 13.0));
    float rand3 = random(grid_id + vec2(23.0, 41.0));
    
    // Check if this cell should have a star (use multiple random checks)
    float star_chance = rand1 * rand2;
    
    if (star_chance < star_density * 0.8) {
        // Completely random position within cell (not just centered)
        vec2 star_pos = vec2(random(grid_id + vec2(1.0, 2.0)), random(grid_id + vec2(3.0, 4.0)));
        
        // Add cell offset randomization to break grid pattern
        vec2 cell_offset = vec2(random(grid_id + vec2(5.0, 6.0)), random(grid_id + vec2(8.0, 9.0)));
        cell_offset = (cell_offset - 0.5) * 0.3; // Random offset up to 30% of cell size
        
        star_pos += cell_offset;
        star_pos = clamp(star_pos, vec2(0.05), vec2(0.95)); // Keep within cell bounds
        
        // Star properties with more randomization
        float size_rand = random(grid_id + vec2(10.0, 11.0));
        float shape_rand = random(grid_id + vec2(12.0, 15.0));
        float brightness_rand = random(grid_id + vec2(16.0, 17.0));
        
        // Adjust star scale based on grid density
        float base_star_scale = star_size * 0.04;
        // Scale stars smaller for denser grids to prevent overlap
        float density_factor = 10.0 / max(grid_scale.x, 10.0);
        base_star_scale *= density_factor;
        
        // Add random size variation
        base_star_scale *= (0.7 + brightness_rand * 0.6);
        
        float star_scale = base_star_scale;
        float star_value = 0.0;
        vec3 final_color = base_color;
        
        if (size_rand > 0.85) {
            // Large stars (15%) - diamond shape with twinkling
            star_scale *= (1.8 + size_rand * 0.7);
            star_value = diamond_star(grid_local, star_pos, star_scale);
            
            // Add twinkling with random phase
            float twinkle_phase = rand3 * 6.28;
            float twinkle = 0.6 + 0.4 * sin(TIME * twinkle_speed + twinkle_phase);
            final_color = mix(base_color, light_color, twinkle * twinkle_intensity);
            
        } else if (size_rand > 0.5) {
            // Medium stars (35%)
            star_scale *= (1.0 + size_rand * 0.5);
            
            if (shape_rand > 0.6) {
                star_value = diamond_star(grid_local, star_pos, star_scale);
            } else {
                star_value = round_star(grid_local, star_pos, star_scale);
            }
            
            // Occasional twinkling for medium stars
            if (brightness_rand > 0.8) {
                float twinkle_phase = rand2 * 6.28;
                float twinkle = 0.8 + 0.2 * sin(TIME * twinkle_speed * 0.5 + twinkle_phase);
                final_color = mix(base_color, light_color, twinkle * twinkle_intensity * 0.5);
            }
            
        } else {
            // Small stars (50%) - mostly static
            star_scale *= (0.5 + size_rand * 0.5);
            
            if (shape_rand > 0.95) {
                star_value = diamond_star(grid_local, star_pos, star_scale);
            } else {
                star_value = round_star(grid_local, star_pos, star_scale);
            }
        }
        
        color += star_value * final_color;
    }
    
    // Add shooting star effect - realistic behavior
    float time_cycle = TIME * (0.15 * shooting_star_speed); // Control speed with uniform
    float cycle_id = floor(time_cycle);
    float cycle_progress = fract(time_cycle);
    
    // Use cycle_id to generate random shooting star properties
    float shooting_rand = random(vec2(cycle_id, cycle_id * 0.618));
    
    // Only show shooting star occasionally and for shorter duration
    if (shooting_rand < shooting_star_frequency && cycle_progress < 0.25) { // About 1.7 seconds - much shorter
        // Generate random start position (anywhere on screen)
        vec2 start_seed = vec2(cycle_id * 1.234, cycle_id * 0.789);
        vec2 start_pos = vec2(
            0.2 + random(start_seed) * 0.6,           // X: 20% to 80% across screen
            0.2 + random(start_seed + vec2(1.0, 0.0)) * 0.6  // Y: 20% to 80% down screen
        );
        
        // End position - always top to bottom diagonal
        float left_or_right = random(start_seed + vec2(2.0, 0.0));
        vec2 direction_vec;
        
        if (left_or_right > 0.5) {
            // Top-left to bottom-right
            direction_vec = vec2(0.707, 0.707); // 45° down-right
        } else {
            // Top-right to bottom-left  
            direction_vec = vec2(-0.707, 0.707); // 135° down-left
        }
        
        float distance = 0.12 + random(start_seed + vec2(3.0, 0.0)) * 0.08; // Much shorter distance
        vec2 end_pos = start_pos + direction_vec * distance;
        
        // Keep end position within bounds
        end_pos = clamp(end_pos, vec2(0.05), vec2(0.95));
        
        // Normalize progress to shooting star duration
        float shoot_progress = cycle_progress / 0.25; // Shorter duration
        
        // Calculate brightness and trail intensity with variable length
        float brightness = 1.0;
        float trail_intensity = 1.0;
        float trail_length_factor = 1.0; // Controls trail length
        float fade_progress = (shoot_progress - 0.8) / 0.2;
        if (shoot_progress < 0.3) {
            // Starting - just a point, getting brighter
            brightness = shoot_progress / 0.2;
            trail_length_factor = 0.0;
        } else if (shoot_progress < 0.7) {
            // Fast phase - bright with trail
            brightness = 2.0; // Very bright
            trail_length_factor = (shoot_progress - 0.2) / 0.4;
        } else {
            // Slowing down - losing trail and brightness
            float fade_progress = (shoot_progress - 0.7) / 0.2;
            brightness = 2.0 - fade_progress;
            trail_length_factor = 1.0 - fade_progress; // 1 to 0
        }
        
        // Calculate shooting star
        float shooting_intensity = shooting_star_with_trail(uv, start_pos, end_pos, shoot_progress, trail_intensity, trail_length_factor);
        
        // Same blue color as other stars, but brighter during fast phase
        vec3 shooting_color = base_color * brightness;
        
        // Add to final color
        color += shooting_intensity * shooting_color;
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