package projectgolf.ball;

/**
 * A path from Lua: points of x, y (world squares), z (ball, storeys) and g (ground under it, storeys).
 * Immutable once parsed, so the render thread can read it while the main thread replaces it.
 */
final class Path {

    static final int MAX_POINTS = 4000;

    final double[] x;
    final double[] y;
    final double[] z;
    final double[] g;
    final int count;

    private Path(double[] x, double[] y, double[] z, double[] g, int count) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.g = g;
        this.count = count;
    }

    /** Parses "x,y,z,g;x,y,z,g;...". Returns null for anything malformed (never throws). */
    static Path parse(String text) {
        if (text == null || text.isEmpty()) {
            return null;
        }
        String[] points = text.split(";");
        int n = Math.min(points.length, MAX_POINTS);
        double[] x = new double[n];
        double[] y = new double[n];
        double[] z = new double[n];
        double[] g = new double[n];
        int count = 0;
        for (int i = 0; i < n; i++) {
            String[] v = points[i].split(",");
            if (v.length < 3) {
                continue;
            }
            try {
                double px = Double.parseDouble(v[0].trim());
                double py = Double.parseDouble(v[1].trim());
                double pz = Double.parseDouble(v[2].trim());
                double pg = v.length > 3 ? Double.parseDouble(v[3].trim()) : Math.floor(pz);
                if (!Double.isFinite(px) || !Double.isFinite(py) || !Double.isFinite(pz) || !Double.isFinite(pg)) {
                    continue;
                }
                x[count] = px;
                y[count] = py;
                z[count] = pz;
                g[count] = pg;
                count++;
            } catch (NumberFormatException e) {
                // skip the point
            }
        }
        return count == 0 ? null : new Path(x, y, z, g, count);
    }

    /** Position at time t (seconds) along a path sampled every dt seconds: {x, y, z, g}. */
    void sample(double t, double dt, double[] out) {
        double f = dt > 0 ? t / dt : 0;
        int i = (int) Math.floor(f);
        if (i >= count - 1) {
            set(out, count - 1);
            return;
        }
        if (i < 0) {
            set(out, 0);
            return;
        }
        double k = f - i;
        out[0] = x[i] + (x[i + 1] - x[i]) * k;
        out[1] = y[i] + (y[i + 1] - y[i]) * k;
        out[2] = z[i] + (z[i + 1] - z[i]) * k;
        out[3] = g[i] + (g[i + 1] - g[i]) * k;
    }

    private void set(double[] out, int i) {
        out[0] = x[i];
        out[1] = y[i];
        out[2] = z[i];
        out[3] = g[i];
    }
}
