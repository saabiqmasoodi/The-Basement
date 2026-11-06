shader_type canvas_item;

void fragment() {
    // Center the coordinates so (0,0) is the middle of the ColorRect
    vec2 center_uv = UV - vec2(0.5);
    
    // Calculate the distance from the current pixel to the center
    float dist = length(center_uv);
    
    // Smooth the edges slightly to avoid pixelation (anti-aliasing)
    // 0.5 is the radius (half of the full width/height)
    float circle = smoothstep(0.5, 0.49, dist);
    
    // Apply the circle mask to the ColorRect's built-in color
    COLOR.a *= circle;
}
