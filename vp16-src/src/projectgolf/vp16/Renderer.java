package projectgolf.vp16;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL15;
import org.lwjgl.opengl.GL20;
import org.lwjgl.opengl.GL30;

/**
 * The ball, its shadow and the aim preview as 3D spheres in Viewpoint 0.1.6's scene: the same drawing as the 0.1.7
 * addon (projectgolf.ball.BallAddon), at the same point of the frame (after the opaque world, before translucent
 * surfaces, so terrain and walls hide the ball), but with plain OpenGL because 0.1.6 has no addon API.
 *
 * <p>Threads: Lua (main thread) swaps in immutable paths; the draw hook (render thread) only reads them. GL state is
 * left exactly as found (program, vertex array, array buffer). Any error switches drawing off for the session
 * instead of disturbing Viewpoint's frame.</p>
 */
final class Renderer {

    private static final int MAX_FLIGHTS = 32;

    // GL constants as literals (only methods are linked against the game's LWJGL, and only ones Viewpoint uses too)
    private static final int GL_FLOAT = 0x1406;
    private static final int GL_TRIANGLE_STRIP = 0x0005;
    private static final int GL_ARRAY_BUFFER = 0x8892;
    private static final int GL_ARRAY_BUFFER_BINDING = 0x8894;
    private static final int GL_STATIC_DRAW = 0x88E4;
    private static final int GL_VERTEX_ARRAY_BINDING = 0x85B5;
    private static final int GL_CURRENT_PROGRAM = 0x8B8D;
    private static final int GL_FRAGMENT_SHADER = 0x8B30;
    private static final int GL_VERTEX_SHADER = 0x8B31;
    private static final int GL_COMPILE_STATUS = 0x8B81;
    private static final int GL_LINK_STATUS = 0x8B82;

    // ---- shared state (main thread writes, render thread reads) -----------------------------------------------------
    static final Map<Integer, Flight> flights = new ConcurrentHashMap<>();
    static volatile Preview preview;
    static volatile float ballRadius = 0.06f;    // the 0.1.7 addon's default size (2 x real size)
    static volatile float previewRadius = 0.03f;
    static volatile boolean shadows = true;
    static volatile boolean broken;

    // ---- GL objects (render thread only) ----------------------------------------------------------------------------
    private static int program;
    private static int vao;
    private static int vbo;
    private static int vertexCount;
    private static int uView;
    private static int uProj;
    private static int uCenter;
    private static int uColor;
    private static int uShape;

    private static final float[] view = new float[16];
    private static final float[] projection = new float[16];
    private static final double[] origin = new double[3];
    private static final double[] pos = new double[4];

    static final class Flight {
        final Path path;
        final double sampleDt;
        final long startNanos;
        final double duration;
        volatile long stopAtNanos; // 0 = not stopped

        Flight(Path path, double sampleDt) {
            this.path = path;
            this.sampleDt = sampleDt;
            this.startNanos = System.nanoTime();
            this.duration = sampleDt * (path.count - 1);
        }
    }

    static final class Preview {
        final Path path;
        final float r;
        final float g;
        final float b;

        Preview(Path path, float r, float g, float b) {
            this.path = path;
            this.r = r;
            this.g = g;
            this.b = b;
        }
    }

    private Renderer() {
    }

    // ---- main thread ------------------------------------------------------------------------------------------------

    static boolean startFlight(int id, String text, double sampleDt) {
        if (!(sampleDt > 0.0 && sampleDt < 1.0)) {
            return false;
        }
        Path path = Path.parse(text);
        if (path == null || (flights.size() >= MAX_FLIGHTS && !flights.containsKey(id))) {
            return false;
        }
        flights.put(id, new Flight(path, sampleDt));
        return true;
    }

    static void stopFlight(int id) {
        Flight f = flights.get(id);
        if (f != null) {
            f.stopAtNanos = System.nanoTime();
        }
    }

    static void setPreview(String text, double r, double g, double b) {
        Path path = Path.parse(text);
        preview = path == null ? null : new Preview(path, clamp01(r), clamp01(g), clamp01(b));
    }

    static void setSize(double size, boolean shadow) {
        double s = Double.isFinite(size) ? Math.max(0.5, Math.min(6.0, size)) : 2.0;
        ballRadius = (float) (0.03 * s);
        previewRadius = (float) (0.015 * s);
        shadows = shadow;
    }

