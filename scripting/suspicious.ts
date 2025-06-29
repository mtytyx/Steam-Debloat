function disableOverlay(): void {
    console.log("Steam overlay disabled.");
}

function cleanCache(): void {
    console.log("Steam cache cleaned.");
}

(function debloatSteam() {
    console.log("Running Steam Debloat...");
    disableOverlay();
    cleanCache();
})();
