#include "core.h"
#include <cassert>
#include <iostream>
#include <limits>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={1000000,3,12,3,5,1.75};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1;d.bullet_radius=.5;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=36;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=18;d.slime_attacks[i+3]=135;}
 d.enemy_evasion.assign(ENEMY_KIND_COUNT,5);return d;
}
int main(){
 Crowd c;c.configure(8,8);auto data=kits();assert(c.combat.configure(data));
 auto h=c.spawn(1,0,SLIME_KIND,{},1000000,.5);auto u=c.unit(h);
 Hit hit;hit.amount=1;
 for(double accuracy:{-10.,0.,3.,5.,100.}){
  hit.accuracy=accuracy;
  for(int bag=0;bag<10;++bag){
   int misses=0;auto hp=u->hp;
   for(int i=0;i<100;++i)misses+=!c.combat.hit(c,h,hit).accepted;
   int expected=int(std::max(0.,5-accuracy));assert(misses==expected);assert(hp-u->hp==100-misses);
  }
 }
 hit.accuracy=-100;assert(!c.combat.hit(c,h,hit).accepted);
 hit.magical=true;assert(c.combat.hit(c,h,hit).accepted);hit.magical=false;
 int draw=u->evasion_draw;Hit status;status.effect=4;status.status_seconds=1;
 assert(c.combat.hit(c,h,status).accepted&&u->evasion_draw==draw);
 hit.accuracy=std::numeric_limits<double>::quiet_NaN();assert(!c.combat.hit(c,h,hit).accepted&&u->evasion_draw==draw);
 hit.accuracy=100;assert(c.set_boss_reactions(h,1,0));u->stun=0;
 for(int i=0;i<100;++i)assert(c.combat.hit(c,h,hit).accepted);
 u->stun=0;u->action_active=false;u->blocking=false;u->dodge_cooldown=0;
 hit.magical=true;assert(!c.combat.hit(c,h,hit).accepted);hit.magical=false;u->dodge_left=u->dodge_cooldown=0;
 auto ally=c.spawn(-1,1,HOUND_KIND,{},1000,.5);hit.accuracy=-10;
 assert(c.combat.hit(c,ally,hit).accepted); // Enemy-only general dodge does not alter allied defense.
 assert(c.set_boss_reactions(h,0,0));hit.accuracy=0;hit.source_id=-100;
 int misses=0;for(int i=0;i<100;++i)misses+=!c.combat.hit(c,h,hit).accepted;
 assert(misses==5); // Native companion attacks share the same target-owned bag.
 c.despawn(h);auto reused=c.spawn(2,0,SLIME_KIND,{},1000,.5);
 assert(c.unit(reused)->evasion_draw==100&&c.unit(reused)->dodge_chance==0);
 data.enemy_evasion[0]=101;assert(!valid_kit_data(data));
 data=kits();data.enemy_evasion.resize(1);assert(!valid_kit_data(data));
 std::cout<<"ACCURACY_RESULT bags=51 baseline=95 axe=85 accuracy_3=98 accuracy_5=100 magic_status_reactions_reuse=passed\n";
}
