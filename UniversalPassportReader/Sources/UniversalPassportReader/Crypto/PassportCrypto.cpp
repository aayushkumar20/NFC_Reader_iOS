#include "PassportCrypto.hpp"
#include <CommonCrypto/CommonCrypto.h>
#include <algorithm>
#include <stdexcept>
#include <iostream>

std::vector<uint8_t> PassportCrypto::sha1(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> hash(CC_SHA1_DIGEST_LENGTH);
    CC_SHA1(data.data(), (CC_LONG)data.size(), hash.data());
    return hash;
}

std::vector<uint8_t> PassportCrypto::sha256(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> hash(CC_SHA256_DIGEST_LENGTH);
    CC_SHA256(data.data(), (CC_LONG)data.size(), hash.data());
    return hash;
}

std::vector<uint8_t> PassportCrypto::pad_iso9797(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> padded = data;
    padded.push_back(0x80);
    while (padded.size() % 8 != 0) {
        padded.push_back(0x00);
    }
    return padded;
}

std::vector<uint8_t> PassportCrypto::unpad_iso9797(const std::vector<uint8_t>& data) {
    if (data.empty()) return data;
    int index = (int)data.size() - 1;
    while (index >= 0) {
        if (data[index] == 0x80) {
            return std::vector<uint8_t>(data.begin(), data.begin() + index);
        } else if (data[index] == 0x00) {
            index--;
        } else {
            break;
        }
    }
    return data;
}

static bool crypt(CCOperation op, CCAlgorithm alg, CCOptions options,
                  const std::vector<uint8_t>& key, const uint8_t* iv,
                  const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data) {
    std::vector<uint8_t> key_bytes = key;
    if (alg == kCCAlgorithm3DES && key_bytes.size() == 16) {
        key_bytes.insert(key_bytes.end(), key_bytes.begin(), key_bytes.begin() + 8);
    }
    
    size_t out_available = data.size() + 1024;
    std::vector<uint8_t> out_buffer(out_available);
    size_t out_moved = 0;
    
    CCCryptorStatus status = CCCrypt(
        op,
        alg,
        options,
        key_bytes.data(),
        key_bytes.size(),
        iv,
        data.data(),
        data.size(),
        out_buffer.data(),
        out_buffer.size(),
        &out_moved
    );
    
    if (status != kCCSuccess) {
        return false;
    }
    
    out_data = std::vector<uint8_t>(out_buffer.begin(), out_buffer.begin() + out_moved);
    return true;
}

bool PassportCrypto::encrypt_3des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                      const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data) {
    return crypt(kCCEncrypt, kCCAlgorithm3DES, 0, key, iv.data(), data, out_data);
}

bool PassportCrypto::decrypt_3des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                      const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data) {
    return crypt(kCCDecrypt, kCCAlgorithm3DES, 0, key, iv.data(), data, out_data);
}

bool PassportCrypto::encrypt_3des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                      std::vector<uint8_t>& out_data) {
    return crypt(kCCEncrypt, kCCAlgorithm3DES, kCCOptionECBMode, key, nullptr, data, out_data);
}

bool PassportCrypto::encrypt_des_cbc(const std::vector<uint8_t>& key, const std::vector<uint8_t>& iv,
                                     const std::vector<uint8_t>& data, std::vector<uint8_t>& out_data) {
    return crypt(kCCEncrypt, kCCAlgorithmDES, 0, key, iv.data(), data, out_data);
}

bool PassportCrypto::decrypt_des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                     std::vector<uint8_t>& out_data) {
    return crypt(kCCDecrypt, kCCAlgorithmDES, kCCOptionECBMode, key, nullptr, data, out_data);
}

bool PassportCrypto::encrypt_des_ecb(const std::vector<uint8_t>& key, const std::vector<uint8_t>& data,
                                     std::vector<uint8_t>& out_data) {
    return crypt(kCCEncrypt, kCCAlgorithmDES, kCCOptionECBMode, key, nullptr, data, out_data);
}

