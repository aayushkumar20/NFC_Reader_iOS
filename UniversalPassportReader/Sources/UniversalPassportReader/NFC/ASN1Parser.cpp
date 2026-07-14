#include "ASN1Parser.hpp"
#include <iostream>

std::vector<TLVNodeCpp> ASN1ParserCpp::parse(const std::vector<uint8_t>& bytes) {
    std::vector<TLVNodeCpp> nodes;
    int index = 0;
    int bytes_count = (int)bytes.size();
    
    while (index < bytes_count) {
        // Skip padding bytes (filler 0x00 or 0xFF)
        while (index < bytes_count && (bytes[index] == 0x00 || bytes[index] == 0xFF)) {
            index++;
        }
        if (index >= bytes_count) break;
        
        // Read Tag
        int tag_start = index;
        uint8_t first_tag_byte = bytes[index];
        index++;
        
        if ((first_tag_byte & 0x1F) == 0x1F) {
            // Multi-byte tag
            while (index < bytes_count) {
                uint8_t next_byte = bytes[index];
                index++;
                if ((next_byte & 0x80) == 0) {
                    break;
                }
            }
        }
        std::vector<uint8_t> tag(bytes.begin() + tag_start, bytes.begin() + index);
        
        // Read Length
        if (index >= bytes_count) break;
        uint8_t first_len_byte = bytes[index];
        index++;
        
        int length = 0;
        if ((first_len_byte & 0x80) == 0) {
            length = first_len_byte;
        } else {
            int num_len_bytes = first_len_byte & 0x7F;
            if (index + num_len_bytes <= bytes_count) {
                for (int i = 0; i < num_len_bytes; i++) {
                    length = (length << 8) | bytes[index];
                    index++;
                }
            } else {
                break;
            }
        }
        
        // Read Value
        if (index + length <= bytes_count) {
            std::vector<uint8_t> value(bytes.begin() + index, bytes.begin() + index + length);
            index += length;
            nodes.push_back({tag, length, value});
        } else {
            std::vector<uint8_t> value(bytes.begin() + index, bytes.end());
            index = bytes_count;
            nodes.push_back({tag, (int)value.size(), value});
            break;
        }
    }
    
    return nodes;
}

bool ASN1ParserCpp::find_node(uint32_t tag, const std::vector<TLVNodeCpp>& nodes, TLVNodeCpp& out_node) {
    for (const auto& node : nodes) {
        if (node.tag_value() == tag) {
            out_node = node;
            return true;
        }
        
        // Check constructed tag (bit 6 is 1)
        if (!node.tag.empty() && (node.tag[0] & 0x20) == 0x20) {
            std::vector<TLVNodeCpp> children = parse(node.value);
            if (find_node(tag, children, out_node)) {
                return true;
            }
        }
    }
    return false;
}

static int find_signature(const std::vector<uint8_t>& signature, const std::vector<uint8_t>& bytes) {
    if (bytes.size() < signature.size()) return -1;
    for (size_t i = 0; i <= bytes.size() - signature.size(); i++) {
        bool found = true;
        for (size_t j = 0; j < signature.size(); j++) {
            if (bytes[i + j] != signature[j]) {
                found = false;
                break;
            }
        }
        if (found) {
            return (int)i;
        }
    }
    return -1;
}

std::vector<uint8_t> ASN1ParserCpp::extract_jpeg_bytes(const std::vector<uint8_t>& bytes) {
    // JPEG start-of-image (FF D8 FF)
    std::vector<uint8_t> jpeg_sig = {0xFF, 0xD8, 0xFF};
    int idx = find_signature(jpeg_sig, bytes);
    if (idx != -1) {
        return std::vector<uint8_t>(bytes.begin() + idx, bytes.end());
    }
    
    // JPEG 2000 start-of-image (00 00 00 0C 6A 50 20 20)
    std::vector<uint8_t> jp2_sig = {0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20};
    idx = find_signature(jp2_sig, bytes);
    if (idx != -1) {
        return std::vector<uint8_t>(bytes.begin() + idx, bytes.end());
    }
    
    return std::vector<uint8_t>();
}
