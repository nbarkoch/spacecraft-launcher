shader_type canvas_item;

uniform float ring_radius : hint_range(0.0, 1.0) = 0.3;
uniform float ring_width : hint_range(0.0, 0.5) = 0.1;
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;
uniform float animation_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Calculate distance from center (0.5, 0.5)
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Ring expands from 0 to ring_radius, width shrinks from ring_width to 0
    float current_radius = ring_radius * animation_progress;
    float current_width = ring_width * (1.0 - animation_progress);
    
    // Calculate ring bounds
    float inner_radius = max(0.0, current_radius - current_width * 0.5);
    float outer_radius = current_radius + current_width * 0.5;
    
    // Create ring mask - only show pixels between inner and outer radius
    float outer_mask = 1.0 - smoothstep(outer_radius - edge_softness, outer_radius + edge_softness, dist);
    float inner_mask = smoothstep(inner_radius - edge_softness, inner_radius + edge_softness, dist);
    
    // Combine masks to create hollow ring
    float ring_mask = outer_mask * inner_mask;
    
    // Apply color with alpha based on ring mask
    COLOR = vec4(ring_color.rgb, ring_color.a * ring_mask);
}