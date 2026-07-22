#pragma header

uniform vec2 u_spriteSize;
uniform float u_gridSize;
uniform float u_outline;

uniform vec3 u_tint;

uniform bool u_outlineTop;
uniform bool u_outlineBottom;

// When true the time axis runs horizontally (event lane) instead of vertically (strumlines).
uniform bool u_horizontal;

vec4 colorA = vec4(0.45, 0.45, 0.45, 1.0);
vec4 colorB = vec4(0.55, 0.55, 0.55, 1.0);
vec4 colorOutline = vec4(0.867, 0.867, 0.867, 1.0);

void main()
{
    vec2 uv = openfl_TextureCoordv.xy;
    vec2 pixelCoord = uv * u_spriteSize;

    bool drawOutline = false;

    if (pixelCoord.x < u_outline || pixelCoord.x > u_spriteSize.x - u_outline)
        drawOutline = true;

    if (u_outlineTop && pixelCoord.y < u_outline)
        drawOutline = true;

    if (u_outlineBottom && pixelCoord.y > u_spriteSize.y - u_outline)
        drawOutline = true;

    if (drawOutline)
    {
        gl_FragColor = vec4(colorOutline.rgb * u_tint, colorOutline.a);
        return;
    }

    vec4 col = colorA;
    bool flip = true;

    float gridX = pixelCoord.x - u_outline;
    float gridY = pixelCoord.y;

    if (u_outlineTop)
        gridY -= u_outline;
    
    if (mod(gridX, u_gridSize * 2.0) < u_gridSize)
        flip = !flip;
        
    if (mod(gridY, u_gridSize * 2.0) < u_gridSize)
        flip = !flip;

    if (flip)
        col = colorB;

    // Position along the time axis (Y for strumlines, X for the horizontal event lane).
    float t = u_horizontal ? gridX : gridY;

    float beatSize = u_gridSize * 4.0;
    float measureSize = u_gridSize * 16.0;

    // Thinner lines on the horizontal event lane so the measure line doesn't dominate the strip.
    float measureW = u_gridSize * (u_horizontal ? 0.05 : 0.09);
    float beatW = u_gridSize * (u_horizontal ? 0.035 : 0.055);

    // Very subtle alternating band per measure.
    if (mod(floor(t / measureSize), 2.0) >= 1.0)
        col.rgb *= 0.93;

    vec4 texColor = flixel_texture2D(bitmap, uv);

    // Beat and measure lines, sitting just above each boundary (shifted up by their own
    // thickness). This also drops the line at t ~ 0, since it lands off the top of the grid.
    // The "strength" blends the grid toward white while staying opaque, so a softer beat line
    // stays white-ish instead of revealing the dark background (premultiplied alpha).
    if (mod(t, measureSize) >= measureSize - measureW)
    {
        vec3 lineRgb = mix(col.rgb * u_tint, vec3(1.0), 0.85);
        gl_FragColor = vec4(min(lineRgb, vec3(1.0)), col.a) * texColor;
        return;
    }
    else if (mod(t, beatSize) >= beatSize - beatW)
    {
        vec3 lineRgb = mix(col.rgb * u_tint, vec3(1.0), 0.35);
        gl_FragColor = vec4(min(lineRgb, vec3(1.0)), col.a) * texColor;
        return;
    }

    gl_FragColor = vec4(min(col.rgb, vec3(1.0)) * u_tint, col.a) * texColor;
}