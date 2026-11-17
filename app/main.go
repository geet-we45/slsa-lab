package main

import "fmt"

// version is injected at link time: -X main.version=${GITHUB_REF_NAME}
var version = "dev"

func main() {
	fmt.Printf("hello from slsa-lab %s\n", version)
	extra()
}
