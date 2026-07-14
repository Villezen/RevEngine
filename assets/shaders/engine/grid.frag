#pragma header

uniform vec2 u_spriteSize;
uniform float u_gridSize;
uniform float u_outline;

uniform bool u_outlineTop;    
uniform bool u_outlineBottom; 

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
        gl_FragColor = colorOutline;
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
    
    float stepsPerBeat = 16.0 / 4.0; 
    float beatHeight = stepsPerBeat * u_gridSize;

    float beatIndex = floor(gridY / beatHeight);

    if (mod(beatIndex, 2.0) >= 1.0)
    {
        col.rgb *= 0.7; 
    }

    vec4 texColor = flixel_texture2D(bitmap, uv);
    
    gl_FragColor = vec4(min(col.rgb, vec3(1.0)), col.a) * texColor;
}