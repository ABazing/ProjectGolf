package projectgolf.vp16;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/**
 * Reads Viewpoint 0.1.6's internals by reflection: the camera of the latest frame, terrain relief, and the matrices
 * of the frame being drawn. Mirrors what Viewpoint 0.1.7 publishes to addons (viewpoint.ViewFeed / AddonDraws), so
 * the golf mod sees the same numbers on both versions.
 *
 * <p>Everything is looked up once; if any piece is missing (another Viewpoint build), {@link #ok} stays false and
 * the bridge does nothing. On Viewpoint 0.1.7 and later (which has the addon API) the bridge is off as well: the
 * real addon "projectgolf.ball" does the drawing there.</p>
 */
final class Viewpoint16 {

    static final float STOREY = 2.4494896f; // sqrt(6): squares per storey

    static final boolean ok;
    static final String why;

    // view mode, camera
    private static Field viewEnabled;
    private static Field viewThirdPerson;
    private static Method viewFovY;          // View.fovY(boolean) -> radians
    private static Field fpFrames;           // FP.frames: Frame[]
    private static Method cameraViewPlace;   // CameraView.place(Frame, float, float, float[]) -> boolean
    private static Method cameraEye;         // Camera.eye(Frame, float, float[])
    private static Field fViewYaw;
    private static Field fViewPitch;
    private static Field fOnCamera;
    private static Field fCamX;
    private static Field fCamY;
    private static Field fCamZ;
    private static Field fCameraShot;
    private static Field shotOn;
    private static Field shotFovY;
    // terrain relief
    private static Method reliefCurrent;     // Relief.current() -> FarRelief$Lift
    private static Method liftLevels;
    private static Method liftAt;
    // draw: FrameContext and SceneData
    private static Field fcView;
    private static Field fcProjection;
    private static Field fcScene;
    private static Field sceneOriginX;
    private static Field sceneOriginY;
    private static Field sceneOriginZ;
    private static Method matrixGet;         // org.joml.Matrix4f.get(float[])

    static {
        String reason = null;
        if (has("viewpoint.api.render.DrawPoint")) {
            reason = "Viewpoint has the addon API (0.1.7+): the projectgolf.ball addon draws instead";
        } else {
            try {
                Class<?> view = cls("viewpoint.core.View");
                viewEnabled = field(view, "enabled");
                viewThirdPerson = field(view, "thirdPerson");
                viewFovY = method(view, "fovY", boolean.class);

                Class<?> frame = cls("viewpoint.core.Frame");
                fpFrames = field(cls("viewpoint.FP"), "frames");
                cameraViewPlace = method(cls("viewpoint.camera.CameraView"), "place",
                        frame, float.class, float.class, float[].class);
                cameraEye = method(cls("viewpoint.input.Camera"), "eye", frame, float.class, float[].class);
                fViewYaw = field(frame, "viewYaw");
                fViewPitch = field(frame, "viewPitch");
                fOnCamera = field(frame, "onCamera");
                fCamX = field(frame, "camX");
                fCamY = field(frame, "camY");
                fCamZ = field(frame, "camZ");
                fCameraShot = field(frame, "cameraShot");
                Class<?> shot = cls("viewpoint.core.CameraShot");
                shotOn = field(shot, "on");
                shotFovY = field(shot, "fovY");

                reliefCurrent = method(cls("viewpoint.far.Relief"), "current");
                Class<?> lift = cls("viewpoint.render.FarRelief$Lift");
                liftLevels = method(lift, "levels");
                liftAt = method(lift, "at", double.class, double.class);

                Class<?> fc = cls("viewpoint.render.FrameContext");
                fcView = field(fc, "view");
                fcProjection = field(fc, "jitteredProjection");
                fcScene = field(fc, "scene");
                Class<?> scene = cls("viewpoint.render.SceneData");
                sceneOriginX = field(scene, "originX");
                sceneOriginY = field(scene, "originY");
                sceneOriginZ = field(scene, "originZ");
                matrixGet = method(cls("org.joml.Matrix4f"), "get", float[].class);
            } catch (Throwable t) {
                reason = "this Viewpoint build is not supported (" + t + ")";
            }
        }
        ok = reason == null;
        why = reason;
    }

