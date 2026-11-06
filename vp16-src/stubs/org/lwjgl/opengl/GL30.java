package org.lwjgl.opengl;
/** Compile-only stand-in (the game's LWJGL is used at runtime; never packaged). */
public class GL30 extends GL20 {
    public static void glBindVertexArray(int a) { throw new UnsupportedOperationException(); }
    public static int glGenVertexArrays() { throw new UnsupportedOperationException(); }
}
