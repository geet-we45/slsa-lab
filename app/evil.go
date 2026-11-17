//go:build evil

package main

import "fmt"

// Harmless training backdoor: prints one line only. No network, no file access.
func extra() {
	fmt.Println("🔓 BACKDOOR ACTIVE (simulated)")
}
