#include <iostream>

void disableSteamOverlay() {
    std::cout << "Steam overlay disabled." << std::endl;
}

void cleanCache() {
    std::cout << "Steam cache cleaned." << std::endl;
}

int main() {
    std::cout << "Starting Steam debloat..." << std::endl;
    disableSteamOverlay();
    cleanCache();
    std::cout << "Done. Go play your games." << std::endl;
    return 0;
}
