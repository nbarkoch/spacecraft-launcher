shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.0, 0.114, 0.310, 1.0);  // #001D4F
uniform vec4 bottom_color : source_color = vec4(0.0, 0.318, 0.494, 1.0);  // #00517E


void fragment() {
    COLOR = mix(top_color, bottom_color, UV.y);
}