    // ---- render thread ----------------------------------------------------------------------------------------------

    /** Called at the start of Viewpoint's translucent pass (see DrawHook). */
    static void draw(Object frameContext) {
        Preview pv = preview;
        if (broken || frameContext == null || (flights.isEmpty() && pv == null)) {
            return; // nothing to draw: no GL work at all
        }
        int oldProgram = 0;
        int oldVao = 0;
        int oldBuffer = 0;
        boolean saved = false;
        try {
            if (!Viewpoint16.frameMatrices(frameContext, view, projection, origin)) {
                return;
            }
            oldProgram = GL11.glGetInteger(GL_CURRENT_PROGRAM);
            oldVao = GL11.glGetInteger(GL_VERTEX_ARRAY_BINDING);
            oldBuffer = GL11.glGetInteger(GL_ARRAY_BUFFER_BINDING);
            saved = true;
            if (program == 0) {
                setup();
            }
            GL20.glUseProgram(program);
            GL30.glBindVertexArray(vao);
            GL20.glUniformMatrix4fv(uView, false, view);
            GL20.glUniformMatrix4fv(uProj, false, projection);

            double ox = origin[0];
            double oy = origin[1];
            double oz = origin[2];
            long now = System.nanoTime();
            for (Map.Entry<Integer, Flight> e : flights.entrySet()) {
                Flight f = e.getValue();
                double t = (now - f.startNanos) * 1e-9;
                boolean stopped = f.stopAtNanos != 0 && now - f.stopAtNanos > 100_000_000L;
                if (stopped || t > f.duration + 2.0) {
                    flights.remove(e.getKey());
                    continue;
                }
                f.path.sample(t, f.sampleDt, pos);
                if (shadows) {
                    sphere(pos[0], pos[1], pos[3], ox, oy, oz, ballRadius * 1.7f, 0f, 0f, 0f, 0.55f, 1f);
                }
                sphere(pos[0], pos[1], pos[2], ox, oy, oz, ballRadius, 0.97f, 0.97f, 0.95f, 1f, 0f);
            }
            if (pv != null) {
                Path p = pv.path;
                if (!diagnosed && p.count > 0) {
                    diagnosed = true;
                    diagnose(p.x[0], p.y[0], p.z[0], ox, oy, oz);
                }
                for (int i = 0; i < p.count; i++) {
                    float fade = 1f - 0.5f * i / Math.max(1, p.count);
                    sphere(p.x[i], p.y[i], p.z[i], ox, oy, oz, previewRadius, pv.r * fade, pv.g * fade, pv.b * fade, 1f, 0f);
                }
            }
        } catch (Throwable t) {
            broken = true;
            System.out.println("[ProjectGolf VP16] 3D ball drawing stopped: " + t);
        } finally {
            if (saved) {
                GL20.glUseProgram(oldProgram);
                GL30.glBindVertexArray(oldVao);
                GL15.glBindBuffer(GL_ARRAY_BUFFER, oldBuffer);
            }
        }
    }

    private static boolean diagnosed;

    /** Once: where the first aim point lands, so a placement problem can be read from console.txt. */
    private static void diagnose(double wx, double wy, double wz, double ox, double oy, double oz) {
        float sx = (float) (ox - wx);
        float sy = (float) ((wz - oz) * Viewpoint16.STOREY);
        float sz = (float) (oy - wy);
        float[] v = mul(view, sx, sy, sz, 1f);
        float[] c = mul(projection, v[0], v[1], v[2], v[3]);
        String ndc = c[3] != 0f ? String.format("%.2f, %.2f, %.3f", c[0] / c[3], c[1] / c[3], c[2] / c[3]) : "w=0";
        System.out.println("[ProjectGolf VP16] first aim point: world (" + String.format("%.2f, %.2f, %.2f", wx, wy, wz)
                + ") origin (" + String.format("%.2f, %.2f, %.2f", ox, oy, oz) + ") scene ("
                + String.format("%.2f, %.2f, %.2f", sx, sy, sz) + ") view z " + String.format("%.2f", v[2])
                + " screen " + ndc + " (on screen when x and y are within -1..1)");
    }

