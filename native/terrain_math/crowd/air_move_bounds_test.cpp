#include "air_move_reference.h"
#include <cassert>
#include <cstring>
#include <iostream>
using namespace army;
int main(){
 NavigationData data;data.width=33;data.spacing=3;data.origin={-48,0,-48};data.covered.assign(33*33,1);
 for(int z=0;z<33;++z)for(int x=0;x<33;++x)data.heights.push_back(x<12?float(x-12)*.15f:0);
 std::vector<Vec3> faces;
 for(int z=0;z<32;++z)for(int x=0;x<32;++x){int i=z*33+x;Vec3 a{-48+x*3.0f,data.heights[i],-48+z*3.0f},b{a.x+3,data.heights[i+1],a.z},c{a.x,data.heights[i+33],a.z+3},d{b.x,data.heights[i+34],c.z};faces.insert(faces.end(),{a,c,b,b,c,d});}
 data.layer_min={{-12,8,-8}};data.layer_max={{12,8,8}};faces.insert(faces.end(),{{-12,8,-8},{-12,8,8},{12,8,8},{-12,8,-8},{12,8,8},{12,8,-8}});
 data.air_faces={{0,0,-12},{0,10,-12},{0,10,12},{0,0,-12},{0,10,12},{0,0,12},{0,0,12},{0,10,12},{12,10,12},{0,0,12},{12,10,12},{12,0,12}};faces.insert(faces.end(),data.air_faces.begin(),data.air_faces.end());
 Terrain terrain;terrain.configure(data);terrain.air_profile.enabled=true;int checks=0;
 auto same=[&](Vec3 from,Vec3 motion,float radius=.4f,float height=1.8f,float center=.9f){auto a=terrain.air_move(from,motion,radius,height,center),b=reference_move::move(faces,from,motion,radius,height,center);if(std::memcmp(&a.position,&b.position,sizeof(Vec3))||std::memcmp(&a.normal,&b.normal,sizeof(Vec3))||a.floor!=b.floor){std::cerr<<"air move mismatch from="<<from.x<<","<<from.y<<","<<from.z<<" motion="<<motion.x<<","<<motion.y<<","<<motion.z<<" actual="<<a.position.x<<","<<a.position.y<<","<<a.position.z<<" reference="<<b.position.x<<","<<b.position.y<<","<<b.position.z<<"\n";std::abort();}++checks;};
 uint32_t rng=71122;auto random=[&](){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return float(rng%100001)/100000;};
 for(int i=0;i<1000;++i)same({-40+80*random(),-1+15*random(),-30+60*random()},{-3+6*random(),-3+6*random(),-3+6*random()},.3f+random()*.4f,2.0f,1.0f);
 for(float x:{-.399f,-.01f,0.0f,.01f,.399f})for(float y:{-.02f,.0f,.02f,7.99f,8.0f,8.01f,9.9f})for(Vec3 v:std::vector<Vec3>{{0,-2,0},{1,0,2},{-1,2,-2}})same({x,y,0},v);
 terrain.air_profile.capsule_tests=0;same({-20,20,-20},{1,-.5f,1});
 assert(terrain.air_profile.capsule_tests<8);++checks;
 std::cout<<"ARMY_AIR_MOVE_BOUNDS_RESULT checks="<<checks<<" narrow_tests="<<terrain.air_profile.capsule_tests<<" failures=0\n";
}
