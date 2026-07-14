#include "UniversalPassportReaderCore.h"
#include "Crypto/PassportCrypto.hpp"
#include "NFC/ASN1Parser.hpp"
#include <string.h>
#include <string>
#include <vector>

void core_derive_bac_keys(const char* doc_num, const char* dob, const char* doe,
                          uint8_t* out_enc_key, uint8_t* out_mac_key) {
    std::vector<uint8_t> enc;
    std::vector<uint8_t> mac;
    PassportCrypto::derive_bac_keys(std::string(doc_num), std::string(dob), std::string(doe), enc, mac);
    
    memcpy(out_enc_key, enc.data(), 16);
    memcpy(out_mac_key, mac.data(), 16);
}

void core_mrz_check_digit(const char* input, char* out_check_digit) {
    std::string res = PassportCrypto::mrz_check_digit(std::string(input));
    strcpy(out_check_digit, res.c_str());
}

void core_compute_retail_mac(const uint8_t* data, int data_len,
                             const uint8_t* key, int key_len,
                             uint8_t* out_mac) {
    std::vector<uint8_t> data_vec(data, data + data_len);
    std::vector<uint8_t> key_vec(key, key + key_len);
    
    std::vector<uint8_t> mac = PassportCrypto::mac3(data_vec, key_vec);
    memcpy(out_mac, mac.data(), 8);
}

bool core_encrypt_3des_cbc(const uint8_t* key, int key_len,
                           const uint8_t* iv, int iv_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len) {
    std::vector<uint8_t> key_vec(key, key + key_len);
    std::vector<uint8_t> iv_vec(iv, iv + iv_len);
    std::vector<uint8_t> data_vec(data, data + data_len);
    std::vector<uint8_t> out;
    
    bool ok = PassportCrypto::encrypt_3des_cbc(key_vec, iv_vec, data_vec, out);
    if (ok) {
        memcpy(out_data, out.data(), out.size());
        *out_len = (int)out.size();
    }
    return ok;
}

bool core_decrypt_3des_cbc(const uint8_t* key, int key_len,
                           const uint8_t* iv, int iv_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len) {
    std::vector<uint8_t> key_vec(key, key + key_len);
    std::vector<uint8_t> iv_vec(iv, iv + iv_len);
    std::vector<uint8_t> data_vec(data, data + data_len);
    std::vector<uint8_t> out;
    
    bool ok = PassportCrypto::decrypt_3des_cbc(key_vec, iv_vec, data_vec, out);
    if (ok) {
        memcpy(out_data, out.data(), out.size());
        *out_len = (int)out.size();
    }
    return ok;
}

bool core_encrypt_3des_ecb(const uint8_t* key, int key_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len) {
    std::vector<uint8_t> key_vec(key, key + key_len);
    std::vector<uint8_t> data_vec(data, data + data_len);
    std::vector<uint8_t> out;
    
    bool ok = PassportCrypto::encrypt_3des_ecb(key_vec, data_vec, out);
    if (ok) {
        memcpy(out_data, out.data(), out.size());
        *out_len = (int)out.size();
    }
    return ok;
}

int core_find_tlv_node(const uint8_t* bytes, int bytes_len, uint32_t tag,
                       uint8_t* out_val, int max_val_len) {
    std::vector<uint8_t> bytes_vec(bytes, bytes + bytes_len);
    std::vector<TLVNodeCpp> nodes = ASN1ParserCpp::parse(bytes_vec);
    TLVNodeCpp found;
    
    if (ASN1ParserCpp::find_node(tag, nodes, found)) {
        int copy_len = (int)found.value.size();
        if (copy_len > max_val_len) copy_len = max_val_len;
        memcpy(out_val, found.value.data(), copy_len);
        return (int)found.value.size(); // Return actual length
    }
    return -1;
}

int core_extract_jpeg_bytes(const uint8_t* bytes, int bytes_len,
                            uint8_t* out_jpeg, int max_jpeg_len) {
    std::vector<uint8_t> bytes_vec(bytes, bytes + bytes_len);
    std::vector<uint8_t> jpeg = ASN1ParserCpp::extract_jpeg_bytes(bytes_vec);
    
    if (!jpeg.empty()) {
        int copy_len = (int)jpeg.size();
        if (copy_len > max_jpeg_len) copy_len = max_jpeg_len;
        memcpy(out_jpeg, jpeg.data(), copy_len);
        return (int)jpeg.size();
    }
    return -1;
}
