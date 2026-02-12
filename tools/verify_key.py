#!/usr/bin/env python3
"""
CLIProxy Management Key Verifier
Kiểm tra key nào match với hash hiện tại trong config.yaml
"""
import bcrypt
import sys

def main():
    # Hash từ config.yaml hiện tại
    current_hash = b"$2a$10$f0VRSxwvKPgAJ80qwBTsLO30dDY9Jcg7I/ZcrXOkGlbSewB45cHcq"
    
    # Danh sách các key phổ biến để thử
    common_keys = [
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
        "brianle",
        "brian",
        "123456",
        "sk-antigravity",
    ]
    
    print("🔍 Đang kiểm tra hash hiện tại trong config.yaml...")
    print(f"Hash: {current_hash.decode()}\n")
    
    found = False
    for key in common_keys:
        try:
            if bcrypt.checkpw(key.encode('utf-8'), current_hash):
                print(f"✅ FOUND! Key đúng là: {key}")
                print(f"\n📋 Sử dụng key này để login dashboard:")
                print(f"   {key}")
                found = True
                break
        except Exception as e:
            continue
    
    if not found:
        print("❌ Không tìm thấy key phù hợp trong danh sách phổ biến.")
        print("\n📝 Các lựa chọn của bạn:")
        print("   1. Nhập key gốc từ backup hoặc ghi chú")
        print("   2. Tạo key mới và update config.yaml")
        print("   3. Chạy script tạo key mới:")
        print("      python3 tools/generate_new_key.py")

if __name__ == "__main__":
    main()
