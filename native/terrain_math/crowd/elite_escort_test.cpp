#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={3000,4.2f,30,4,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};
 d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=15;d.slime_attacks[i+3]=135;}
 return d;
}
static Vec3 post(const Unit& leader,int slot){
 Vec3 forward{-std::sin(leader.yaw),0,-std::cos(leader.yaw)};
 return leader.position+Vec3{-forward.z,0,forward.x}*PARTY_FORMATION_POSTS[slot].x+forward*PARTY_FORMATION_POSTS[slot].z;
}
int main(){
 int checks=0;
 for(int hz:{20,30,60})for(bool wall:{false,true}){
  Crowd c;c.configure(64,64);NavigationData nav;
  if(wall){nav.obstacle_min={{-9,-1,-4}};nav.obstacle_max={{-5,10,-3}};}
  c.set_navigation(nav);assert(c.combat.configure(kits()));
  ExternalTarget hero;hero.kind=0;hero.hp=100000;c.combat.set_targets({});
  auto leader=c.spawn(1,0,SLIME_KIND,{0,0,0},9000,.8f);
  assert(c.set_body_scale(leader,2)&&c.set_enemy_scaling(leader,3,3));
  std::vector<Handle> escorts;
  for(int slot=0;slot<5;++slot){
   auto h=c.spawn(slot+2,0,SLIME_KIND,{float(slot*3-6),0,12},3000,.8f);c.set_guard(h,c.unit(h)->position,14);
   assert(c.set_enemy_escort(h,leader,slot));escorts.push_back(h);
  }
  assert(!c.set_enemy_escort(leader,leader,0)&&!c.set_enemy_escort(escorts[0],leader,5)&&!c.set_enemy_escort(escorts[0],escorts[1],0));++checks;
  const double dt=1.0/hz;
  auto step=[&](int ticks){for(int tick=0;tick<ticks;++tick){
   std::vector<Vec3> before;for(auto h:escorts)before.push_back(c.unit(h)->position);
   c.step(dt);for(int slot=0;slot<5;++slot){assert(length(c.unit(escorts[slot])->position-before[slot])<1);++checks;}
   c.combat.clear_events();
  }};
  step(hz*12);
  for(int slot=0;slot<5;++slot){auto u=c.unit(escorts[slot]);
   std::cout<<"ESCORT_POST hz="<<hz<<" wall="<<wall<<" slot="<<slot<<" gap="<<length(u->position-post(*c.unit(leader),slot))<<std::endl;
   assert(length(u->position-post(*c.unit(leader),slot))<(wall?3.5f:1.f));
   assert(c.terrain.clear(u->position,u->radius,std::max(0,u->support_layer)));++checks;
  }
  if(!wall){
   for(int tick=0;tick<hz*6;++tick){c.set_pose(leader,{12.f*(tick+1)/(hz*6),0,0},-float(M_PI/2));step(1);}
   step(hz*6);
   assert(c.unit(leader)->position.x>11);++checks;
   c.set_pose(leader,c.unit(leader)->position,float(M_PI/2));step(hz*12);
   for(int slot=0;slot<5;++slot){assert(length(c.unit(escorts[slot])->position-post(*c.unit(leader),slot))<1);++checks;}
   hero.foot=c.unit(leader)->position+Vec3{0,0,-4};c.combat.set_targets({hero});
   std::set<int64_t> attackers;
   for(int tick=0;tick<hz*12;++tick){c.step(dt);for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){attackers.insert(e.source_id);assert(e.amount==(e.source_id==1?90:30));}c.combat.clear_events();}
   assert(attackers.size()==6);++checks;
   c.combat.set_targets({});step(hz*14);
   for(auto h:escorts)assert(c.unit(h)->target_handle==0&&c.unit(h)->external_kind<0);
  }
  c.despawn(leader);auto replacement=c.spawn(99,0,SLIME_KIND,{0,0,0},3000,.8f);c.step(dt);
  for(auto h:escorts){assert(c.valid(h)&&c.unit(h)->escort_leader==0&&c.unit(h)->escort_slot==-1);++checks;}
  assert(!c.set_enemy_escort(escorts[0],leader,0)&&c.unit(replacement)->escort_leader==0);++checks;
 }
 std::cout<<"ELITE_ESCORT_RESULT checks="<<checks<<" failures=0\n";
}
