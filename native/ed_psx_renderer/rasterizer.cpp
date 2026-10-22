#include "rasterizer.h"
#include <algorithm>
#include <array>
#include <limits>

namespace ed_psx {
namespace {
struct Vertex {int32_t x,y;std::array<int32_t,5> attribute;};
int64_t edge(const Vertex& a,const Vertex& b,int x,int y) {
 return int64_t(b.x-a.x)*(y-a.y)-int64_t(b.y-a.y)*(x-a.x);
}
bool inclusive(const Vertex& a,const Vertex& b) {
 return b.y<a.y || (b.y==a.y && b.x>a.x);
}
int64_t floor_q12(int64_t value) {
 return value>=0?value/4096:-((-value+4095)/4096);
}
constexpr int dither[16]={-4,0,-3,1,2,-2,3,-1,-3,1,-4,0,3,-1,2,-2};
}

bool Rasterizer::configure(int w,int h,const uint8_t* indices,size_t count,const uint8_t* palette,size_t bytes) {
 width_=height_=0;rgba_.clear();indices_.clear();palettes_.clear();
 if(w<1||h<1||w>2048||h>2048||count!=65536||bytes==0||bytes%32||bytes>8192||!indices||!palette)return false;
 for(size_t i=0;i<count;++i)if(indices[i]>15)return false;
 for(size_t i=0;i<bytes;i+=2) {
  uint16_t word=uint16_t(palette[i])|(uint16_t(palette[i+1])<<8);
  if(word && !(word&0x8000)) {palettes_.clear();return false;}
  palettes_.push_back(word);
 }
 width_=w;height_=h;indices_.assign(indices,indices+count);rgba_.resize(size_t(w)*h*4);return true;
}

const std::vector<uint8_t>& Rasterizer::render(const int32_t* packets,size_t count) {
 rgba_.clear();
 if(!width_||count%24||(!packets&&count))return rgba_;
 // Reject unsupported opaque packets rather than silently pretending to add them.
 for(size_t i=0;i<count;i+=24) {
  const int32_t* p=packets+i;
  if(!(p[0]&2)||(p[2]!=0&&p[2]!=1))return rgba_;
  if((p[0]&4)&&(p[1]<0||size_t(p[1])>=palettes_.size()/16))return rgba_;
  for(int v=0;v<3;++v)for(int a=0;a<7;++a) {
   int value=p[3+v*7+a];
   if(a<2 ? (value<-32768||value>32767) : (value<0||value>255))return rgba_;
  }
 }
 rgba_.assign(size_t(width_)*height_*4,0);
 for(size_t i=0;i<count;i+=24)triangle(packets+i);
 return rgba_;
}

void Rasterizer::triangle(const int32_t* p) {
 Vertex v[3];
 for(int i=0;i<3;++i) {v[i].x=p[3+i*7];v[i].y=p[4+i*7];for(int a=0;a<5;++a)v[i].attribute[a]=p[5+i*7+a];}
 const bool textured=p[0]&4,raw=p[0]&1,gouraud=p[0]&16;
 if(!gouraud)for(int i=1;i<3;++i)for(int a=2;a<5;++a)v[i].attribute[a]=v[0].attribute[a];
 int low_x=std::min({v[0].x,v[1].x,v[2].x}),high_x=std::max({v[0].x,v[1].x,v[2].x});
 int low_y=std::min({v[0].y,v[1].y,v[2].y}),high_y=std::max({v[0].y,v[1].y,v[2].y});
 // Native GPU rejects polygons exceeding its maximum coordinate spans.
 if(high_x-low_x>=1024||high_y-low_y>=512)return;
 int anchor=0;
 for(int i=1;i<3;++i)if(v[i].x<=v[anchor].x)anchor=i;
 if(v[0].x==v[2].x&&v[0].x<v[1].x)anchor=0;
 const Vertex start=v[anchor];
 int64_t area=edge(v[0],v[1],v[2].x,v[2].y);if(!area)return;
 if(area<0){std::swap(v[1],v[2]);area=-area;}
 std::array<int64_t,5> dx{},dy{},origin{};
 for(int a=0;a<5;++a) {
  int64_t d1=v[1].attribute[a]-v[0].attribute[a],d2=v[2].attribute[a]-v[0].attribute[a];
  // Integer division truncates gradients toward zero to twelve fractional bits.
  dx[a]=(d1*(v[2].y-v[0].y)-d2*(v[1].y-v[0].y))*4096/area;
  dy[a]=((v[1].x-v[0].x)*d2-(v[2].x-v[0].x)*d1)*4096/area;
  origin[a]=int64_t(start.attribute[a])*4096+2048-dx[a]*start.x-dy[a]*start.y;
 }
 low_x=std::max(0,low_x);high_x=std::min(width_-1,high_x);
 low_y=std::max(0,low_y);high_y=std::min(height_-1,high_y);
 const bool include[3]={inclusive(v[0],v[1]),inclusive(v[1],v[2]),inclusive(v[2],v[0])};
 for(int y=low_y;y<=high_y;++y) {
  int64_t e[3]={edge(v[0],v[1],low_x,y),edge(v[1],v[2],low_x,y),edge(v[2],v[0],low_x,y)};
  std::array<int64_t,5> value{};for(int a=0;a<5;++a)value[a]=origin[a]+dx[a]*low_x+dy[a]*y;
  for(int x=low_x;x<=high_x;++x) {
   if((e[0]>0||(e[0]==0&&include[0]))&&(e[1]>0||(e[1]==0&&include[1]))&&(e[2]>0||(e[2]==0&&include[2]))) {
    uint16_t texel=0x8000;
    if(textured) {
     unsigned u=unsigned(floor_q12(value[0]))&255,vv=unsigned(floor_q12(value[1]))&255;
     texel=palettes_[size_t(p[1])*16+indices_[vv*256+u]];
    }
    if(texel) {
     auto* out=&rgba_[(size_t(y)*width_+x)*4];
     const int adjustment=p[2]?dither[(y&3)*4+(x&3)]:0;
     for(int c=0;c<3;++c) {
      int color=int(unsigned(floor_q12(value[c+2]))&255);
      int foreground;
      if(textured) {
       int channel=(texel>>(c*5))&31;
       foreground=raw?channel:std::clamp(int(floor_q12(int64_t(((channel*color)>>4)+adjustment)*512)),0,31);
      } else foreground=std::clamp(int(floor_q12(int64_t(color+adjustment)*512)),0,31);
      out[c]=uint8_t(std::min(31,int(out[c])+foreground));
     }
     out[3]=255;
    }
   }
   e[0]-=v[1].y-v[0].y;e[1]-=v[2].y-v[1].y;e[2]-=v[0].y-v[2].y;
   for(int a=0;a<5;++a)value[a]+=dx[a];
  }
 }
}
}
