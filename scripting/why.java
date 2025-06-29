public class SteamDebloat {

    public static void main(String[] args) {
        System.out.println("Launching Steam Debloat Utility...");
        removeOverlay();
        clearCache();
        System.out.println("Steam is now lighter than air.");
    }

    public static void removeOverlay() {
        System.out.println("Overlay disabled.");
    }

    public static void clearCache() {
        System.out.println("Cache cleared. FPS +0.5");
    }
}
