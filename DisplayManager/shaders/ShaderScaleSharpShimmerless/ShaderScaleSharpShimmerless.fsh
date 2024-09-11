//Sharp Shimmerless scale adapted by Alynne Keith
//Based on  Sharp Shimmerless by Woohyun Kang   2023-01-24
//https://github.com/Woohyun-Kang/Sharp-Shimmerless-Shader

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2 u_vTexelSize;
uniform vec2 u_vScale;

void main()
{
    vec2 pixelPos = v_vTexcoord * u_vScale / u_vTexelSize;
    vec2 pixelFloored = floor(pixelPos);
    vec2 pixelCeiled = ceil(pixelPos);
    vec2 invScale = vec2(1.0) / u_vScale;
    vec2 texelFloored = floor(invScale * pixelFloored);
    vec2 texelCeiled = floor(invScale * pixelCeiled);

    vec2 finalTexCoord;
    if (texelFloored.x == texelCeiled.x)
    {
        finalTexCoord.x = texelCeiled.x + 0.5;
    }
    else
    {
        finalTexCoord.x = texelCeiled.x + 0.5 - (u_vScale.x * texelCeiled.x - pixelFloored.x);
    }

    if (texelFloored.y == texelCeiled.y)
    {
        finalTexCoord.y = texelCeiled.y + 0.5;   
    }
    else
    {
        finalTexCoord.y = texelCeiled.y + 0.5 - (u_vScale.y * texelCeiled.y - pixelFloored.y);
    }
    
    gl_FragColor = v_vColour*texture2D(gm_BaseTexture, finalTexCoord*u_vTexelSize);
}
