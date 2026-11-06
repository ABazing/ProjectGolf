package projectgolf.ball;

/**
 * The ball's shaders. One program draws both the ball (lit sphere) and its shadow (the same sphere flattened
 * onto the ground, faded at the edge with an ordered dither, so it needs no blending and still writes depth).
 */
final class Shaders {

    private Shaders() {
    }

    static final String VERTEX = String.join("\n",
            "#version 330 core",
            "layout(location = 0) in vec3 aPos;",
            "layout(location = 1) in vec3 aNormal;",
            "uniform mat4 uView;",
            "uniform mat4 uProj;",
            "uniform vec4 uCenter;   // xyz scene position, w radius",
            "uniform vec4 uShape;    // x > 0.5: flat shadow disc",
            "out vec3 vNormal;",
            "out vec3 vLocal;",
            "void main() {",
            "    vec3 p = aPos;",
            "    if (uShape.x > 0.5) p.y = 0.0;",
            "    vLocal = p;",
            "    vNormal = aNormal;",
            "    gl_Position = uProj * uView * vec4(uCenter.xyz + p * uCenter.w, 1.0);",
            "}",
            "");

    static final String FRAGMENT = String.join("\n",
            "#version 330 core",
            "in vec3 vNormal;",
            "in vec3 vLocal;",
            "uniform vec4 uColor;",
            "uniform vec4 uShape;",
            "out vec4 fragColor;",
            "float bayer4(vec2 p) {",
            "    ivec2 i = ivec2(mod(p, 4.0));",
            "    int idx = i.x + i.y * 4;",
            "    float m[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);",
            "    return (m[idx] + 0.5) / 16.0;",
            "}",
            "void main() {",
            "    if (uShape.x > 0.5) {",
            "        float a = uColor.a * (1.0 - smoothstep(0.35, 1.0, length(vLocal.xz)));",
            "        if (a < bayer4(gl_FragCoord.xy)) discard;",
            "        fragColor = vec4(0.0, 0.0, 0.0, 1.0);",
            "        return;",
            "    }",
            "    vec3 n = normalize(gl_FrontFacing ? vNormal : -vNormal);",
            "    vec3 l = normalize(vec3(0.35, 1.0, 0.25));",
            "    float diffuse = 0.45 + 0.55 * max(dot(n, l), 0.0);",
            "    fragColor = vec4(uColor.rgb * diffuse, 1.0);",
            "}",
            "");
}
