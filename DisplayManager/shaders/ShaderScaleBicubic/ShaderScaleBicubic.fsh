//Bicubic scale adapted by Alynne Keith
//Based on bicubic via Mytino https://marketplace.gamemaker.io/assets/1911/better-scaling

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform vec2 u_vTexelSize;

vec4 cubic(float v)
{
    vec4 texelDistance = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 cubicDistance = texelDistance * texelDistance * texelDistance;
    
    float x = cubicDistance.x;
    float y = cubicDistance.y - 4.0 * cubicDistance.x;
    float z = cubicDistance.z - 4.0 * cubicDistance.y + 6.0 * cubicDistance.x;
    float w = 6.0 - x - y - z;

    return vec4(x, y, z, w);
}

void main()
{
    vec2 coord = v_vTexcoord / u_vTexelSize - 0.5;
    vec2 fractionalCoord = fract(coord);
    coord -= fractionalCoord;

    vec4 xCubic = cubic(fractionalCoord.x);
    vec4 yCubic = cubic(fractionalCoord.y);

    vec4 weighted = vec4(xCubic.x + xCubic.y, yCubic.x + yCubic.y, xCubic.z + xCubic.w, yCubic.z + yCubic.w);
    vec4 offset = vec4(coord - 0.5, coord + 1.5) + vec4(xCubic.y, yCubic.y, xCubic.w, yCubic.w) / weighted;

    vec4 sample0 = texture2D(gm_BaseTexture, offset.xy * u_vTexelSize);
    vec4 sample1 = texture2D(gm_BaseTexture, offset.zy * u_vTexelSize);
    vec4 sample2 = texture2D(gm_BaseTexture, offset.xw * u_vTexelSize);
    vec4 sample3 = texture2D(gm_BaseTexture, offset.zw * u_vTexelSize);

    float xWeight = weighted.x / (weighted.x + weighted.z); 
    vec4 resultX = mix(sample3, sample2, xWeight);
    vec4 resultY = mix(sample1, sample0, xWeight);

    gl_FragColor = v_vColour * mix(resultX, resultY, weighted.y / (weighted.y + weighted.w));
}
