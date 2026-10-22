#pragma once
// Frozen capsule calculations and source coarse-grid recovery/sweep from 0ff91681.
// Deliberately independent of optimized terrain bounds and candidate filters.
#include "terrain.h"
#include <algorithm>
namespace reference_move {
using namespace army;
Vec3 closest(Vec3 p,Vec3 a,Vec3 b,Vec3 c){
    Vec3 ab=b-a,ac=c-a,ap=p-a;float d1=dot(ab,ap),d2=dot(ac,ap);
    if(d1<=0&&d2<=0)return a;
    Vec3 bp=p-b;float d3=dot(ab,bp),d4=dot(ac,bp);if(d3>=0&&d4<=d3)return b;
    float vc=d1*d4-d3*d2;if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
    Vec3 cp=p-c;float d5=dot(ab,cp),d6=dot(ac,cp);if(d6>=0&&d5<=d6)return c;
    float vb=d5*d2-d1*d6;if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
    float va=d3*d6-d5*d4;if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/(d4-d3+d5-d6));
    float inv=1/(va+vb+vc);return a+ab*(vb*inv)+ac*(vc*inv);
}
bool triangle_ray(Vec3 from,Vec3 motion,Vec3 a,Vec3 b,Vec3 c,float& t){
    Vec3 ab=b-a,ac=c-a,h=cross(motion,ac);float det=dot(ab,h);if(std::abs(det)<1e-8f)return false;
    float inv=1/det;Vec3 s=from-a;float u=dot(s,h)*inv;if(u<-.00001f||u>1.00001f)return false;
    Vec3 q=cross(s,ab);float v=dot(motion,q)*inv;if(v<-.00001f||u+v>1.00001f)return false;
    t=dot(ac,q)*inv;return t>=0&&t<=1;
}
void segment_pair(Vec3 a,Vec3 b,Vec3 c,Vec3 d,Vec3& p,Vec3& q){
    Vec3 u=b-a,v=d-c,w=a-c;float aa=dot(u,u),bb=dot(u,v),cc=dot(v,v),dd=dot(u,w),ee=dot(v,w),denom=aa*cc-bb*bb;
    float s=denom>1e-8f?std::clamp((bb*ee-cc*dd)/denom,0.0f,1.0f):0;
    float t=cc>1e-8f?std::clamp((bb*s+ee)/cc,0.0f,1.0f):0;
    if(aa>1e-8f)s=std::clamp((bb*t-dd)/aa,0.0f,1.0f);
    if(cc>1e-8f)t=std::clamp((bb*s+ee)/cc,0.0f,1.0f);
    p=a+u*s;q=c+v*t;
}
float capsule_triangle(Vec3 lower,Vec3 upper,Vec3 a,Vec3 b,Vec3 c,Vec3& normal){
    float t;if(triangle_ray(lower,upper-lower,a,b,c,t)){normal=normalized(cross(b-a,c-a));if(normal.y<0)normal=normal*-1;return 0;}
    Vec3 p=lower,q=closest(lower,a,b,c);float best=length(p-q);
    auto consider=[&](Vec3 x,Vec3 y){float gap=length(x-y);if(gap<best){best=gap;p=x;q=y;}};
    consider(upper,closest(upper,a,b,c));Vec3 x,y;
    segment_pair(lower,upper,a,b,x,y);consider(x,y);segment_pair(lower,upper,b,c,x,y);consider(x,y);segment_pair(lower,upper,c,a,x,y);consider(x,y);
    normal=best>1e-7f?(p-q)*(1/best):normalized(cross(b-a,c-a));return best;
}
AirMove move(const std::vector<Vec3>& faces,Vec3 from,Vec3 motion,float radius,float body_height,float center){
    AirMove result;result.position=from;
    const float skin=.001f,reach=radius+skin,stem=body_height*.5f-radius;
    Vec3 end=from+motion,pad{reach,reach,reach};Vec3 low{std::min(from.x,end.x),std::min(from.y,end.y),std::min(from.z,end.z)},high{std::max(from.x,end.x),std::max(from.y,end.y)+body_height,std::max(from.z,end.z)};
    std::vector<int> candidates;auto lo=low-pad,hi=high+pad;
    for(int i=0;i<int(faces.size());i+=3){auto a=faces[i],b=faces[i+1],c=faces[i+2];
        if(std::floor(std::min({a.x,b.x,c.x})/12)>std::floor(hi.x/12)||std::floor(std::max({a.x,b.x,c.x})/12)<std::floor(lo.x/12)||std::floor(std::min({a.z,b.z,c.z})/12)>std::floor(hi.z/12)||std::floor(std::max({a.z,b.z,c.z})/12)<std::floor(lo.z/12))continue;
        candidates.push_back(i);
    }
    // CharacterBody recovers a shallow initial overlap before its body sweep.
    for(int pass=0;pass<4;++pass){bool recovered=false;
        for(int i:candidates){Vec3 normal,at=result.position;float distance=capsule_triangle(at+Vec3{0,center-stem,0},at+Vec3{0,center+stem,0},faces[i],faces[i+1],faces[i+2],normal);
            if(distance<reach-.000005f){result.position=result.position+normal*(reach-distance);recovered=true;}}
        if(!recovered)break;
    }
    for(int slide=0;slide<5&&length(motion)>1e-7f;++slide){
        float earliest=1;Vec3 contact{};bool found=false;
        for(int i:candidates){
            Vec3 a=faces[i],b=faces[i+1],c=faces[i+2];float t=0;
            for(int iteration=0;iteration<48;++iteration){
                Vec3 at=result.position+motion*t,normal;float distance=capsule_triangle(at+Vec3{0,center-stem,0},at+Vec3{0,center+stem,0},a,b,c,normal);
                if(distance<=reach+.000005f){
                    if(dot(motion,normal)<-1e-7f&&t<=earliest){earliest=t;contact=normal;found=true;}break;
                }
                // Convex distance's supporting tangent bounds the next contact.
                // Using total speed converges too slowly for a shallow descent
                // and can exhaust the iteration budget before meeting a floor.
                float closing=-dot(motion,normal);if(closing<=1e-8f)break;
                float advance=(distance-reach)/closing;t+=std::max(advance,1e-7f);if(t>earliest||t>1)break;
            }
        }
        result.position=result.position+motion*earliest;
        if(!found)break;
        result.normal=contact;if(contact.y>=std::cos(48.0*M_PI/180)&&motion.y<0)result.floor=true;
        motion=motion*(1-earliest);motion=motion-contact*std::min(0.0f,dot(motion,contact));
    }
    return result;
}
}