std::vector<uint8_t> PassportCrypto::mac3(const std::vector<uint8_t>& data, const std::vector<uint8_t>& key) {
    std::vector<uint8_t> padded = pad_iso9797(data);
    std::vector<uint8_t> ka(key.begin(), key.begin() + 8);
    std::vector<uint8_t> kb(key.begin() + 8, key.begin() + 16);
    
    std::vector<uint8_t> zeroes(8, 0);
    std::vector<uint8_t> cbc_result;
    if (!encrypt_des_cbc(ka, zeroes, padded, cbc_result)) {
        return zeroes;
    }
    
    std::vector<uint8_t> yn(cbc_result.end() - 8, cbc_result.end());
    
    std::vector<uint8_t> w;
    if (!decrypt_des_ecb(kb, yn, w)) {
        return zeroes;
    }
    
    std::vector<uint8_t> mac;
    if (!encrypt_des_ecb(ka, w, mac)) {
        return zeroes;
    }
    
    return mac;
}

std::string PassportCrypto::mrz_check_digit(const std::string& input) {
    int weights[] = {7, 3, 1};
    int sum = 0;
    
    for (size_t i = 0; i < input.length(); i++) {
        char c = toupper(input[i]);
        int val = 0;
        if (c >= '0' && c <= '9') {
            val = c - '0';
        } else if (c >= 'A' && c <= 'Z') {
            val = c - 'A' + 10;
        } else {
            val = 0; // '<' filler
        }
        sum += val * weights[i % 3];
    }
    
    return std::to_string(sum % 10);
}

std::string PassportCrypto::pad_mrz_string(const std::string& input, int length) {
    std::string str = input;
    std::transform(str.begin(), str.end(), str.begin(), ::toupper);
    std::replace(str.begin(), str.end(), ' ', '<');
    
    if ((int)str.length() > length) {
        return str.substr(0, length);
    } else {
        while ((int)str.length() < length) {
            str.push_back('<');
        }
    }
    return str;
}

void PassportCrypto::derive_bac_keys(const std::string& doc_num, const std::string& dob, const std::string& doe,
                                     std::vector<uint8_t>& out_enc, std::vector<uint8_t>& out_mac) {
    std::string clean_doc = pad_mrz_string(doc_num, 9);
    std::string clean_dob = pad_mrz_string(dob, 6);
    std::string clean_doe = pad_mrz_string(doe, 6);
    
    std::string doc_check = mrz_check_digit(clean_doc);
    std::string dob_check = mrz_check_digit(clean_dob);
    std::string doe_check = mrz_check_digit(clean_doe);
    
    std::string info = clean_doc + doc_check + clean_dob + dob_check + clean_doe + doe_check;
    std::vector<uint8_t> info_bytes(info.begin(), info.end());
    
    std::vector<uint8_t> hash = sha1(info_bytes);
    std::vector<uint8_t> k_seed(hash.begin(), hash.begin() + 16);
    
    std::vector<uint8_t> k_seed_enc = k_seed;
    uint8_t enc_suffix[] = {0x00, 0x00, 0x00, 0x01};
    k_seed_enc.insert(k_seed_enc.end(), enc_suffix, enc_suffix + 4);
    
    std::vector<uint8_t> k_seed_mac = k_seed;
    uint8_t mac_suffix[] = {0x00, 0x00, 0x00, 0x02};
    k_seed_mac.insert(k_seed_mac.end(), mac_suffix, mac_suffix + 4);
    
    std::vector<uint8_t> hash_enc = sha1(k_seed_enc);
    std::vector<uint8_t> hash_mac = sha1(k_seed_mac);
    
    out_enc = std::vector<uint8_t>(hash_enc.begin(), hash_enc.begin() + 16);
    out_mac = std::vector<uint8_t>(hash_mac.begin(), hash_mac.begin() + 16);
}
