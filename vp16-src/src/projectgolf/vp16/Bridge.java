package projectgolf.vp16;

import me.zed_0xff.zombie_buddy.Exposer;

/**
 * Lua: the global {@code ProjectGolfVP16} (see PG_Viewpoint.lua). Gives Project Golf on Viewpoint 0.1.6 what
 * Viewpoint 0.1.7 gives it through its addon API: the view state, terrain relief height and the 3D ball.
 * Nothing here throws into Lua: on any problem it answers "off" (false / nil).
 */
@Exposer.LuaClass(name = "ProjectGolfVP16")
public final class Bridge {

    private static boolean warned;

    private Bridge() {
    }

    /** True when this bridge works (Viewpoint 0.1.6 internals found, and no 0.1.7 addon API to use instead). */
    public static boolean active() {
        return Viewpoint16.ok;
    }

    /** Why the bridge is off, for the log (nil when it is on). */
    public static String why() {
        return Viewpoint16.why;
    }

    /** "mode,x,y,z,yaw,pitch,fov" in first / third person, nil in the isometric view. */
    public static String view() {
        if (!Viewpoint16.ok) {
            return null;
        }
        try {
            return Viewpoint16.view();
        } catch (Throwable t) {
            warn(t);
            return null;
        }
    }

    /** Height of Viewpoint's drawn ground at x, y in storeys, or nil when relief is off. */
    public static Double terrainHeight(double x, double y) {
        if (!Viewpoint16.ok) {
            return null;
        }
        try {
            return Viewpoint16.terrainHeight(x, y);
        } catch (Throwable t) {
            warn(t);
            return null;
        }
    }

    // ---- the 3D ball: the same calls as the 0.1.7 addon's Ball export ------------------------------------------------

    /** Starts drawing a flight. path: "x,y,z,g;..." sampled every sampleDt seconds. False if not accepted. */
    public static boolean flight(double id, String path, double sampleDt) {
        return Viewpoint16.ok && !Renderer.broken && Renderer.startFlight((int) id, path, sampleDt);
    }

    /** The flight has ended (the real ball is back on the ground): stop drawing it. */
    public static void stop(double id) {
        Renderer.stopFlight((int) id);
    }

    /** Shows the aim preview: path "x,y,z,g;...", colour 0..1. */
    public static void preview(String path, double r, double g, double b) {
        if (Viewpoint16.ok) {
            Renderer.setPreview(path, r, g, b);
        }
    }

    public static void clearPreview() {
        Renderer.preview = null;
    }

    /** Ball size (1 = real size, default 2) and shadow on / off. */
    public static void settings(double size, boolean shadow) {
        Renderer.setSize(size, shadow);
    }

    /** True while drawing works (false after a GL error stopped it). */
    public static boolean drawing() {
        return Viewpoint16.ok && !Renderer.broken;
    }

    private static void warn(Throwable t) {
        if (!warned) {
            warned = true;
            System.out.println("[ProjectGolf VP16] view read failed: " + t);
        }
    }
}
