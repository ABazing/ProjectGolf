package org.lwjgl.opengl;
/** Compile-only stand-in (the game's LWJGL is used at runtime; never packaged). */
public class GL20 extends GL15 {
    public static void glAttachShader(int p, int s) { throw new UnsupportedOperationException(); }
    public static void glBindAttribLocation(int p, int i, CharSequence n) { throw new UnsupportedOperationException(); }
    public static void glCompileShader(int s) { throw new UnsupportedOperationException(); }
    public static int glCreateProgram() { throw new UnsupportedOperationException(); }
    public static int glCreateShader(int t) { throw new UnsupportedOperationException(); }
    public static void glDeleteProgram(int p) { throw new UnsupportedOperationException(); }
    public static void glDeleteShader(int s) { throw new UnsupportedOperationException(); }
    public static void glEnableVertexAttribArray(int i) { throw new UnsupportedOperationException(); }
    public static String glGetProgramInfoLog(int p) { throw new UnsupportedOperationException(); }
    public static int glGetProgrami(int p, int n) { throw new UnsupportedOperationException(); }
    public static String glGetShaderInfoLog(int s) { throw new UnsupportedOperationException(); }
    public static int glGetShaderi(int s, int n) { throw new UnsupportedOperationException(); }
    public static int glGetUniformLocation(int p, CharSequence n) { throw new UnsupportedOperationException(); }
    public static void glLinkProgram(int p) { throw new UnsupportedOperationException(); }
    public static void glShaderSource(int s, CharSequence src) { throw new UnsupportedOperationException(); }
    public static void glUniform4f(int l, float a, float b, float c, float d) { throw new UnsupportedOperationException(); }
    public static void glUniformMatrix4fv(int l, boolean t, float[] v) { throw new UnsupportedOperationException(); }
    public static void glUseProgram(int p) { throw new UnsupportedOperationException(); }
    public static void glVertexAttribPointer(int i, int size, int type, boolean norm, int stride, long ptr) { throw new UnsupportedOperationException(); }
}
