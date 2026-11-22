#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={HOUND_KIND,BEAR_KIND};
 d.soldier_profiles={3000,4.5,60,3.4,6,1.75,30000,12,3000,3.4,6,1.75};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1;d.bullet_radius=.5;
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.hound_attacks[i]=30;d.hound_attacks[i+1]=1;d.hound_attacks[i+2]=15;d.hound_attacks[i+3]=131;}
 d.bear_attacks.assign(d.hound_attacks.begin(),d.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE)d.bear_attacks[i+3]=135;
 return d;
}
int main(){
 int checks=0;
 for(int kind:{HOUND_KIND,BEAR_KIND})for(int hz:{20,30,60}){
  Crowd c;c.configure(64,64);c.set_navigation({});assert(c.combat.configure(kits()));
  auto pet=c.spawn(-1,1,kind,{0,0,0},30000,.6f);
  auto foe=c.spawn(100,0,SLIME_KIND,{0,0,-2},1000000,.5f);
  c.set_guard(pet,{0,0,0},18);ExternalTarget hero;hero.hp=10000;
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,foe);c.step(1.0/hz);
  auto* u=c.unit(pet);u->target_handle=foe;u->action_active=true;u->pet_skill=0;u->pet_rush_left=5.0/32;
  u->just_started=false;u->phase_tick=u->attack_tick=14.8;
  c.unit(foe)->position={0,0,-6};float before=u->position.z;
  c.step(1.0/hz);assert(u->position.z<before&&u->move_speed>=32&&u->target_handle==foe);
  for(int tick=0;tick<hz/3;++tick)c.step(1.0/hz);
  assert(c.unit(foe)->hp<1000000);++checks;
 }
 for(int kind:{HOUND_KIND,BEAR_KIND})for(int order:{HOUND_ATTACK,HOUND_DEFEND}){
  Crowd c;c.configure(64,64);c.set_navigation({});assert(c.combat.configure(kits()));
  auto pet=c.spawn(-1,1,kind,{0,0,0},30000,.6f);
  auto foe=c.spawn(100,0,SLIME_KIND,{0,0,-8},1000000,.5f);
  c.set_guard(pet,{0,0,0},18);
  ExternalTarget hero;hero.hp=10000;
  c.combat.set_targets({hero},0,0,order,1,order==HOUND_ATTACK?foe:0);
  c.step(1.0/60);
  const auto* u=c.unit(pet);
  const float expected=kind==HOUND_KIND?(order==HOUND_ATTACK?13.f:6.f):(order==HOUND_ATTACK?20.f:15.f);
  assert(u->target_handle==foe&&length(u->velocity)>expected&&c.unit(foe)->hp==1000000);
  const Vec3 at=u->position;
  c.combat.set_targets({hero},0,0,HOUND_HOLD,2);
  for(int tick=0;tick<30;++tick)c.step(1.0/60);
  assert(length(u->position-at)<.001f&&c.unit(foe)->hp==1000000);++checks;
 }
 for(int hz:{20,30,60})for(bool wall:{false,true})for(int order:{HOUND_ATTACK,HOUND_DEFEND}){
  Crowd c;c.configure(64,64);NavigationData nav;
  nav.origin={-60,0,-60};nav.width=61;nav.spacing=3;nav.heights.assign(61*61,0);nav.covered.assign(61*61,1);
  if(wall){nav.obstacle_min={{1.5f,-1,-50}};nav.obstacle_max={{4.5f,10,50}};}
  c.set_navigation(nav);assert(c.combat.configure(kits()));
  ExternalTarget hero;hero.hp=1000;hero.foot={0,0,14};std::vector<Handle> pets;
  for(int i=0;i<6;++i){auto h=c.spawn(-i-1,1,i==5?BEAR_KIND:HOUND_KIND,{wall?-8.f:float(i*3-7),0,wall?float(6+i*2):14.f},30000,i==5?1.2f:.6f);c.set_guard(h,c.unit(h)->position,18);pets.push_back(h);}
  for(int cycle=0;cycle<3;++cycle){
   Vec3 center{wall?0.f:float(cycle*6),0,0};auto enemy=c.spawn(100+cycle,0,SLIME_KIND,center,10000000,.5);
   c.combat.set_targets({hero},0,0,order,cycle+1,order==HOUND_ATTACK?enemy:0);std::set<int64_t> hitters;
   for(int tick=0;tick<hz*12;++tick){c.step(1.0/hz);for(auto& event:c.combat.events())if(event.kind==DAMAGE&&event.target_id==100+cycle)hitters.insert(event.source_id);c.combat.clear_events();}
   std::set<int> octants;float spacing=1000;bool targeting=true;
   for(auto h:pets){auto u=c.unit(h);auto offset=u->position-center;octants.insert((int(std::round(std::atan2(offset.x,offset.z)*4/M_PI))+8)%8);targeting&=u->target_handle==enemy;++checks;
    for(auto other:pets)if(other!=h){auto v=c.unit(other);spacing=std::min(spacing,length(u->position-v->position)/(u->radius+v->radius));}}
   std::cout<<"PET_SURROUND hz="<<hz<<" wall="<<wall<<" order="<<order<<" cycle="<<cycle<<" octants="<<octants.size()<<" min_spacing="<<spacing<<" hitters="<<hitters.size()<<" focus="<<c.combat.hound_focus_target()<<std::endl;
   if(!targeting||hitters.size()!=pets.size())for(auto h:pets){auto u=c.unit(h);std::cout<<"PET_TRACE id="<<u->logical_id<<" hit="<<hitters.count(u->logical_id)<<" target="<<u->target_handle<<" position="<<u->position.x<<","<<u->position.y<<","<<u->position.z<<" goal="<<u->goal.x<<","<<u->goal.z<<" action="<<u->action_active<<" order="<<u->hound_order<<" reach="<<c.allied_terrain.reachable(u->position,center,u->radius,u->support_layer)<<" layer="<<u->support_layer<<" think="<<u->think_left<<std::endl;}
   assert(targeting&&octants.size()>=(wall?3u:4u)&&spacing>=.9f&&hitters.size()==pets.size());++checks;
   c.despawn(enemy);
  }
 }
 std::cout<<"PET_SURROUND_RESULT checks="<<checks<<" failures=0\n";
}
