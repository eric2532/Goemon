#include "terrain.h"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
using namespace army;
// Source porch deck pixels are preserved. Only inferred height/tread depth vary.
struct P {float x,z;};
P source(float px,float py,float height){float u=(px-45)/(32.f/3),v=(py-140+height/.045f)/8;return {(u-v)*.5f,(u+v)*.5f};}
bool polygon(P p,const P* a){bool inside=false;for(int i=0,j=3;i<4;j=i++){if((a[i].z>p.z)!=(a[j].z>p.z)&&p.x<(a[j].x-a[i].x)*(p.z-a[i].z)/(a[j].z-a[i].z)+a[i].x)inside=!inside;}return inside;}
float support(float x,float z,float height,float depth){
    P deck[]{source(5,104,height),source(50,130,height),source(89,103,height),source(49,75,height)};
    // Both native return paths have this central source cell blocked.
    if(int(std::floor(x/3+.5f))==0&&int(std::floor(z/3+.5f))==0)return 0;
    float lo=std::min(deck[1].x,deck[2].x),hi=std::max(deck[1].x,deck[2].x);
    float rear=std::min(deck[1].z,deck[2].z),nose=std::max(deck[1].z,deck[2].z)+depth,foot=nose+4*depth;
    if(polygon({x,z},deck)||(x>=lo&&x<=hi&&z>=rear&&z<=nose))return height;
    if(x>=lo&&x<=hi&&z>=nose&&z<=foot)return height*(foot-z)/(foot-nose);
    return 0;
}
int main(){
    int checks=0,failed=0;
    std::cout<<std::fixed<<std::setprecision(6);
    for(auto option:{P{1.8f,.42f},P{1.2f,.60f},P{1.1f,.60f},P{1.2f,.65f}})for(float scale:{1.f,1.3f}){
        NavigationData d;d.width=17;d.spacing=1.5f*scale;d.route_spacing=3*scale;
        d.origin={-9*scale,0,-9*scale};d.bounds_min=d.origin;d.bounds_max={15*scale,0,15*scale};
        d.heights.assign(d.width*d.width,0);d.covered.assign(d.heights.size(),1);
        for(int z=0;z<d.width;++z)for(int x=0;x<d.width;++x)d.heights[z*d.width+x]=support(-9+x*1.5f,-9+z*1.5f,option.x,option.z)*scale;
        Terrain terrain;terrain.configure(d);Vec3 returned{0,float(terrain.height(0,3*scale)),3*scale},ground{0,0,6*scale};
        // Door-leaf bottom is measured independently at fixed z=-2.28.
        float door_bottom=((-2.28f-((12-45)/(32.f/3)+2.28f))*8-101+140)*.045f;
        for(float radius:{.25f,.35f,.60f}){
            bool descent=true;for(float z=3;z<=6;z+=.05f)descent=descent&&terrain.clear({0,0,z*scale},radius,0);
            bool up=terrain.reachable(ground,returned,radius,0),down=terrain.reachable(returned,ground,radius,0);
            bool segment=terrain.segment(returned,ground,radius,0);
            if(option.x==1.2f&&option.z==.60f){checks+=5;failed+=!terrain.clear(returned,radius,0)+!descent+!up+!down+!segment;}
            std::cout<<"deck="<<option.x<<" tread="<<option.z<<" scale="<<scale<<" radius="<<radius<<" leaf_bottom="<<door_bottom<<" return_height="<<returned.y<<" return_clear="<<terrain.clear(returned,radius,0)<<" descent_clear="<<descent<<" up="<<up<<" down="<<down<<" direct_down="<<segment<<'\n';
        }
    }
    std::cout<<"EAST_LEKTAL_NATIVE_NAV_RESULT checks="<<checks<<" failures="<<failed<<'\n';
    return failed?1:0;
}
