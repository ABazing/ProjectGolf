package projectgolf.vp16;

import me.zed_0xff.zombie_buddy.Patch;

/**
 * Draws the golf ball at the start of Viewpoint's translucent pass: the solid world is drawn and the scene target
 * and depth buffer are bound - the moment Viewpoint 0.1.7 calls its addons' AFTER_OPAQUE draws.
 * The argument is Viewpoint's FrameContext (typed Object: read by reflection).
 */
@Patch(className = "viewpoint.render.TranslucentPass", methodName = "draw")
public final class Patch_DrawBall {

    private Patch_DrawBall() {
    }

    // ZombieBuddy copies this body into TranslucentPass.draw: it may only call public code (DrawHook is public).
    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) Object frameContext) {
        DrawHook.draw(frameContext);
    }
}
