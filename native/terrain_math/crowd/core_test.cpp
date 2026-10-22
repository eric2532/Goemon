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
    std::cout<<"ARMY_CORE_RESULT failures=0\n";
}
