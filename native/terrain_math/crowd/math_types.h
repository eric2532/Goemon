#pragma once
#include <cmath>
namespace army {
struct Vec3 {float x=0,y=0,z=0;};
inline Vec3 operator+(Vec3 a,Vec3 b){return {a.x+b.x,a.y+b.y,a.z+b.z};}
inline Vec3 operator-(Vec3 a,Vec3 b){return {a.x-b.x,a.y-b.y,a.z-b.z};}
inline Vec3 operator*(Vec3 a,float s){return {a.x*s,a.y*s,a.z*s};}
inline float length(Vec3 p){return std::sqrt(p.x*p.x+p.y*p.y+p.z*p.z);}
inline float dot(Vec3 a,Vec3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
inline Vec3 cross(Vec3 a,Vec3 b){return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
inline Vec3 normalized(Vec3 p){float d=length(p);return d>1e-7f?p*(1/d):Vec3{};}
inline Vec3 rotated_y(Vec3 p,float yaw){float s=std::sin(yaw),c=std::cos(yaw);return {c*p.x+s*p.z,p.y,-s*p.x+c*p.z};}
inline bool finite(Vec3 p){return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z);}
}
