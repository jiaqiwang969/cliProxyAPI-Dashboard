#!/usr/bin/env python3
"""
Generate new Management Key and update config.yaml
"""
import bcrypt
import secrets
import string

def generate_secure_key(length=48):
    """Generate a cryptographically secure random key"""
    alphabet = string.ascii_letters + string.digits + '-_'
    key = 'sk-mgmt-' + ''.join(secrets.choice(alphabet) for _ in range(length))
    return key

def main():
    print("🔐 Tạo Management Key mới cho CLIProxy")
    print("=" * 50)
    
    # Generate new key
    new_key = generate_secure_key()
    print(f"\n✅ Key mới đã được tạo:")
    print(f"   {new_key}")
    
    # Generate bcrypt hash
    print("\n⏳ Đang tạo bcrypt hash...")
    hash_bytes = bcrypt.hashpw(new_key.encode('utf-8'), bcrypt.gensalt())
    hash_str = hash_bytes.decode('utf-8')
    
    print(f"\n🔒 Hash bcrypt:")
    print(f"   {hash_str}")
    
    print("\n" + "=" * 50)
    print("📋 THÔNG TIN QUAN TRỌNG - HÃY LƯU LẠI:")
    print("=" * 50)
    print(f"\n🔑 Management Key (dùng để login):")
    print(f"   {new_key}")
    print(f"\n💾 Bcrypt Hash (đã update vào config.yaml):")
    print(f"   {hash_str}")
    print("\n" + "=" * 50)
    
    # Update config.yaml
    config_path = "config.yaml"
    print(f"\n📝 Đang update {config_path}...")
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Find and replace the secret-key line
        updated = False
        for i, line in enumerate(lines):
            if 'secret-key:' in line:
                indent = len(line) - len(line.lstrip())
                lines[i] = ' ' * indent + f'secret-key: "{hash_str}"\n'
                updated = True
                break
        
        if updated:
            with open(config_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f"✅ Đã update {config_path} thành công!")
        else:
            print(f"⚠️  Không tìm thấy dòng secret-key trong {config_path}")
            print(f"   Vui lòng thêm thủ công:")
            print(f"   remote-management:")
            print(f'     secret-key: "{hash_str}"')
            
    except Exception as e:
        print(f"❌ Lỗi khi update config: {e}")
        return
    
    print("\n✅ Hoàn tất! Bây giờ hãy:")
    print("   1. Restart Docker container")
    print("   2. Đăng nhập dashboard với key mới")
    print(f"   3. Key: {new_key}")

if __name__ == "__main__":
    main()
