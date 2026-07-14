#ifndef UNIVERSAL_PASSPORT_READER_CORE_H
#define UNIVERSAL_PASSPORT_READER_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// BAC Key Derivation API
void core_derive_bac_keys(const char* doc_num, const char* dob, const char* doe,
                          uint8_t* out_enc_key, uint8_t* out_mac_key);

// Check Digit API
void core_mrz_check_digit(const char* input, char* out_check_digit);

// Retail MAC calculation API
void core_compute_retail_mac(const uint8_t* data, int data_len,
                             const uint8_t* key, int key_len,
                             uint8_t* out_mac);

// 3DES CBC Encryption API
bool core_encrypt_3des_cbc(const uint8_t* key, int key_len,
                           const uint8_t* iv, int iv_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len);

// 3DES CBC Decryption API
bool core_decrypt_3des_cbc(const uint8_t* key, int key_len,
                           const uint8_t* iv, int iv_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len);

// 3DES ECB Encryption API (for IV derivation)
bool core_encrypt_3des_ecb(const uint8_t* key, int key_len,
                           const uint8_t* data, int data_len,
                           uint8_t* out_data, int* out_len);

// TLV Node lookup API
// Returns the length of the node value if found, or -1 if not found.
int core_find_tlv_node(const uint8_t* bytes, int bytes_len, uint32_t tag,
                       uint8_t* out_val, int max_val_len);

// JPEG image extractor API
// Returns the length of the extracted JPEG if found, or -1 if not found.
int core_extract_jpeg_bytes(const uint8_t* bytes, int bytes_len,
                            uint8_t* out_jpeg, int max_jpeg_len);

#ifdef __cplusplus
}
#endif

#endif // UNIVERSAL_PASSPORT_READER_CORE_H
