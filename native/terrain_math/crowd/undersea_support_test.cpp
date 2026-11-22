#include "core.h"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace army;

static KitData kits(){
 KitData d;d.undersea_boss=true;d.soldier_kinds={SLIME_KIND};
 d.soldier_profiles={2000,3.85f,12,3.25f,5,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){
  d.slime_attacks[i]=36;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=18;d.slime_attacks[i+3]=135;
 }
 return d;
}
static void steps(Crowd& crowd,int ticks){for(int i=0;i<ticks;++i)crowd.step(1.0/60);}
int main(){
 Crowd c;c.configure(20,20);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto h=c.spawn(1,0,SLIME_KIND,{0,0,0},2000,1.12f);auto u=c.unit(h);
 u->buff_left=5;int misses=0;
 for(int i=0;i<10000;++i){Hit hit;hit.amount=.01;auto result=c.combat.hit(c,h,hit);if(!result.accepted)++misses;}
 assert(misses>4700&&misses<5300);
 assert(std::abs(u->hp-(2000-(10000-misses)*.01))<1e-6);
 for(int i=0;i<100;++i){Hit hit;hit.amount=.01;hit.magical=true;assert(c.combat.hit(c,h,hit).accepted);}
 auto escort=c.spawn(2,0,SLIME_KIND,{10,0,0},2000,1);c.unit(escort)->pose_row=1;c.unit(escort)->buff_left=5;
 for(int i=0;i<100;++i){Hit hit;hit.amount=.01;assert(c.combat.hit(c,escort,hit).accepted);}
 u=c.unit(h);
 steps(c,301);assert(u->buff_left==0&&!(u->status&8));
 for(int i=0;i<100;++i){Hit hit;hit.amount=.01;assert(c.combat.hit(c,h,hit).accepted);}
 u->hp=1000;u->action=UNDERSEA_MEDITATION;u->action_time=0;u->action_active=true;u->stun=0;u->frozen=2;
 steps(c,60);assert(u->hp==1000&&u->action_time==0);
 steps(c,150);assert(u->hp==1500);
 u->hp=1000;u->action=UNDERSEA_MEDITATION;u->action_time=0;u->action_active=true;u->buff_left=5;
 Hit interrupt;interrupt.amount=100;assert(c.combat.hit(c,h,interrupt).accepted);
 steps(c,120);assert(u->hp==900);
 u->buff_left=0;
 u->hp=1990;u->action=UNDERSEA_MEDITATION;u->action_time=0;u->action_active=true;
 steps(c,80);assert(u->hp==2000);
 u->hp=1000;u->action=UNDERSEA_MEDITATION;u->action_time=0;u->action_active=true;c.combat.clear_events();
 Hit lethal;lethal.amount=10000;lethal.magical=true;assert(c.combat.hit(c,h,lethal).dead);
 steps(c,120);assert(!c.valid(h));
 for(const auto& event:c.combat.events())assert(event.source_id!=1||event.action_index!=ZOMBIE_HEAL);
 auto fresh=c.spawn(3,0,SLIME_KIND,{0,0,0},2000,1.12f);
 assert(c.unit(fresh)->buff_left==0&&c.unit(fresh)->utility_left==0&&c.unit(fresh)->utility_wait==0);
 auto off=kits();off.undersea_boss=false;assert(c.combat.configure(off));c.unit(fresh)->buff_left=5;
 for(int i=0;i<100;++i){Hit hit;hit.amount=.01;assert(c.combat.hit(c,fresh,hit).accepted);}
 std::cout<<"UNDERSEA_SUPPORT_RESULT trials=10000 dodges="<<misses<<" failures=0\n";
}