    /** Column-major 4x4 matrix times (x, y, z, w). */
    private static float[] mul(float[] m, float x, float y, float z, float w) {
        return new float[] {
            m[0] * x + m[4] * y + m[8] * z + m[12] * w,
            m[1] * x + m[5] * y + m[9] * z + m[13] * w,
            m[2] * x + m[6] * y + m[10] * z + m[14] * w,
            m[3] * x + m[7] * y + m[11] * z + m[15] * w,
        };
    }

    /** World x, y (squares), z (storeys) -> scene space (x west, y up in squares, z north) around the origin. */
    private static void sphere(double wx, double wy, double wz, double ox, double oy, double oz,
                               float radius, float r, float g, float b, float a, float flatten) {
        float sx = (float) (ox - wx);
        // the physics puts the ball's centre on the ground: lift spheres by their radius so they rest on it,
        // and the shadow a little, so it does not flicker against the terrain
        float sy = (float) ((wz - oz) * Viewpoint16.STOREY) + (flatten > 0f ? 0.025f : radius);
        float sz = (float) (oy - wy);
        GL20.glUniform4f(uCenter, sx, sy, sz, radius);
        GL20.glUniform4f(uColor, r, g, b, a);
        GL20.glUniform4f(uShape, flatten, 0f, 0f, 0f);
        GL11.glDrawArrays(GL_TRIANGLE_STRIP, 0, vertexCount);
    }

    private static void setup() {
        int vs = shader(GL_VERTEX_SHADER, Shaders.VERTEX);
        int fs = shader(GL_FRAGMENT_SHADER, Shaders.FRAGMENT);
        int p = GL20.glCreateProgram();
        GL20.glAttachShader(p, vs);
        GL20.glAttachShader(p, fs);
        GL20.glBindAttribLocation(p, 0, "aPos");
        GL20.glBindAttribLocation(p, 1, "aNormal");
        GL20.glLinkProgram(p);
        GL20.glDeleteShader(vs);
        GL20.glDeleteShader(fs);
        if (GL20.glGetProgrami(p, GL_LINK_STATUS) == 0) {
            String log = GL20.glGetProgramInfoLog(p);
            GL20.glDeleteProgram(p);
            throw new IllegalStateException("ball shader did not link: " + log);
        }
        uView = GL20.glGetUniformLocation(p, "uView");
        uProj = GL20.glGetUniformLocation(p, "uProj");
        uCenter = GL20.glGetUniformLocation(p, "uCenter");
        uColor = GL20.glGetUniformLocation(p, "uColor");
        uShape = GL20.glGetUniformLocation(p, "uShape");

        float[] verts = SphereMesh.build(8, 14);
        vertexCount = verts.length / 6;
        vao = GL30.glGenVertexArrays();
        vbo = GL15.glGenBuffers();
        GL30.glBindVertexArray(vao);
        GL15.glBindBuffer(GL_ARRAY_BUFFER, vbo);
        FloatBuffer data = ByteBuffer.allocateDirect(verts.length * Float.BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        data.put(verts).flip();
        GL15.glBufferData(GL_ARRAY_BUFFER, data, GL_STATIC_DRAW);
        GL20.glEnableVertexAttribArray(0);
        GL20.glVertexAttribPointer(0, 3, GL_FLOAT, false, 24, 0L);
        GL20.glEnableVertexAttribArray(1);
        GL20.glVertexAttribPointer(1, 3, GL_FLOAT, false, 24, 12L);
        program = p;
        System.out.println("[ProjectGolf VP16] 3D ball ready (" + vertexCount + " vertices per sphere)");
    }

    private static int shader(int type, String source) {
        int s = GL20.glCreateShader(type);
        GL20.glShaderSource(s, source);
        GL20.glCompileShader(s);
        if (GL20.glGetShaderi(s, GL_COMPILE_STATUS) == 0) {
            String log = GL20.glGetShaderInfoLog(s);
            GL20.glDeleteShader(s);
            throw new IllegalStateException("ball shader did not compile: " + log);
        }
        return s;
    }

    private static float clamp01(double v) {
        return (float) Math.max(0.0, Math.min(1.0, Double.isFinite(v) ? v : 1.0));
    }
}
