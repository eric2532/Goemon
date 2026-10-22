#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

namespace ed_psx {
// The recovered Ed effect uses only ABR1, with no destination mask operation.
// This buffer is a foreground contribution, not a general PSX framebuffer.
class Rasterizer {
public:
 bool configure(int width,int height,const uint8_t* indices,size_t index_count,
                const uint8_t* palettes,size_t palette_bytes);
 const std::vector<uint8_t>& render(const int32_t* packets,size_t count);
private:
 int width_=0,height_=0;
 std::vector<uint8_t> indices_,rgba_;
 std::vector<uint16_t> palettes_;
 void triangle(const int32_t* packet);
};
}
