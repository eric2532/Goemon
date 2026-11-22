#include "core.h"
#include <algorithm>
#include <cassert>
#include <chrono>
#include <iostream>
#include <set>
#include <string>
using namespace army;
static KitData kits(){
    KitData d;d.soldier_kinds={0,1,3};
    d.soldier_profiles={192,4.32f,11,2.5f,5,2.304f,240,2.16f,25,24,4,1.44f,216,4.32f,11,2.5f,7,2.304f};
    d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
    d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};
    d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};
    d.bullet_speed=8.64f;d.bullet_life=3.34f;d.bullet_tail=.576f;d.bullet_radius=.576f;return d;
}
static NavigationData ground(){
    NavigationData d;d.origin={-240,0,-240};
    d.obstacle_min={{-6,0,-3},{-90,0,-3},{6,0,-3}};
    d.obstacle_max={{6,10,3},{-6,10,3},{90,10,3}};
    d.ray_min=d.obstacle_min;d.ray_max=d.obstacle_max;d.ray_owner={99,100,101};return d;
}
static ExternalTarget gate(){ExternalTarget t;t.id=99;t.kind=2;t.hp=1e9;t.minimum={-6,0,-3};t.maximum={6,10,3};t.foot={0,0,0};return t;}
static void setup(Crowd& c){c.configure(4000,2000);c.set_navigation(ground());assert(c.combat.configure(kits()));c.combat.set_targets({gate()});}
static void ticks(Crowd& c,int count){for(int i=0;i<count;++i){c.step(1.0/60);c.combat.clear_events();}}
static std::set<int64_t> attackers(Crowd& c,int count,int64_t target=99){
    std::set<int64_t> hits;
    for(int i=0;i<count;++i){
        c.step(1.0/60);
        for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.target_id==target)hits.insert(e.source_id);
        c.combat.clear_events();
        for(const auto& u:c.snapshot())assert(c.terrain.clear(u.position,u.radius,0));
    }
    return hits;
}
int main(int argc,char** argv){
    if(argc>1&&std::string(argv[1])=="--benchmark"){
        for(int count:{240,2000}){
            Crowd c;setup(c);
            for(int i=0;i<count;++i)c.spawn(i+1,0,i%3==1?1:0,{float(i%50)*2.9f-72,0,12+float(i/50)*4},192,1.3);
            // Stationary allies exercise the normal two-team movement worker.
            for(int i=0;i<count;++i)c.spawn(-i-1,1,12,{float(i%50)*2-50,0,-160-float(i/50)},500,.4);
            ticks(c,60);c.timing={};c.timing.enabled=true;c.terrain.navigation_profile.enabled=true;
            std::vector<double> frames;auto start=std::chrono::steady_clock::now();
            for(int i=0;i<600;++i){auto frame=std::chrono::steady_clock::now();ticks(c,1);frames.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-frame).count());}
            double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count()/600;
            std::sort(frames.begin(),frames.end());
            std::cout<<"FORMATION_BENCHMARK enemies="<<count<<" allies="<<count<<" wall_ms="<<ms<<" p95_ms="<<frames[570]<<" max_ms="<<frames.back()<<" movement_ms="<<c.timing.movement/600<<" decisions_ms="<<c.timing.decisions/600<<" flow_builds="<<c.terrain.navigation_profile.flow_builds<<"\n";
        }
        return 0;
    }
    Crowd c;setup(c);std::vector<Handle> army;
    for(int i=0;i<28;++i)army.push_back(c.spawn(i+1,0,0,{0,0,60+float(i)*3},192,1.3));
    ticks(c,360);float low=0,high=0;
    for(auto h:army){low=std::min(low,c.unit(h)->position.x);high=std::max(high,c.unit(h)->position.x);}
    std::cout<<"APPROACH_WIDTH "<<high-low<<std::endl;
    assert(high-low>1.3f && "Stable approach lanes must spread by more than one body radius");
    auto hits=attackers(c,4200);
    std::cout<<"MELEE_ATTACKERS "<<hits.size()<<"/"<<army.size()<<std::endl;
    assert(hits.size()==army.size() && "Every melee troop must advance and damage the gate without waiting for front-row casualties");
    // A nearby player draws the assault, and disappearing targets release it.
    ExternalTarget hero;hero.id=0;hero.kind=0;hero.hp=10000;hero.foot={0,0,12};c.combat.set_targets({gate(),hero});
    hits=attackers(c,1800,0);assert(hits.size()==army.size());
    hero.targetable=false;c.combat.set_targets({gate(),hero});assert(attackers(c,1800).size()==army.size());
    // A breached/disappearing gate releases the assault and retains safe routing.
    auto nav=ground();nav.obstacle_min.erase(nav.obstacle_min.begin());nav.obstacle_max.erase(nav.obstacle_max.begin());nav.ray_min.clear();nav.ray_max.clear();nav.ray_owner.clear();c.set_navigation(nav);
    hero.targetable=true;hero.foot={0,0,-25};c.combat.set_targets({hero});ticks(c,1800);
    bool crossed=false;
    for(const auto& u:c.snapshot())if(u.position.z<0)crossed=true;
    assert(crossed);
    setup(c);c.set_navigation({});hero.foot={0,0,0};c.combat.set_targets({hero});
    auto clear_runner=c.spawn(1,0,0,{8,0,8},192,1.3f);
    c.spawn(2,0,0,{0,0,8},192,1.3f);
    auto blocked_runner=c.spawn(3,0,0,{0,0,8.9f},192,1.3f);
    ticks(c,1);
    const auto clear_speed=length(c.unit(clear_runner)->velocity);
    const auto lateral_speed=std::abs(c.unit(blocked_runner)->velocity.x);
    std::cout<<"SIDESTEP clear_speed="<<clear_speed<<" crowded_lateral_speed="<<lateral_speed<<std::endl;
    assert(std::abs(clear_speed-4.32f)<.001f);
    assert(lateral_speed>clear_speed && "Only the crowded runner should get a quick lateral step");
    // A crowded charge should spread around a player and still land real hits.
    setup(c);c.set_navigation({});hero.foot={0,0,0};c.combat.set_targets({hero});
    for(int i=0;i<20;++i)c.spawn(i+1,0,0,{0,0,6+i*.9f},192,1.3f);
    hits=attackers(c,1200,0);
    const auto settled=c.snapshot();
    int overlaps=0;
    for(size_t i=0;i<settled.size();++i)for(size_t j=0;j<i;++j)
        if(length(settled[i].position-settled[j].position)<1.3f)++overlaps;
    std::cout<<"PLAYER_CHARGE attackers="<<hits.size()<<" deep_overlaps="<<overlaps<<std::endl;
    assert(hits.size()==20);
    assert(overlaps<=95 && "A crowded charge must avoid at least half the possible deep overlaps");
    // Both lane shoulders must yield at a narrow corridor, without new flows.
    Terrain t;NavigationData narrow;narrow.origin={-30,0,-30};narrow.obstacle_min={{-30,0,-25},{2,0,-25}};narrow.obstacle_max={{-2,10,25},{30,10,25}};t.configure(narrow);
    int layer=0;bool routing=false;
    Vec3 safe=t.move({0,0,20},{0,0,-20},4,1.f/60,1.3f,layer,routing,{},0,{60,0,0});
    assert(safe.x==0&&safe.z<20&&t.clear(safe,1.3f,layer));
    for(float lane:{-3.0f,3.0f}){Vec3 p{0,0,20};int layer=0;bool routing=false;
        for(int i=0;i<1200;++i){p=t.move(p,{0,0,-20},4,1.0f/60,1.3f,layer,routing,{},lane);assert(t.clear(p,1.3f,layer));}
        assert(p.z<-19 && "Lane preference must not jam a narrow passage");
    }
    // Every gunner with a clear shot may fire, including those behind melee.
    setup(c);for(int i=0;i<12;++i)c.spawn(i+1,0,1,{0,0,30+float(i)*3},240,1.3);
    hits=attackers(c,3000);std::cout<<"RANGED_ATTACKERS "<<hits.size()<<"/12"<<std::endl;assert(hits.size()==12);
    setup(c);
    for(int i=0;i<32;++i)c.spawn(i+1,0,i<24?0:1,{0,0,25+float(i)*2},240,1.3);
    hits=attackers(c,3600);std::cout<<"MIXED_ATTACKERS "<<hits.size()<<"/32"<<std::endl;assert(hits.size()==32);
    // All four approaches retain real contacts, without formation slots.
    for(int side=0;side<4;++side){
        setup(c);auto d=ground();d.obstacle_min.resize(1);d.obstacle_max.resize(1);d.ray_min.resize(1);d.ray_max.resize(1);d.ray_owner.resize(1);c.set_navigation(d);
        for(int i=0;i<8;++i){float distance=20+float(i)*3;Vec3 p=side<2?Vec3{side==0?-distance:distance,0,0}:Vec3{0,0,side==2?-distance:distance};c.spawn(i+1,0,0,p,192,1.3);}
        assert(attackers(c,2400).size()==8);
    }
    // A local tower can replace the shrine while the route first moves away from its cliff.
    for(int half_width:{12,21}){
        NavigationData d;d.origin={-180,0,-180};d.width=121;d.spacing=3;
        d.heights.assign(121*121,0);d.covered.assign(121*121,1);
        for(int z=0;z<121;++z)for(int x=0;x<121;++x){
            float px=x*3-180,pz=z*3-180;
            if(std::abs(px)<=54&&std::abs(pz)<=54)d.heights[z*121+x]=32;
            else if(px>54&&std::abs(pz+3)<=half_width)d.heights[z*121+x]=32*std::clamp((150-px)/96,0.0f,1.0f);
        }
        ExternalTarget tower;tower.id=24;tower.kind=2;tower.hp=1e9;tower.minimum={27,32,15};tower.maximum={39,42,27};tower.foot={33,32,21};tower.assault_priority=4;
        ExternalTarget shrine;shrine.id=1;shrine.kind=2;shrine.hp=1e9;shrine.minimum={-9,32,-9};shrine.maximum={9,48,9};shrine.foot={0,32,0};shrine.assault_priority=2;
        d.obstacle_min={tower.minimum,shrine.minimum};d.obstacle_max={tower.maximum,shrine.maximum};
        d.ray_min=d.obstacle_min;d.ray_max=d.obstacle_max;d.ray_owner={24,1};
        c.configure(128,2000);c.set_navigation(d);auto data=kits();data.soldier_profiles[1]=5.2f;
        assert(c.combat.configure(data));c.combat.set_targets({tower,shrine});
        c.spawn(78,0,0,{120,0,78},192,1.3f);c.spawn(79,0,0,{102,0,84},192,1.3f);
        assert(attackers(c,12000,24).size()==2 && "Retargeting must not trap troops against a raised castle's side");
    }
    std::cout<<"ARMY_FORMATION_RESULT failures=0\n";
}
