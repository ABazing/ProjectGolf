package projectgolf.ball;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import viewpoint.api.*;
import viewpoint.api.render.*;

/**
 * Draws Project Golf's ball, its shadow and the aim preview as real 3D spheres inside Viewpoint's scene.
 *
 * <p>Threads: Lua calls {@link Ball} on the main thread, which parses the text into immutable {@link Path}s and
 * swaps them in. The draw callback runs on the render thread and only reads those snapshots, so nothing is locked
 * while drawing. Cost: one small sphere and one shadow per ball in flight, and up to ~50 tiny spheres for the
 * preview while aiming. Nothing at all when no ball is flying and nobody is aiming.</p>
 */
public final class BallAddon implements Addon {

    static volatile BallAddon instance;

    private static final double STOREY = Math.sqrt(6.0); // squares per storey (docs: view state)
    private static final int MAX_FLIGHTS = 32;

    // ---- shared state (main thread writes, render thread reads) ---------------------------------------------------
    private final Map<Integer, Flight> flights = new ConcurrentHashMap<>();
    private volatile Preview preview;
    private volatile float ballRadius = 0.06f;
    private volatile float previewRadius = 0.03f;
    private volatile boolean shadows = true;

    // ---- GPU objects (render thread only) ---------------------------------------------------------------------------
    private GpuProgram program;
    private GpuMesh sphere;
    private int sphereVertices;
    private final double[] pos = new double[4];

    private AddonContext ctx;

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

    @Override
    public void enable(AddonContext ctx) {
        this.ctx = ctx;
        readSettings();
        ctx.settings().onChange("size", this::readSettings);
        ctx.settings().onChange("shadow", this::readSettings);
        ctx.render().draw(DrawPoint.AFTER_OPAQUE, this::draw);
        instance = this;
        System.out.println("[ProjectGolf Ball] on");
    }

    @Override
    public void disable() {
        instance = null;
        flights.clear();
        preview = null;
        System.out.println("[ProjectGolf Ball] off");
    }

    private void readSettings() {
        double size = ctx.settings().number("size");
        ballRadius = (float) (0.03 * size);
        previewRadius = (float) (0.015 * size);
        shadows = ctx.settings().toggle("shadow");
    }

    // ---- called from Lua through Ball (main thread) ----------------------------------------------------------------

    boolean startFlight(int id, String text, double sampleDt) {
        if (!(sampleDt > 0.0 && sampleDt < 1.0)) {
            return false;
        }
        Path path = Path.parse(text);
        if (path == null) {
            return false;
        }
        if (flights.size() >= MAX_FLIGHTS && !flights.containsKey(id)) {
            return false;
        }
        flights.put(id, new Flight(path, sampleDt));
        return true;
    }

    void stopFlight(int id) {
        Flight f = flights.get(id);
        if (f != null) {
            f.stopAtNanos = System.nanoTime();
        }
    }

    void setPreview(String text, double r, double g, double b) {
        Path path = Path.parse(text);
        preview = path == null ? null : new Preview(path, clamp01(r), clamp01(g), clamp01(b));
    }

    void clearPreview() {
        preview = null;
    }

    // ---- render thread ---------------------------------------------------------------------------------------------

    private void draw(DrawContext context) {
        Preview pv = preview;
        if (flights.isEmpty() && pv == null) {
            return; // nothing to draw: no GPU work at all
        }
        FrameView view = context.view();
        Gpu gpu = context.gpu();
        if (program == null) {
            program = gpu.program(Shaders.VERTEX, Shaders.FRAGMENT);
            float[] verts = SphereMesh.build(8, 14);
            sphereVertices = verts.length / 6;
            sphere = gpu.mesh(gpu.buffer(verts.length * Float.BYTES).upload(verts), 3, 3);
        }

        var origin = view.sceneOrigin();
        double ox = origin.x();
        double oy = origin.y();
        double oz = origin.z();
        program.setMatrix("uView", view.view()).setMatrix("uProj", view.projection());

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
                drawSphere(gpu, pos[0], pos[1], pos[3], ox, oy, oz, ballRadius * 1.7f, 0f, 0f, 0f, 0.55f, 1f);
            }
            drawSphere(gpu, pos[0], pos[1], pos[2], ox, oy, oz, ballRadius, 0.97f, 0.97f, 0.95f, 1f, 0f);
        }

        if (pv != null) {
            Path p = pv.path;
            for (int i = 0; i < p.count; i++) {
                float fade = 1f - 0.5f * i / Math.max(1, p.count);
                drawSphere(gpu, p.x[i], p.y[i], p.z[i], ox, oy, oz, previewRadius, pv.r * fade, pv.g * fade, pv.b * fade, 1f, 0f);
            }
        }
    }

    /** World x, y (squares), z (storeys) -> scene space (x west, y up in squares, z north) around the origin. */
    private void drawSphere(Gpu gpu, double wx, double wy, double wz, double ox, double oy, double oz,
                            float radius, float r, float g, float b, float a, float flatten) {
        float sx = (float) (ox - wx);
        // the physics puts the ball's centre on the ground: lift spheres by their radius so they rest on it,
        // and the shadow a little, so it does not flicker against the terrain
        float sy = (float) ((wz - oz) * STOREY) + (flatten > 0f ? 0.025f : radius);
        float sz = (float) (oy - wy);
        program.set("uCenter", sx, sy, sz, radius)
                .set("uColor", r, g, b, a)
                .set("uShape", flatten, 0f, 0f, 0f);
        gpu.draw(program, sphere, Primitive.TRIANGLE_STRIP, 0, sphereVertices);
    }

    private static float clamp01(double v) {
        return (float) Math.max(0.0, Math.min(1.0, Double.isFinite(v) ? v : 1.0));
    }
}
