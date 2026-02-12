package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	// Hash từ config.yaml hiện tại
	currentHash := "$2a$10$f0VRSxwvKPgAJ80qwBTsLO30dDY9Jcg7I/ZcrXOkGlbSewB45cHcq"
	
	// Danh sách các key phổ biến để thử
	commonKeys := []string{
		"sk-antigravity-management",
		"sk-antigravity-client-key",
		"admin",
		"password",
		"secret",
		"management",
		"831227",
		"34ba56f38983bb7f1d32bc6a0c6d54a0",
		"cliproxy",
		"antigravity",
		"sk-management",
		"cliproxy-management",
	}

	fmt.Println("🔍 Đang kiểm tra hash hiện tại trong config.yaml...")
	fmt.Printf("Hash: %s\n\n", currentHash)
	
	found := false
	for _, key := range commonKeys {
		err := bcrypt.CompareHashAndPassword([]byte(currentHash), []byte(key))
		if err == nil {
			fmt.Printf("✅ FOUND! Key đúng là: %s\n", key)
			found = true
			break
		}
	}
	
	if !found {
		fmt.Println("❌ Không tìm thấy key phù hợp trong danh sách phổ biến.")
		fmt.Println("\n📝 Các lựa chọn của bạn:")
		fmt.Println("   1. Tìm lại key gốc từ backup hoặc ghi chú")
		fmt.Println("   2. Tạo key mới bằng tool: tools/generate_management_key.go")
		fmt.Println("   3. Liên hệ người đã setup server này")
	}
}
