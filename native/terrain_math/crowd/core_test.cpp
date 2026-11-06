#include "core.h"
#include <cassert>
#include <iostream>
#include <limits>
int main() {
    army::Crowd crowd;
    crowd.configure(4000,2000);
    auto first=crowd.spawn(1,0,0,{0,0,0},100,.5);
    assert(first && crowd.valid(first));
    auto published=crowd.snapshot();
    crowd.despawn(first);
    auto next=crowd.spawn(2,0,0,{1,0,0},100,.5);
    assert(next && next!=first && !crowd.valid(first));
    assert(published.size()==1 && published[0].logical_id==1);
    assert(crowd.spawn(2,1,11,{0,0,0},100,.5)==0);
    assert(crowd.spawn(3,0,0,{NAN,0,0},100,.5)==0);
    army::Generation generation{0x7fffffff};
    assert(generation.take()==0x7fffffff && generation.take()==0);
    crowd.configure(4000,2000);
    assert(!crowd.valid(next));
    auto fresh=crowd.spawn(1,0,0,{0,0,0},100,.5);
    assert(fresh!=first && fresh!=next);
    for(int i=1;i<2000;++i)assert(crowd.spawn(i+1,0,0,{float(i),0,0},100,.5));
    assert(!crowd.spawn(5000,0,0,{0,0,0},100,.5));
    assert(crowd.spawn(-1,1,11,{0,0,0},100,.5));
    assert(crowd.query({-.1f,-.1f,-.1f},{.1f,.1f,.1f},0).size()==1);
    // A horizontal approach on a hill must still route around an intervening wall.
    army::NavigationData nav;nav.origin={-60,0,-60};nav.width=41;nav.spacing=3;
    nav.heights.resize(41*41);nav.covered.assign(41*41,1);
    for(int z=0;z<41;++z)for(int x=0;x<41;++x)nav.heights[z*41+x]=x*.5f;
    nav.obstacle_min={{-3,0,-12}};nav.obstacle_max={{3,30,12}};
    for(int hz:{20,30,60}){
        crowd.clear();crowd.set_navigation(nav);
        auto guard=crowd.spawn(-1,1,11,{-30,5,0},200,.4);crowd.set_guard(guard,{-30,5,0},18);
        crowd.set_goal(guard,{30,5,0},6);assert(crowd.unit(guard)->goal.y==15);
        for(int tick=0;tick<hz*30;++tick)crowd.step(1.0/hz);
        assert(army::length(crowd.unit(guard)->position-army::Vec3{30,15,0})<.1f);
    }
    std::cout<<"ARMY_CORE_RESULT failures=0\n";
}
