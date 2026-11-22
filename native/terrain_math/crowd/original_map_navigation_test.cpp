#include "terrain.h"
#include <cassert>
#include <iostream>
#include <limits>
using namespace army;
int main(){
    NavigationData d;d.origin={0,0,0};d.width=17;d.spacing=3.9f;
    d.heights.assign(17*17,0);d.covered.assign(17*17,1);
    d.obstacle_min={{0,0,0},{5.85f,0,0},{33.15f,0,0},{0,0,37.05f}};
    d.obstacle_max={{1.95f,10,62.4f},{29.25f,10,33.15f},{62.4f,10,62.4f},{62.4f,10,62.4f}};
    Terrain terrain;terrain.navigation_profile.enabled=true;terrain.configure(d);
    assert(!terrain.reachable({3.9f,0,3.9f},{31.2f,0,15.6f},.5f,0));
    d.route_spacing=3.9f;terrain.configure(d);
    assert(terrain.reachable({3.9f,0,3.9f},{31.2f,0,15.6f},.5f,0));
    assert(terrain.navigation_profile.topology_builds==2);
    d.width=401;d.obstacle_min.clear();d.obstacle_max.clear();
    d.heights.assign(401*401,0);d.covered.assign(401*401,1);terrain.configure(d);
    assert(terrain.reachable({1000,0,20},{1400,0,20},.5f,0));
    d.route_spacing=std::numeric_limits<float>::quiet_NaN();terrain.configure(d);
    assert(!terrain.reachable({1000,0,20},{1400,0,20},.5f,0));
    std::cout<<"PASS: original narrow passages, spacing cache invalidation, full recovered bounds and invalid spacing\n";
}
