#include "rasterizer.h"
#include <array>
#include <cassert>
#include <chrono>
#include <iostream>
#include <vector>
using Packet=std::vector<int32_t>;
using Vertex=std::array<int32_t,7>;
Packet triangle(int mode,Vertex a,Vertex b,Vertex c,int row=0,int dither=0) {
 Packet p={mode,row,dither};for(auto v:{a,b,c})p.insert(p.end(),v.begin(),v.end());return p;
}
std::array<int,4> pixel(const std::vector<uint8_t>& image,int x,int y,int width=8) {
 size_t i=(y*width+x)*4;return {image[i],image[i+1],image[i+2],image[i+3]};
}
size_t covered(const std::vector<uint8_t>& image) {size_t n=0;for(size_t i=3;i<image.size();i+=4)n+=image[i]!=0;return n;}
void word(std::vector<uint8_t>& bytes,int index,uint16_t value) {bytes[index*2]=value&255;bytes[index*2+1]=value>>8;}
int main() {
 ed_psx::Rasterizer r;std::vector<uint8_t> indices(65536,1),palette(64,0);
 word(palette,1,0x80b6);word(palette,17,0x811f);
 auto configure=[&]{assert(r.configure(8,8,indices.data(),indices.size(),palette.data(),palette.size()));};
 auto render=[&](const Packet& p)->const std::vector<uint8_t>&{return r.render(p.data(),p.size());};
 assert(r.render(nullptr,0).empty());configure();assert(r.render(nullptr,0).size()==256&&covered(r.render(nullptr,0))==0);
 auto orange=triangle(0x32,{0,0,0,0,255,64,0},{4,0,0,0,255,64,0},{0,4,0,0,255,64,0});
 auto result=render(orange);assert(covered(result)==10);assert((pixel(result,0,0)==std::array<int,4>{31,8,0,255}));assert(pixel(result,3,1)[3]==0);
 auto reverse=triangle(0x32,{0,0,0,0,255,64,0},{0,4,0,0,255,64,0},{4,0,0,0,255,64,0});assert(render(reverse)==result);
 auto twice=orange;twice.insert(twice.end(),orange.begin(),orange.end());assert((pixel(render(twice),1,1)==std::array<int,4>{31,16,0,255}));
 auto flat=triangle(0x22,{0,0,0,0,255,64,0},{4,0,0,0,0,0,0},{0,4,0,0,0,0,0});assert(render(flat)==result);
 auto a=triangle(0x32,{0,0,0,0,8,8,8},{4,0,0,0,8,8,8},{0,4,0,0,8,8,8});
 auto b=triangle(0x32,{4,0,0,0,8,8,8},{4,4,0,0,8,8,8},{0,4,0,0,8,8,8});a.insert(a.end(),b.begin(),b.end());result=render(a);assert(covered(result)==16);
 for(int y=0;y<4;++y)for(int x=0;x<4;++x)assert((pixel(result,x,y)==std::array<int,4>{1,1,1,255}));
 auto modulated=triangle(0x36,{0,0,0,0,106,119,136},{4,0,0,0,106,119,136},{0,4,0,0,106,119,136});
 assert((pixel(render(modulated),1,1)==std::array<int,4>{18,4,0,255}));
 modulated[0]=0x27;assert((pixel(render(modulated),1,1)==std::array<int,4>{22,5,0,255}));
 modulated[1]=1;assert((pixel(render(modulated),1,1)==std::array<int,4>{31,8,0,255}));
 indices.assign(65536,0);configure();assert(covered(render(modulated))==0);
 indices.assign(65536,1);for(int y=0;y<256;++y)indices[y*256+1]=2;word(palette,1,0x8001);word(palette,2,0x8008);configure();
 auto uv=triangle(0x27,{0,0,0,0,128,128,128},{6,0,1,0,128,128,128},{0,6,0,0,128,128,128});
 result=render(uv);assert(pixel(result,3,0)[0]==1&&pixel(result,4,0)[0]==8); // 1/6 gradient truncated toQ12: half-step remains below0.5.
 auto gradient=triangle(0x32,{0,0,0,0,7,7,7},{6,0,0,0,8,8,8},{0,6,0,0,7,7,7});
 result=render(gradient);assert(pixel(result,3,0)[0]==0&&pixel(result,4,0)[0]==1&&pixel(result,3,0)[3]==255);
 auto small=triangle(0x32,{0,0,0,0,7,7,7},{4,0,0,0,7,7,7},{0,4,0,0,7,7,7});auto small_copy=small;small.insert(small.end(),small_copy.begin(),small_copy.end());assert(pixel(render(small),1,1)[0]==0); // Each contribution is quantized separately.
 auto d=triangle(0x32,{0,0,0,0,8,8,8},{4,0,0,0,8,8,8},{0,4,0,0,8,8,8},0,1);result=render(d);assert(pixel(result,0,0)[0]==0&&pixel(result,1,0)[0]==1&&pixel(result,0,1)[0]==1);
 auto clip=triangle(0x32,{-2,-2,0,0,255,64,0},{4,-2,0,0,255,64,0},{-2,4,0,0,255,64,0});result=render(clip);assert(covered(result)==3&&pixel(result,0,0)[3]==255);
 auto degenerate=triangle(0x32,{0,0,0,0,255,0,0},{2,2,0,0,255,0,0},{4,4,0,0,255,0,0});assert(covered(render(degenerate))==0);
 auto malformed=orange;malformed.pop_back();assert(render(malformed).empty());assert(covered(render(orange))==10);
 auto opaque=orange;opaque[0]&=~2;assert(render(opaque).empty());
 word(palette,1,1);assert(!r.configure(8,8,indices.data(),indices.size(),palette.data(),palette.size()));assert(render(orange).empty());word(palette,1,0x8001);
 indices[0]=16;assert(!r.configure(8,8,indices.data(),indices.size(),palette.data(),palette.size()));indices[0]=1;configure();
 assert(covered(r.render(nullptr,0))==0);
 // Representative repeated native-sized meshes, not a whole-frame giant triangle.
 assert(r.configure(320,240,indices.data(),indices.size(),palette.data(),palette.size()));Packet scene;
 for(int i=0;i<300;++i){int x=i%20*14,y=i/20*12;auto t=triangle(0x36,{x,y,0,64,106,119,136},{x+24,y,63,64,128,128,128},{x,y+36,0,127,149,149,161});scene.insert(scene.end(),t.begin(),t.end());}
 auto start=std::chrono::steady_clock::now();for(int i=0;i<100;++i)render(scene);
 double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count()/100;
 std::cout<<"ED_PSX_RASTERIZER_PASS: literal RGB555/texture fixtures, shared-edge coverage, Q12 affine UV/Gouraud, clipping, saturation, mask and malformed-input cases; 300 triangles average "<<ms<<" ms\n";
}
