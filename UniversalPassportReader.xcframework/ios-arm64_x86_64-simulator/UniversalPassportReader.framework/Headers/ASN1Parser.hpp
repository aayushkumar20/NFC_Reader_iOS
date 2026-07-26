#pragma once
#include <vector>
#include <stdint.h>

struct TLVNodeCpp {
    std::vector<uint8_t> tag;
    int length;
    std::vector<uint8_t> value;
    
    uint32_t tag_value() const {
        uint32_t val = 0;
        for (uint8_t byte : tag) {
            val = (val << 8) | byte;
        }
        return val;
    }
};

class ASN1ParserCpp {
public:
    static std::vector<TLVNodeCpp> parse(const std::vector<uint8_t>& bytes);
    static bool find_node(uint32_t tag, const std::vector<TLVNodeCpp>& nodes, TLVNodeCpp& out_node);
    static std::vector<uint8_t> extract_jpeg_bytes(const std::vector<uint8_t>& bytes);
};
