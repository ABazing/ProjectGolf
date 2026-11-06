package projectgolf.ball;

import viewpoint.api.lua.LuaExport;

/**
 * Lua: {@code Viewpoint.Addons["projectgolf.ball"].Ball.flight(...)} and so on (see PG_Viewpoint.lua).
 * An export that throws suspends the addon, so each one checks its input and returns quietly.
 */
@LuaExport
public final class Ball {

    private Ball() {
    }

    /** Starts drawing a flight. path: "x,y,z,g;..." sampled every sampleDt seconds. False if not accepted. */
    public static boolean flight(int id, String path, double sampleDt) {
        BallAddon addon = BallAddon.instance;
        return addon != null && addon.startFlight(id, path, sampleDt);
    }

    /** The flight has ended (the real ball is back on the ground): stop drawing it. */
    public static void stop(int id) {
        BallAddon addon = BallAddon.instance;
        if (addon != null) {
            addon.stopFlight(id);
        }
    }

    /** Shows the aim preview: path "x,y,z,g;...", colour 0..1. */
    public static void preview(String path, double r, double g, double b) {
        BallAddon addon = BallAddon.instance;
        if (addon != null) {
            addon.setPreview(path, r, g, b);
        }
    }

    public static void clearPreview() {
        BallAddon addon = BallAddon.instance;
        if (addon != null) {
            addon.clearPreview();
        }
    }
}
