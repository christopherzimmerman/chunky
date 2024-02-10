#version 330

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec4 sunFragColor;
in vec4 vertexPositionOut;
in vec3 fragNormal;
in float passBrightness;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float drawDistance;
uniform float sunlightStrength;

// Output fragment color
out vec4 finalColor;

// Input lighting values
uniform vec4 ambient;
uniform vec3 viewPos;

float getFog(float d)
{
    float fogMax = drawDistance - 32.0;
    float fogMin = drawDistance - 48.0;
    if (d >= fogMax) return 1.0;
    if (d <= fogMin) return 0.0;
    return 1.0 - (fogMax - d) / (fogMax - fogMin);
}

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);
    if (texelColor.a == 0.0)
        discard;

    float d = distance(vec4(0, 0, 0, 0), vertexPositionOut);
    float alpha = getFog(d);

    finalColor = (texelColor*clamp(sunFragColor * sunlightStrength + fragColor, vec4(0.1, 0.1, 0.1, 1), vec4(1,1,1,1))) * (1.0 - alpha);
    finalColor = vec4(finalColor.xyz * passBrightness, finalColor.a);
}