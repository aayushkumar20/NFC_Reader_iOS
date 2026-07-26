#pragma once
#include <vector>
#include <string>
#include <stdint.h>

class PassportCrypto {
public:
    static std::vector<uint8_t> sha1(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> sha256(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> pad_iso9797(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> unpad_iso9797(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> mac3(const std::vector<uint8_t>& data, const std::vector<uint8_t>& key);
    
    static std::string mrz_check_digit(const std::string& input);
    static std::string pad_mrz_string(const std::string& input, int length);
    static void derive_bac_keys(const std::string& doc_num, const std::string& dob, const std::string& doe,
                                std::vector<uint8_t>& out_enc, std::vector<uint8_t>& out_mac);
                                
    static bool encrypt_3des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                 const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data);
    static bool decrypt_3des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                 const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data);
    static bool encrypt_3des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                 std::vector<uint8_t>& out_data);
                                 
    static bool encrypt_des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data);
    static bool decrypt_des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                std::vector<uint8_t>& out_data);
    static bool encrypt_des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                std::vector<uint8_t>& out_data);
};
