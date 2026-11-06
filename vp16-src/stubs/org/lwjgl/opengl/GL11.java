package org.lwjgl.opengl;
/** Compile-only stand-in (the game's LWJGL is used at runtime; never packaged). */
public class GL11 {
    public static void glDrawArrays(int mode, int first, int count) { throw new UnsupportedOperationException(); }
    public static int glGetInteger(int pname) { throw new UnsupportedOperationException(); }
}
