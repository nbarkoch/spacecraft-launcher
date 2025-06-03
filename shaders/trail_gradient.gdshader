shader_type canvas_item;

uniform vec4 start_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 end_color : source_color = vec4(0.0, 1.0, 0.0, 0.0);
uniform float width_taper : hint_range(0.0, 2.0) = 1.0;
uniform float opacity_fade : hint_range(0.0, 3.0) = 1.5;

void fragment() {
    // UV.x = position along the trail (0.0 at start, 1.0 at end)
    // UV.y = position across the trail width (0.0 at top edge, 1.0 at bottom edge)
    
    float trail_progress = UV.x;  // How far along the trail
    float width_position = UV.y;  // Position across the width
    
    // Calculate distance from center of trail (0.0 = center, 1.0 = edge)
    float distance_from_center = abs(width_position - 0.5) * 2.0;
    
    // Create width tapering effect (trail gets thinner toward the end)
    float width_factor = 1.0 - pow(trail_progress, width_taper);
    
    // Create soft edges based on current width
    float edge_softness = 0.1;
    float width_mask = 1.0 - smoothstep(width_factor - edge_softness, width_factor + edge_softness, distance_from_center);
    
    // Color gradient along the trail
    vec4 trail_color = mix(start_color, end_color, trail_progress);
    
    // Opacity fade along the trail
    float opacity_factor = 1.0 - pow(trail_progress, opacity_fade);
    
    // Combine all effects
    trail_color.a *= opacity_factor * width_mask;
    
    COLOR = trail_color;
}