package projectgolf.vp16;

/**
 * The one entry point the draw patch calls. ZombieBuddy copies a patch's body into the patched method
 * (viewpoint.render.TranslucentPass.draw), so that body may only touch public classes and methods: this one.
 * Nothing escapes from here into Viewpoint's frame, whatever happens (including our classes failing to load).
 */
public final class DrawHook {

    private static volatile boolean dead;

    private DrawHook() {
    }

    public static void draw(Object frameContext) {
        if (dead) {
            return;
        }
        try {
            if (Viewpoint16.ok) {
                Renderer.draw(frameContext);
            } else {
                dead = true; // 0.1.7+ or an unknown build: never look again
            }
        } catch (Throwable t) {
            dead = true;
            try {
                System.out.println("[ProjectGolf VP16] 3D ball drawing stopped: " + t);
            } catch (Throwable ignored) {
                // nothing more to do
            }
        }
    }
}
