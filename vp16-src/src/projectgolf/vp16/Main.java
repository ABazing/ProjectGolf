package projectgolf.vp16;

/** ZombieBuddy calls this once when the jar loads: say in console.txt whether the bridge is on. */
public final class Main {

    private Main() {
    }

    public static void main(String[] args) {
        if (Viewpoint16.ok) {
            System.out.println("[ProjectGolf VP16] bridge on: Viewpoint 0.1.6 view state, relief and 3D ball");
        } else {
            System.out.println("[ProjectGolf VP16] bridge off: " + Viewpoint16.why);
        }
    }
}
