package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	fmt.Println("🔑 CLIProxy Management Key Generator")
	fmt.Println("=====================================")
	fmt.Println()

	reader := bufio.NewReader(os.Stdin)

	// Read password
	fmt.Print("Enter your desired management key: ")
	password, err := reader.ReadString('\n')
	if err != nil {
		fmt.Printf("Error reading input: %v\n", err)
		os.Exit(1)
	}
	password = strings.TrimSpace(password)

	if len(password) < 8 {
		fmt.Println("❌ Error: Password must be at least 8 characters long")
		os.Exit(1)
	}

	// Generate bcrypt hash
	fmt.Println("\n⏳ Generating bcrypt hash...")
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		fmt.Printf("Error generating hash: %v\n", err)
		os.Exit(1)
	}

	// Display results
	fmt.Println("\n✅ Success! Your configuration:")
	fmt.Println("=====================================")
	fmt.Printf("\n📋 Plaintext Key (use this to login):\n   %s\n", password)
	fmt.Printf("\n🔒 Bcrypt Hash (add to config.yaml):\n   %s\n", string(hash))
	fmt.Println("\n📝 Update your config.yaml:")
	fmt.Println("   remote-management:")
	fmt.Println("     allow-remote: true")
	fmt.Printf("     secret-key: \"%s\"\n", string(hash))
	fmt.Println("\n⚠️  Important:")
	fmt.Println("   - Save the plaintext key in a secure location")
	fmt.Println("   - After updating config.yaml, restart the server")
	fmt.Println("   - Use the plaintext key to login to the dashboard")
	fmt.Println()
}
