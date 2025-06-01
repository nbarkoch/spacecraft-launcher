// shaders/spacecraft_trail.gdshader
shader_type canvas_item;

uniform float trail_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 start_color : source_color = vec4(0.3, 0.7, 1.0, 0.8);
uniform vec4 end_color : source_color = vec4(0.1, 0.3, 0.8, 0.0);
uniform float width_falloff : hint_range(0.0, 2.0) = 1.0;
uniform float opacity_curve : hint_range(0.1, 3.0) = 2.0;
uniform bool enable_glow = true;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;

varying vec2 world_position;

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    // Get distance along the trail (U coordinate represents position along line)
    float trail_position = UV.x;
    
    // Get distance from center of trail (V coordinate represents width)
    float distance_from_center = abs(UV.y - 0.5) * 2.0;
    
    // Apply trail progress (for animated effects)
    float effective_position = trail_position * trail_progress;
    
    // Calculate width falloff (trail gets thinner towards the end)
    float width_factor = 1.0 - pow(effective_position, width_falloff);
    
    // Calculate opacity falloff (trail fades out)
    float opacity_factor = 1.0 - pow(effective_position, opacity_curve);
    
    // Create soft edges for the trail width
    float edge_softness = 0.1;
    float width_mask = 1.0 - smoothstep(width_factor - edge_softness, width_factor, distance_from_center);
    
    // Interpolate colors along the trail
    vec4 trail_color = mix(start_color, end_color, effective_position);
    
    // Apply glow effect
    if (enable_glow && distance_from_center > width_factor) {
        float glow_distance = distance_from_center - width_factor;
        float glow_falloff = 1.0 - smoothstep(0.0, 0.3, glow_distance);
        trail_color.a += glow_falloff * glow_intensity * opacity_factor;
        trail_color.rgb = mix(trail_color.rgb, start_color.rgb, glow_falloff * 0.5);
    }
    
    // Apply all effects
    trail_color.a *= opacity_factor * width_mask;
    
    // Add subtle animation
    float time_offset = TIME * animation_speed;
    float shimmer = sin(effective_position * 10.0 + time_offset) * 0.1 + 1.0;
    trail_color.rgb *= shimmer;
    
    COLOR = trail_color;
}