    private Viewpoint16() {
    }

    private static boolean has(String name) {
        try {
            Class.forName(name, false, Viewpoint16.class.getClassLoader());
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Looks a class up without initialising it (it initialises on first real use, in the game). */
    private static Class<?> cls(String name) throws ClassNotFoundException {
        return Class.forName(name, false, Viewpoint16.class.getClassLoader());
    }

    private static Field field(Class<?> c, String name) throws NoSuchFieldException {
        Field f = c.getDeclaredField(name);
        f.setAccessible(true);
        return f;
    }

    private static Method method(Class<?> c, String name, Class<?>... args) throws NoSuchMethodException {
        Method m = c.getDeclaredMethod(name, args);
        m.setAccessible(true);
        return m;
    }

    // ---- main thread (Lua) ------------------------------------------------------------------------------------------

    /** The latest snapshot frame (player 0), or null. */
    private static Object frame() throws ReflectiveOperationException {
        Object[] frames = (Object[]) fpFrames.get(null);
        return frames != null && frames.length > 0 ? frames[0] : null;
    }

    /**
     * The view when Viewpoint draws first or third person, as "mode,x,y,z,yaw,pitch,fov" (mode 1 first, 2 third;
     * x east, y south in squares, z up in storeys; angles in degrees, fov vertical), else null.
     * Same maths as Viewpoint 0.1.7's view state (ViewFeed.state / WorldPose).
     */
    static String view() throws ReflectiveOperationException {
        if (!viewEnabled.getBoolean(null)) {
            return null;
        }
        Object f = frame();
        if (f == null) {
            return null;
        }
        float yaw = fViewYaw.getFloat(f);
        float pitch = fViewPitch.getFloat(f);
        float[] eye = new float[3];
        if (!fOnCamera.getBoolean(f)) {
            boolean placed = (Boolean) cameraViewPlace.invoke(null, f, yaw, pitch, eye);
            if (!placed) {
                cameraEye.invoke(null, f, yaw, eye);
            }
        }
        double x = fCamX.getFloat(f) - eye[0];
        double y = fCamY.getFloat(f) - eye[2];
        double z = fCamZ.getFloat(f) + eye[1] / STOREY;
        Object shot = fCameraShot.get(f);
        float fov = shot != null && shotOn.getBoolean(shot) ? shotFovY.getFloat(shot) : (Float) viewFovY.invoke(null, false);
        int mode = viewThirdPerson.getBoolean(null) ? 2 : 1;
        if (!Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)) {
            return null;
        }
        return mode + "," + x + "," + y + "," + z + "," + Math.toDegrees(yaw) + "," + Math.toDegrees(pitch) + ","
                + Math.toDegrees(fov);
    }

    /** Height of Viewpoint's drawn ground at x, y in storeys, or null when relief is off. */
    static Double terrainHeight(double x, double y) throws ReflectiveOperationException {
        Object lift = reliefCurrent.invoke(null);
        if (lift == null || (Float) liftLevels.invoke(lift) <= 0f) {
            return null;
        }
        float h = (Float) liftAt.invoke(lift, x, y);
        return Float.isFinite(h) ? (double) h : null;
    }

    // ---- render thread ----------------------------------------------------------------------------------------------

    /** Fills view and projection (column-major) and origin {x, world-y, storeys} for the frame being drawn. */
    static boolean frameMatrices(Object frameContext, float[] view, float[] projection, double[] origin)
            throws ReflectiveOperationException {
        Object v = fcView.get(frameContext);
        Object p = fcProjection.get(frameContext);
        Object scene = fcScene.get(frameContext);
        if (v == null || p == null || scene == null) {
            return false;
        }
        matrixGet.invoke(v, (Object) view);
        matrixGet.invoke(p, (Object) projection);
        // Exactly what Viewpoint 0.1.7 hands its addons as sceneOrigin (render.AddonDraws.view):
        // (-originX, -originZ, originY / sqrt 6) = the camera's world x, world y and storeys.
        origin[0] = -sceneOriginX.getDouble(scene);
        origin[1] = -sceneOriginZ.getDouble(scene);
        origin[2] = sceneOriginY.getDouble(scene) / STOREY;
        return true;
    }
}
