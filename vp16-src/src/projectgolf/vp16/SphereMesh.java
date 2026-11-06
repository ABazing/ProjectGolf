package projectgolf.vp16;

/**
 * A unit UV sphere as one triangle strip (bands joined by degenerate triangles).
 * Each vertex: position x, y, z then normal x, y, z (the same for a unit sphere).
 */
final class SphereMesh {

    private SphereMesh() {
    }

    static float[] build(int stacks, int slices) {
        int perBand = (slices + 1) * 2;
        int vertices = stacks * perBand + (stacks - 1) * 2; // + degenerate joins
        float[] out = new float[vertices * 6];
        int o = 0;
        for (int s = 0; s < stacks; s++) {
            double phi0 = Math.PI * s / stacks;
            double phi1 = Math.PI * (s + 1) / stacks;
            if (s > 0) {
                o = put(out, o, phi0, 0); // degenerate: repeat the first vertex of this band
            }
            for (int i = 0; i <= slices; i++) {
                double theta = 2 * Math.PI * i / slices;
                o = put(out, o, phi0, theta);
                o = put(out, o, phi1, theta);
            }
            if (s < stacks - 1) {
                o = put(out, o, phi1, 2 * Math.PI); // degenerate: repeat the last vertex of this band
            }
        }
        return out;
    }

    private static int put(float[] out, int o, double phi, double theta) {
        float x = (float) (Math.sin(phi) * Math.cos(theta));
        float y = (float) Math.cos(phi);
        float z = (float) (Math.sin(phi) * Math.sin(theta));
        out[o] = x;
        out[o + 1] = y;
        out[o + 2] = z;
        out[o + 3] = x;
        out[o + 4] = y;
        out[o + 5] = z;
        return o + 6;
    }
}
