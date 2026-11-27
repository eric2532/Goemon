#include "core.h"
#include <cassert>
#include <iostream>
using namespace army;
int main(){
 KitData d;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={2000,3.85f,12,3.25f,5,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){
  d.slime_attacks[i]=36;d.slime_attacks[i+1]=2;
  d.slime_attacks[i+2]=8;d.slime_attacks[i+3]=20207;
  d.slime_attacks[i+4]=18;d.slime_attacks[i+5]=10162;
 }
 Crowd c;c.configure(20,20);c.set_navigation(NavigationData{});assert(c.combat.configure(d));
 auto h=c.spawn(1,0,SLIME_KIND,{0,0,0},2000,.5f);c.unit(h)->yaw=0;
 ExternalTarget hero;hero.kind=0;hero.id=7;hero.hp=10000;hero.foot={0,0,-2};c.combat.set_targets({hero});
 bool hit=false,sound=false;
 for(int i=0;i<180;++i){
  c.step(1.0/60);
  for(const auto& event:c.combat.events()){
   if(event.kind==EXTERNAL_DAMAGE)hit=true;
   if(event.kind==STATUS_EVENT&&event.action_index==HOUND_CUE_BASE+207)sound=true;
  }
 }
 assert(hit&&sound);assert(!companion_contact_cue(20207)&&companion_contact_cue(10162));
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){
  d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=18;d.slime_attacks[i+3]=135;
 }
 Crowd legacy;legacy.configure(20,20);legacy.set_navigation(NavigationData{});assert(legacy.combat.configure(d));
 h=legacy.spawn(1,0,SLIME_KIND,{0,0,0},2000,.5f);legacy.unit(h)->yaw=0;legacy.combat.set_targets({hero});hit=false;
 for(int i=0;i<180;++i){legacy.step(1.0/60);for(const auto& event:legacy.combat.events())if(event.kind==EXTERNAL_DAMAGE)hit=true;}
 assert(hit);
 for(int cue:{111,141,158,302}){
  for(int tag:{10000,20000}){auto source=d;source.slime_attacks[3]=tag+cue;assert(valid_kit_data(source));}
  auto source=d;source.slime_attacks[3]=cue;assert(!valid_kit_data(source));
 }
 d.slime_attacks[3]=29999;assert(!c.combat.configure(d));
 std::cout<<"TINA_CUES_RESULT source contact/audio, damage and invalid-cue rejection passed\n";
}
