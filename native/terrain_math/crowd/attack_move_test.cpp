#include "pet_skills_fixture.h"
#include <iostream>

int main(){
 int checks=0;
 for(int hz:{20,30,60})for(int skin:{-1,0,21,41,61,81}){
  Crowd c;c.configure(128,128);c.set_navigation({});auto data=kits();
  data.soldier_kinds.push_back(BEAR_KIND);data.soldier_profiles.insert(data.soldier_profiles.end(),{30000,12,3000,3.4,6,1.75});
  data.bear_attacks.assign(data.hound_attacks.begin(),data.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<data.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.bear_attacks[i+3]=135;data.bear_attacks[i+5]=135;}
  assert(c.combat.configure(data));
  ExternalTarget hero;hero.id=7;hero.hp=10000;
  auto pet=c.spawn(-1,1,skin<0?BEAR_KIND:HOUND_KIND,{0,0,0},3000,.5);c.unit(pet)->pose_row=std::max(0,skin);c.set_guard(pet,{0,0,0},18);
  auto behind=c.spawn(1,0,12,{0,0,8},1000000,.5);
  auto side=c.spawn(2,0,12,{20,0,-1},1000000,.5);
  auto front=c.spawn(3,0,12,{0,0,-18},1000000,.5);
  const double dt=1.0/hz;const Vec3 destination{0,0,-60};
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,0,destination);c.step(dt);c.step(dt);
  assert(c.unit(pet)->target_handle==front);++checks;
  for(int serial=2;serial<=4;++serial){
   c.combat.set_targets({hero},0,0,HOUND_ATTACK,serial,0,destination);c.combat.before_move(c,dt);
   assert(!c.unit(pet)->target_handle&&!c.unit(pet)->action_active&&c.unit(pet)->has_goal);++checks;
   c.step(.2);
   assert(c.unit(pet)->target_handle==front);++checks;
  }
  for(int i=0;i<hz*4;++i)c.step(dt);
  assert(c.unit(front)->hp<1000000&&c.unit(behind)->hp==1000000&&c.unit(side)->hp==1000000);++checks;
  c.set_pose(pet,{0,0,-26},0);c.unit(pet)->action_active=false;c.unit(pet)->think_left=0;c.step(dt);
  assert(c.unit(pet)->target_handle==front);++checks;
  c.despawn(front);
  for(int i=0;i<hz*8;++i)c.step(dt);
  assert(!c.unit(pet)->target_handle&&length(c.unit(pet)->position-destination)<2);++checks;
  hero.foot={80,0,50};c.combat.set_targets({hero},0,18,HOUND_ATTACK,4,0,destination);
  for(int i=0;i<hz*2;++i)c.step(dt);
  assert(length(c.unit(pet)->position-destination)<2&&!c.unit(pet)->has_goal);++checks;
  auto arrival=c.spawn(4,0,12,{0,0,-65},1000000,.5);
  for(int i=0;i<hz*3;++i)c.step(dt);
  assert(c.unit(arrival)->hp<1000000&&c.unit(pet)->target_handle==arrival);++checks;
  c.despawn(arrival);
  // A fresh direction releases the old pursuit immediately.
  c.set_pose(pet,{0,0,0},0);hero.foot={0,0,0};
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,5,0,{60,0,0});
  for(int i=0;i<hz*3;++i)c.step(dt);
  assert(c.unit(pet)->position.x>10&&c.unit(behind)->hp==1000000);++checks;
  c.combat.set_targets({hero},0,0,HOUND_HOLD,6);c.step(dt);auto post=c.unit(pet)->position;
  for(int i=0;i<hz;++i)c.step(dt);
  assert(length(c.unit(pet)->position-post)<.001f);++checks;
  c.combat.set_targets({hero},0,0,HOUND_RETURN,7);
  for(int i=0;i<hz;++i)c.step(dt);
  assert(length(c.unit(pet)->position-post)>1);++checks;
  // Explicit focus and local player-threat priority keep their existing behavior.
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,8,behind);c.step(dt);
  assert(c.unit(pet)->target_handle==behind);++checks;
  c.set_pose(pet,{0,0,0},0);c.unit(pet)->action_active=false;
  c.unit(behind)->external_kind=0;c.unit(behind)->external_target=7;
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,9,0,destination);c.step(dt);c.step(dt);
  assert(c.unit(pet)->target_handle==behind);++checks;
  c.combat.set_targets({hero},0,0,HOUND_HOLD,10);c.step(dt);
  c.despawn(pet);pet=c.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);c.set_guard(pet,{0,0,0},18);
  c.combat.set_targets({hero});c.step(dt);
  assert(c.unit(pet)->hound_order==HOUND_DEFEND);++checks;
 }
 // Redirect before contact, during a combo/flurry and during a counter, without finishing the old attack.
 for(int hz:{20,30,60})for(int skin:{-1,0,21,41,61,81})for(int mode=0;mode<5;++mode){
  Crowd c;c.configure(64,64);c.set_navigation({});auto data=kits();
  data.soldier_kinds.push_back(BEAR_KIND);data.soldier_profiles.insert(data.soldier_profiles.end(),{30000,12,3000,3.4,6,1.75});
  data.bear_attacks.assign(data.hound_attacks.begin(),data.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<data.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.bear_attacks[i+3]=135;data.bear_attacks[i+5]=135;}
  assert(c.combat.configure(data));
  ExternalTarget hero;hero.id=7;hero.hp=10000;
  auto pet=c.spawn(-1,1,skin<0?BEAR_KIND:HOUND_KIND,{0,0,0},3000,.5);auto* u=c.unit(pet);
  u->pose_row=std::max(0,skin);c.set_guard(pet,{0,0,0},18);
  auto old=c.spawn(100,0,12,{0,0,-2},1000000,.5),next=c.spawn(101,0,12,{18,0,0},1000000,.5);
  const double dt=1.0/hz;
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,old);c.step(dt);
  u->action_active=true;u->action=1;u->action_time=.32;u->phase_tick=9.9;u->target_handle=old;
  if(mode==1){u->pet_skill=2;u->pet_combo_left=3;u->action_hits.push_back(old);}
  if(mode==2||mode==3){u->pet_skill=PET_BEE_FLURRY;u->pet_combo_left=5;u->pet_flurry_charge=mode==2?.4:0;u->pet_flurry_origin={-30,0,0};}
  if(mode==4){u->counter_active=u->counter_pending=true;u->counter_contact=.33;u->counter_duration=1;}
  const Vec3 before=u->position;
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,2,0,{60,0,0});c.combat.before_move(c,dt);
  assert(!u->target_handle&&!u->action_active&&!u->counter_active&&!u->counter_pending);++checks;
  assert(!u->pet_skill&&!u->pet_combo_left&&!u->pet_flurry_charge&&u->action_hits.empty());++checks;
  assert(u->hound_order_serial==2&&u->has_goal&&u->goal.x>u->position.x&&length(u->position-before)<.001f);++checks;
  c.combat.after_move(c,dt);assert(c.unit(old)->hp==1000000);++checks;
  c.step(.2);assert(u->target_handle==next);++checks;
  for(int i=0;i<hz*3;++i)c.step(dt);
  assert(c.unit(old)->hp==1000000&&c.unit(next)->hp<1000000);++checks;
 }
 // A newly arrived enemy is noticed promptly during an otherwise empty advance.
 for(int hz:{20,30,60})for(int skin:{-1,0,21,41,61,81}){
  Crowd c;c.configure(64,64);c.set_navigation({});auto data=kits();
  data.soldier_kinds.push_back(BEAR_KIND);data.soldier_profiles.insert(data.soldier_profiles.end(),{30000,12,3000,3.4,6,1.75});
  data.bear_attacks.assign(data.hound_attacks.begin(),data.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<data.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.bear_attacks[i+3]=135;data.bear_attacks[i+5]=135;}
  assert(c.combat.configure(data));ExternalTarget hero;hero.id=7;hero.hp=10000;
  auto pet=c.spawn(-1,1,skin<0?BEAR_KIND:HOUND_KIND,{0,0,0},3000,.5);c.unit(pet)->pose_row=std::max(0,skin);c.set_guard(pet,{0,0,0},18);
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,0,{0,0,-60});c.step(1.0/hz);c.step(1.0/hz);
  auto enemy=c.spawn(100,0,SLIME_KIND,c.unit(pet)->position+Vec3{0,0,-6},1000000,.5);
  int ticks=0;while(!c.unit(pet)->target_handle&&ticks<hz){c.step(1.0/hz);++ticks;}
  std::cout<<"PET_ACQUIRE hz="<<hz<<" skin="<<skin<<" seconds="<<double(ticks)/hz<<std::endl;
  assert(c.unit(pet)->target_handle==enemy&&double(ticks)/hz<=.1+1.0/hz);++checks;
 }
 // A pet already in clear melee contact can attack without first orbiting to its reserved post.
 for(int hz:{20,30,60})for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;c.configure(64,64);c.set_navigation({});auto data=kits();
  data.soldier_kinds.push_back(BEAR_KIND);data.soldier_profiles.insert(data.soldier_profiles.end(),{30000,12,3000,3.4,6,1.75});
  data.bear_attacks.assign(data.hound_attacks.begin(),data.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<data.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.bear_attacks[i+3]=135;data.bear_attacks[i+5]=135;}
  assert(c.combat.configure(data));ExternalTarget hero;hero.id=7;hero.hp=10000;
  auto enemy=c.spawn(100,0,SLIME_KIND,{0,0,0},1000000,.5);
  std::vector<Handle> pets;
  for(int i=0;i<2;++i){
   Vec3 point{float(i?2:-2),0,2};auto pet=c.spawn(-i-1,1,kind,point,3000,.5);c.set_guard(pet,point,18);
   auto* u=c.unit(pet);u->target_handle=enemy;u->hound_order=HOUND_ATTACK;u->hound_order_serial=1;u->age=1;
   u->yaw=std::atan2(point.x,point.z);pets.push_back(pet);
  }
  c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,0,{0,0,-60});c.combat.before_move(c,1.0/hz);
  for(auto pet:pets){assert(c.unit(pet)->action_active&&!c.unit(pet)->has_goal);++checks;}
 }
 // Empty advances route around existing cover, for pets and summoned bears.
 for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;c.configure(64,64);auto data=kits();data.soldier_kinds.push_back(BEAR_KIND);
  data.soldier_profiles.insert(data.soldier_profiles.end(),{30000,12,3000,3.4,6,1.75});
  data.bear_attacks.assign(data.hound_attacks.begin(),data.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);for(size_t i=0;i<data.bear_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.bear_attacks[i+3]=135;data.bear_attacks[i+5]=135;}
  assert(c.combat.configure(data));
  NavigationData nav;nav.origin={-90,0,-90};nav.width=61;nav.spacing=3;nav.heights.assign(61*61,0);nav.covered.assign(61*61,1);
  nav.obstacle_min={{-6,-1,-30}};nav.obstacle_max={{6,10,-24}};c.set_navigation(nav);
  auto pet=c.spawn(-1,1,kind,{0,0,0},3000,.5);c.set_guard(pet,{0,0,0},18);
  ExternalTarget hero;hero.id=7;hero.hp=10000;c.combat.set_targets({hero},0,0,HOUND_ATTACK,1,0,{0,0,-60});
  bool detoured=false;
  for(int i=0;i<900;++i){c.step(1.0/60);auto p=c.unit(pet)->position;
   if(p.z>=-30&&p.z<=-24){assert(std::abs(p.x)>6);detoured=true;}
  }
  assert(detoured&&length(c.unit(pet)->position-Vec3{0,0,-60})<2);++checks;
 }
 std::cout<<"ATTACK_MOVE_RESULT checks="<<checks<<" failures=0\n";
}
