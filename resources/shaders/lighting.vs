#version 330

// Input vertex attributes
layout(location=0) in vec3 vertexPosition;
layout(location=1) in vec2 vertexTexCoord;
layout(location=2) in vec3 vertexNormal;
layout(location=5) in vec2 vertexTexCoord2;

// Input uniform values
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec4 sunFragColor;
out vec3 fragNormal;
out vec4 vertexPositionOut;
out float passBrightness;

// NOTE: Add here your custom variables

void main()
{
    // Send vertex attributes to fragment shader
    fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vec4((int(vertexTexCoord2.x) >> 4) / 15.0, (int(vertexTexCoord2.x) >> 4) / 15.0, (int(vertexTexCoord2.x) >> 4) / 15.0, 1.0);
    sunFragColor = vec4((int(vertexTexCoord2.y) & 15) / 15.0, (int(vertexTexCoord2.y) & 15) / 15.0, (int(vertexTexCoord2.y) & 15) / 15.0, 1.0);
    fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));
    passBrightness = 0.6;
    passBrightness += clamp(dot(vec3(-0.5, 0.4, 0.0), fragNormal), -0.15, 1.0) * 0.5;
    passBrightness += clamp(dot(vec3(0.5, 0.4, 0.0), fragNormal), -0.15, 1.0) * 0.5;
    passBrightness = clamp(passBrightness, 0.0, 1.0);

    // Calculate final vertex position
    vertexPositionOut = mvp*vec4(vertexPosition, 1.0);
    gl_Position = vertexPositionOut;
}