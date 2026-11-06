package org.lwjgl.opengl;
/** Compile-only stand-in (the game's LWJGL is used at runtime; never packaged). */
public class GL15 extends GL11 {
    public static void glBindBuffer(int target, int buffer) { throw new UnsupportedOperationException(); }
    public static void glBufferData(int target, java.nio.FloatBuffer data, int usage) { throw new UnsupportedOperationException(); }
    public static int glGenBuffers() { throw new UnsupportedOperationException(); }
}
