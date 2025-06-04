// shaders/simple_stars.gdshader
shader_type canvas_item;

uniform float star_density : hint_range(0.001, 0.1) = 0.03;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV * 50.0; // Scale up for more stars
    vec2 grid = floor(uv);
    vec2 local = fract(uv);
    
    float star_chance = random(grid);
    
    if (star_chance > (1.0 - star_density)) {
        vec2 star_pos = vec2(random(grid + 1.0), random(grid + 2.0));
        float dist = length(local - star_pos);
        
        // Simple star
        float star = 1.0 - smoothstep(0.0, 0.05, dist);
        
        // Simple twinkling
        float twinkle = 0.5 + 0.5 * sin(TIME + random(grid) * 6.28);
        
        COLOR = vec4(1.0, 1.0, 1.0, star * twinkle * brightness);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}