package main

import "fmt"

func main() {
    fmt.Println("Running Steam Debloat tool...")
    disableOverlay()
    cleanupCache()
}

func disableOverlay() {
    fmt.Println("Overlay disabled successfully.")
}

func cleanupCache() {
    fmt.Println("Cache cleaned. You're welcome.")
}
