#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={HOUND_KIND,BEAR_KIND};d.soldier_profiles={3000,4.5f,60,3.4f,6,1.75f,30000,12,3000,3.4f,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.hound_attacks[i]=30;d.hound_attacks[i+1]=1;d.hound_attacks[i+2]=15;d.hound_attacks[i+3]=131;}
 d.bear_attacks.assign(d.hound_attacks.begin(),d.hound_attacks.begin()+5*8*HOUND_TIMELINE_STRIDE);
 return d;
}
static ExternalTarget hero(){ExternalTarget p;p.id=7;p.hp=10000;return p;}
static Handle pet(Crowd& c,int skin=0,Vec3 point={5,0,0}){auto h=c.spawn(-skin-1,1,HOUND_KIND,point,3000,.5);c.unit(h)->pose_row=skin;c.set_guard(h,point,18);return h;}
static Handle foe(Crowd& c,int id,Vec3 point,bool threat=false){auto h=c.spawn(id,0,12,point,10000,.5);if(threat){c.unit(h)->external_kind=0;c.unit(h)->external_target=7;}return h;}
static void setup(Crowd& c){c.configure(128,128);c.set_navigation({});assert(c.combat.configure(kits()));c.combat.set_targets({hero()});}
int main(){
 int checks=0;
 for(int skin:{0,21,41,61,81}){
  Crowd c;setup(c);auto data=kits();data.hound_hp=150;data.hound_damage=data.pet_mana=50;data.pet_mana_regen=1;
  assert(c.combat.configure(data,&c));auto h=pet(c,skin);auto other=pet(c,skin+1,{12,0,0});
  auto* u=c.unit(h);u->max_hp=150;u->hp=110;u->pet_mana=20;
  assert(c.set_pet_growth(h,42,15)&&c.set_pet_training(h,1.05,1.1,10,false));
  assert(u->max_hp==192&&u->hp==152&&u->pet_mana==30);++checks;
  assert(!c.set_pet_training(h,NAN,1,0,false)&&!c.set_pet_training(h,1,0,0,false)&&!c.set_pet_training(h,1,1,INFINITY,false));++checks;
  c.set_goal(h,{5,0,-10},10);assert(std::abs(u->move_speed-10.5)<1e-6);++checks;
  auto target=foe(c,1,{5,0,-2});
  u->target_handle=target;u->action_active=true;u->action=1;u->live_delta=.1;
  c.combat.after_move(c,.1);assert(std::abs(u->action_time-.11)<1e-7);++checks;
  assert(c.unit(other)->pet_attack_multiplier==1&&c.unit(other)->pet_move_multiplier==1&&c.unit(other)->pet_damage_bonus==0);++checks;
  c.rest_allies();assert(u->pet_health_bonus==42&&u->pet_damage_bonus==15&&u->pet_mana_bonus==10&&u->pet_attack_multiplier==1.1&&u->pet_move_multiplier==1.05);++checks;
  data.hound_hp=180;assert(c.combat.configure(data,&c));assert(u->max_hp==222&&u->max_hp-u->hp==40);++checks;
  assert(c.set_pet_mana(h,60)&&!c.set_pet_mana(h,61));c.combat.rest_tick(c,2);assert(u->pet_mana==60);++checks;
  assert(c.set_pet_training(h,1.05,1.1,10,true)&&u->hp==u->max_hp);++checks;
  c.despawn(h);auto replacement=pet(c,skin);
  assert(replacement!=h&&!c.set_pet_training(h,1,1,0,true)&&c.unit(replacement)->pet_attack_multiplier==1&&c.unit(replacement)->pet_mana_bonus==0);++checks;
 }
 for(int hz:{20,30,60}){
  Crowd c;setup(c);std::vector<Handle> pack;
  for(int i=0;i<5;++i)pack.push_back(pet(c,i,{float(20+i*4),0,20}));
  auto player=hero();player.pet_formation_facing={0,0,-1};player.pet_formation_ids={-1,-2,-3,-4,-5};
  const Vec3 expected[]={{-7,0,-3.5f},{7,0,-3.5f},{0,0,7},{-7,0,3.5f},{7,0,3.5f}};
  for(int cycle=0;cycle<3;++cycle){
   c.combat.set_targets({player},0,0,cycle==0?HOUND_DEFEND:HOUND_RETURN,cycle+1);
   for(int i=0;i<hz*16;++i)c.step(1.0/hz);
   for(int i=0;i<5;++i){
    Vec3 post=cycle==0?expected[i]:Vec3{-expected[i].z,0,expected[i].x};
    assert(length(c.unit(pack[i])->position-player.foot-post)<1.5f);++checks;
   }
   player.pet_formation_facing={1,0,0};
   if(cycle==1)player.foot={20,0,10};
  }
 }

 for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;setup(c);
  auto data=kits();data.hound_hp=150;data.hound_damage=data.bear_damage=data.pet_mana=50;
  assert(c.combat.configure(data,&c));
  auto h=c.spawn(-1,1,kind,{5,0,0},150,.5);
  auto other=c.spawn(-2,1,kind,{10,0,0},150,.5);
  auto target=foe(c,1,{5,0,-2});
  auto* pet_unit=c.unit(h);
  assert(pet_unit->pet_mana==50&&c.combat.pet_max_mana()==50&&pet_unit->dodge_chance==0&&pet_unit->counter_chance==0);++checks;
  pet_unit->pet_mana=17;c.rest_allies();
  assert(pet_unit->pet_mana==17&&c.unit(other)->pet_mana==50&&!c.valid(target));++checks;
  target=foe(c,1,{5,0,-2});
  Hit hit;hit.amount=10;hit.source_id=1;
  assert(c.set_boss_reactions(h,1,0)&&!c.combat.hit(c,h,hit).accepted&&pet_unit->hp==150);++checks;
  assert(c.set_boss_reactions(h,0,1)&&c.combat.hit(c,h,hit).accepted&&pet_unit->counter_pending);
  c.step(1.0/60);
  assert(pet_unit->counter_active&&pet_unit->target_handle==target);++checks;
  for(int i=0;i<36;++i)c.step(1.0/60);
  assert(c.unit(target)->hp==9950);++checks;
  c.despawn(h);h=c.spawn(-1,1,kind,{5,0,0},150,.5);
  assert(c.unit(h)->pet_mana==50&&c.unit(h)->dodge_chance==0&&c.unit(h)->counter_chance==0);++checks;
 }
 for(int hz:{20,30,60})for(int skin:{0,21,41,61,81}){
  const double dt=1.0/hz;Crowd c;setup(c);auto h=pet(c,skin);auto near=foe(c,1,{6,0,0});auto attacker=foe(c,2,{-10,0,0},true);
  c.step(dt);assert(c.unit(h)->target_handle==attacker);++checks;
  c.despawn(attacker);c.unit(h)->hound_return_left=-1;c.unit(h)->target_handle=0;c.unit(h)->think_left=0;c.step(dt);
  assert(c.unit(h)->target_handle==near);++checks;
  attacker=foe(c,3,{-10,0,0},true);c.unit(h)->action_active=false;c.unit(h)->think_left=0;c.step(dt);
  assert(c.unit(h)->target_handle==attacker);++checks;
  // Native targets override stale external player metadata.
  c.unit(attacker)->target_handle=h;c.unit(h)->target_handle=0;c.unit(h)->action_active=false;c.unit(h)->think_left=0;c.step(dt);
  assert(c.unit(h)->target_handle==near);++checks;
  c.unit(attacker)->target_handle=0;c.unit(h)->action_active=true;c.unit(h)->think_left=0;c.combat.before_move(c,dt);
  assert(c.unit(h)->target_handle==near);++checks;
  c.unit(h)->action_active=false;c.unit(h)->target_handle=0;c.unit(h)->think_left=0;c.unit(attacker)->shelter_mode=2;c.step(dt);
  assert(c.unit(h)->target_handle==near);++checks;
  c.despawn(near);c.despawn(attacker);auto distant=foe(c,4,{40,0,0},true);c.unit(h)->target_handle=0;c.unit(h)->action_active=false;c.unit(h)->think_left=0;c.step(dt);
  assert(!c.unit(h)->target_handle);++checks;
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK);c.unit(h)->think_left=0;c.step(dt);assert(c.unit(h)->target_handle==distant);++checks;
  auto nearby=foe(c,5,{-3,0,0});
  for(int serial=1;serial<=3;++serial){
   c.combat.set_targets({hero()},0,0,HOUND_RETURN,serial);c.step(dt);assert(!c.unit(h)->target_handle&&!c.unit(h)->action_active);++checks;
   for(int i=0;i<hz*12&&!c.unit(h)->target_handle;++i)c.step(dt);
   assert(c.unit(h)->target_handle==nearby);++checks;
  }
  auto gone=hero();gone.hp=0;c.combat.set_targets({gone});c.step(dt);assert(!c.unit(h)->target_handle&&!c.unit(h)->action_active);++checks;
 }
 for(int hz:{20,30,60})for(int skin:{0,21,41,61,81}){
  Crowd c;setup(c);auto h=pet(c,skin);auto close=foe(c,10,{5,0,-2});auto distant=foe(c,11,{15,0,0},true);
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK);c.step(1.0/hz);
  const Vec3 post=c.unit(h)->position;
  c.combat.set_targets({hero()},0,0,HOUND_HOLD,1);
  for(int i=0;i<hz*4;++i)c.step(1.0/hz);
  assert(length(c.unit(h)->position-post)<.001f&&!c.unit(h)->has_goal&&c.unit(close)->hp<10000&&c.unit(distant)->hp==10000);++checks;
  auto moved=hero();moved.foot={60,0,0};c.combat.set_targets({moved},0,10,HOUND_HOLD,1);
  for(int i=0;i<hz*2;++i)c.step(1.0/hz);
  assert(length(c.unit(h)->position-post)<.001f);++checks;
  c.despawn(close);
  for(int i=0;i<hz*3;++i)c.step(1.0/hz);
  assert(!c.unit(h)->target_handle&&length(c.unit(h)->position-post)<.001f);++checks;
  c.set_pose(distant,post+Vec3{0,0,2},0);
  for(int i=0;i<hz*3;++i)c.step(1.0/hz);
  assert(c.unit(distant)->hp<10000&&length(c.unit(h)->position-post)<.001f);++checks;
  c.combat.set_targets({moved},0,0,HOUND_HOLD,2);c.step(1.0/hz);
  assert(length(c.unit(h)->position-post)<.001f&&c.unit(h)->hound_order_serial==2);++checks;
  c.combat.set_targets({moved},0,0,HOUND_RETURN,3);
  for(int i=0;i<hz;++i)c.step(1.0/hz);
  assert(length(c.unit(h)->position-post)>1);++checks;
  c.combat.set_targets({moved},0,0,HOUND_HOLD,4);c.step(1.0/hz);const Vec3 second=c.unit(h)->position;
  c.set_pose(distant,second+Vec3{12,0,0},0);
  c.combat.set_targets({moved},0,0,HOUND_ATTACK,5);
  for(int i=0;i<hz;++i)c.step(1.0/hz);
  assert(length(c.unit(h)->position-second)>1&&c.unit(h)->target_handle==distant);++checks;
 }
 // Automatic escorts clear reachable enemies before returning, including late arrivals.
 for(int hz:{20,30,60})for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;setup(c);const double dt=1.0/hz;
  auto h=c.spawn(-1,1,kind,{16,0,0},30000,.5);c.set_guard(h,{16,0,0},18);
  auto first=foe(c,1,{16,0,-2}),next=foe(c,2,{15,0,-3});
  c.step(dt);assert(c.unit(h)->target_handle==first);++checks;
  auto moved=hero();moved.foot={80,0,0};c.combat.set_targets({moved},0,18);
  c.step(dt);assert(c.unit(h)->target_handle==first);++checks;
  for(int cycle=0;cycle<3;++cycle){
   c.despawn(first);c.step(dt);
   assert(c.unit(h)->target_handle==next&&c.unit(h)->hound_return_left<0);++checks;
   assert(length(c.unit(h)->position-Vec3{16,0,0})<3);++checks;
   first=next;next=foe(c,3+cycle,{15,0,-3});
  }
  c.despawn(first);c.despawn(next);c.step(dt);
  assert(!c.unit(h)->target_handle&&c.unit(h)->hound_return_left>=0);++checks;
  // A foe arriving as the return delay expires must cancel it between decisions.
  auto late=foe(c,10,{15,0,-3});c.unit(h)->hound_return_left=dt;c.unit(h)->think_left=1;
  c.combat.clear_events();c.step(dt);c.step(dt);
  assert(c.unit(h)->target_handle==late&&c.unit(h)->hound_return_left<0);++checks;
  for(const auto& event:c.combat.events()){assert(event.action_index!=HOUND_BLINK_CUE);++checks;}
  auto outside=foe(c,11,{-20,0,0});c.despawn(late);c.step(dt);
  assert(!c.unit(h)->target_handle&&c.unit(h)->hound_return_left>=0);++checks;
  const Vec3 start=c.unit(h)->position;
  for(int i=0;i<hz*8;++i){
   const Vec3 before=c.unit(h)->position;c.step(dt);
   assert(length(c.unit(h)->position-before)<=35*dt+.001f);
   for(const auto& event:c.combat.events())assert(event.action_index!=HOUND_BLINK_CUE);
  }
  assert(length(c.unit(h)->position-start)>40&&length(c.unit(h)->position-moved.foot)<17&&c.unit(outside)->hp==10000);++checks;
 }
 // Automatic return uses the same terrain routing as ordinary escort movement.
 for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;setup(c);
  NavigationData nav;nav.origin={-60,0,-60};nav.width=61;nav.spacing=3;nav.heights.assign(61*61,0);nav.covered.assign(61*61,1);
  nav.obstacle_min={{28,0,-8}};nav.obstacle_max={{31,10,8}};c.set_navigation(nav);
  auto h=c.spawn(-1,1,kind,{16,0,0},30000,.5);c.set_guard(h,{16,0,0},18);
  auto enemy=foe(c,1,{16,0,-2});c.step(1.0/60);assert(c.unit(h)->target_handle==enemy);
  auto moved=hero();moved.foot={50,0,0};c.combat.set_targets({moved});c.despawn(enemy);
  bool ran_around=false;
  for(int i=0;i<480;++i){
   const Vec3 before=c.unit(h)->position;c.step(1.0/60);const Vec3 after=c.unit(h)->position;
   assert(length(after-before)<=.585f);
   if(after.x>=28&&after.x<=31){assert(std::abs(after.z)>8);ran_around=true;}
  }
  assert(ran_around&&c.unit(h)->position.x>31&&length(c.unit(h)->position-moved.foot)<17);++checks;
 }
 // Recall routes around cover to the assigned post instead of picking a random clear side.
 {
  Crowd c;setup(c);
  NavigationData nav;nav.origin={-60,0,-60};nav.width=61;nav.spacing=3;nav.heights.assign(61*61,0);nav.covered.assign(61*61,1);
  nav.obstacle_min={{28,0,-8}};nav.obstacle_max={{31,10,8}};c.set_navigation(nav);
  auto h=pet(c,0,{16,0,0});auto player=hero();player.foot={50,0,0};
  player.pet_formation_facing={0,0,-1};player.pet_formation_ids={-1};
  c.combat.set_targets({player},0,0,HOUND_RETURN,1);
  for(int i=0;i<900;++i){auto before=c.unit(h)->position;c.step(1.0/60);assert(length(c.unit(h)->position-before)<.585f);}
  assert(length(c.unit(h)->position-Vec3{43,0,-3.5f})<1.5f);++checks;
 }
 // Distant companions each search their own neighborhood, not the player's or another pet's.
 for(int kind:{HOUND_KIND,BEAR_KIND}){
  Crowd c;setup(c);c.combat.set_targets({hero()},0,18);std::vector<Handle> pack,targets;
  for(int i=0;i<5;++i){
   Vec3 point{float(i*50-100),0,30};
   auto h=c.spawn(-i-1,1,kind,point,30000,.5);c.set_guard(h,point,18);pack.push_back(h);
   targets.push_back(foe(c,i+1,point+Vec3{0,0,-12}));
  }
  foe(c,50,{0,0,0},true);c.step(1.0/60);
  for(int i=0;i<5;++i){assert(c.unit(pack[i])->target_handle==targets[i]);++checks;}
 }
 // A pack shares a lone foe, then spreads immediately when replacements arrive.
 for(int hz:{20,30,60})for(int skin=-1;skin<HOUND_SKINS;++skin){
  const int kind=skin<0?BEAR_KIND:HOUND_KIND;
  Crowd c;setup(c);std::vector<Handle> pack,targets;const double dt=1.0/hz;
  for(int i=0;i<5;++i){auto h=c.spawn(-i-1,1,kind,{0,0,6},30000,.5);c.unit(h)->pose_row=std::max(0,skin);c.set_guard(h,{0,0,6},18);pack.push_back(h);}
  targets.push_back(foe(c,1,{0,0,-2}));c.combat.before_move(c,dt);
  for(auto h:pack){assert(c.unit(h)->target_handle==targets[0]);++checks;}
  for(int cycle=0;cycle<4;++cycle){
   for(auto h:targets)c.despawn(h);targets.clear();
   for(int i=0;i<5;++i)targets.push_back(foe(c,10+cycle*5+i,{float(i-2)*.5f,0,-2}));
   c.combat.before_move(c,dt);std::set<Handle> chosen;
   for(auto h:pack){chosen.insert(c.unit(h)->target_handle);assert(c.unit(h)->hound_return_left<0);++checks;}
   assert(chosen.size()==5&&!chosen.count(0));++checks;
   // Decisions do not shuffle living targets between attacks.
   std::vector<Handle> kept;for(auto h:pack)kept.push_back(c.unit(h)->target_handle);
   for(auto h:pack){c.unit(h)->action_active=false;c.unit(h)->think_left=0;}
   c.combat.before_move(c,dt);
   for(int i=0;i<5;++i){assert(c.unit(pack[i])->target_handle==kept[i]);++checks;}
  }
  // Player protection still outranks scattering, even with five claimed pets.
  auto threat=foe(c,99,{0,0,-3},true);
  for(auto h:pack){c.unit(h)->action_active=false;c.unit(h)->think_left=0;}
  c.combat.before_move(c,dt);
  for(auto h:pack){assert(c.unit(h)->target_handle==threat);++checks;}
 }
 // Equivalent nearby choices vary with each companion's existing random state.
 for(int kind:{HOUND_KIND,BEAR_KIND}){
  std::set<int64_t> choices;
  for(int seed=1;seed<=32;++seed){
   Crowd c;setup(c);auto h=c.spawn(-seed,1,kind,{0,0,6},30000,.5);c.set_guard(h,{0,0,6},18);
   foe(c,1,{-4,0,0});foe(c,2,{4,0,0});c.combat.before_move(c,1.0/60);
   choices.insert(c.unit(c.unit(h)->target_handle)->logical_id);
  }
  assert(choices.size()==2);++checks;
 }
 // Every pet's local search must still respect cover.
 {
  Crowd c;setup(c);NavigationData nav;nav.origin={-60,0,-60};nav.width=41;nav.spacing=3;nav.heights.assign(41*41,0);nav.covered.assign(41*41,1);
  nav.obstacle_min={{-14,0,-4},{-8,0,-4},{-14,0,-4},{-14,0,2}};
  nav.obstacle_max={{-12,10,4},{-6,10,4},{-6,10,-2},{-6,10,4}};c.set_navigation(nav);
  auto moved=hero();moved.foot={50,0,0};c.combat.set_targets({moved});
  auto blocked=foe(c,1,{-10,0,0},true);auto reachable=foe(c,2,{10,0,0});std::vector<Handle> pack;
  for(int skin:{0,21,41,61,81})pack.push_back(pet(c,skin,{5,0,float(int(pack.size())*2-4)}));
  c.step(1.0/60);for(auto h:pack){assert(c.unit(h)->target_handle==reachable&&c.unit(h)->target_handle!=blocked);++checks;}
 }
 {
  Crowd c;setup(c);auto h=pet(c);auto enemy=foe(c,1,{5,0,-2});
  NavigationData nav;nav.ray_min={{0,0,-1.1f}};nav.ray_max={{10,10,-.9f}};nav.ray_owner={-1};c.set_navigation(nav);
  c.combat.set_targets({hero()},0,0,HOUND_HOLD,1);
  for(int i=0;i<180;++i)c.step(1.0/60);
  assert(!c.unit(h)->target_handle&&c.unit(enemy)->hp==10000&&length(c.unit(h)->position-Vec3{5,0,0})<.001f);++checks;
 }
 // A cursor mark overrides automatic threats for both selectable pets and summoned bears.
 for(int hz:{20,30,60})for(int skin=-1;skin<HOUND_SKINS;++skin){
  const int kind=skin<0?BEAR_KIND:HOUND_KIND;const double dt=1.0/hz;
  Crowd c;setup(c);auto h=c.spawn(-1,1,kind,{5,0,0},30000,.5);c.unit(h)->pose_row=std::max(0,skin);c.set_guard(h,{5,0,0},18);
  auto near=foe(c,1,{5,0,-2},true),marked=foe(c,2,{32,0,0});
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK,1,marked);c.step(dt);
  assert(c.combat.hound_focus_target()==marked&&c.unit(h)->target_handle==marked);++checks;
  // Changing the mark cannot redirect a strike already in progress.
  c.unit(h)->target_handle=near;c.unit(h)->action_active=true;c.unit(h)->action_time=.01;
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK,2,marked);c.combat.before_move(c,dt);
  assert(c.unit(h)->target_handle==near&&c.unit(h)->action_active);++checks;
  c.unit(h)->action_active=false;c.step(dt);
  assert(c.unit(h)->target_handle==marked);++checks;
  c.combat.set_targets({hero()},0,0,HOUND_HOLD,3,marked);c.step(dt);
  assert(c.combat.hound_focus_target()==0&&c.unit(h)->hound_order==HOUND_HOLD&&!c.unit(h)->has_goal);++checks;
  c.combat.set_targets({hero()},0,0,HOUND_RETURN,4,marked);c.step(dt);
  assert(c.combat.hound_focus_target()==0&&!c.unit(h)->target_handle);++checks;
  // The native generation must expire with the victim, even when its slot is reused.
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK,5,marked);c.step(dt);c.despawn(marked);
  auto replacement=foe(c,2,{32,0,0});assert(replacement!=marked);c.step(dt);
  assert(c.combat.hound_focus_target()==0&&c.unit(h)->target_handle!=replacement&&c.unit(h)->hound_order==HOUND_DEFEND);++checks;
 }
 for(int scenario=0;scenario<5;++scenario){
  Crowd c;setup(c);auto h=pet(c);auto marked=foe(c,1,{32,0,0});auto p=hero();
  if(scenario==0)c.unit(marked)->team=1;
  if(scenario==1)c.set_pose(marked,{121,0,0},0);
  if(scenario==2)c.unit(marked)->shelter_mode=2;
  if(scenario==3)p.hp=0;
  if(scenario==4){
   NavigationData nav;nav.origin={-60,0,-60};nav.width=61;nav.spacing=3;nav.heights.assign(61*61,0);nav.covered.assign(61*61,1);
   nav.obstacle_min={{27,0,-6},{36,0,-6},{27,0,-6},{27,0,3}};
   nav.obstacle_max={{30,10,6},{39,10,6},{39,10,-3},{39,10,6}};c.set_navigation(nav);
  }
  c.combat.set_targets({p},0,0,HOUND_ATTACK,1,marked);c.step(1.0/60);
  assert(!c.combat.hound_focus_target()&&c.unit(h)->target_handle!=marked);++checks;
 }
 {
  Crowd c;setup(c);auto h=pet(c);auto marked=foe(c,1,{12,0,0});
  NavigationData nav;nav.origin={-30,0,-30};nav.width=21;nav.spacing=3;nav.heights.assign(441,0);nav.covered.assign(441,1);
  nav.obstacle_min={{12.25f,0,-2}};nav.obstacle_max={{15,8,2}};c.set_navigation(nav);
  assert(!c.allied_terrain.reachable(hero().foot,c.unit(marked)->position,.5f,0));
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK,1,marked);c.step(1.0/60);
  assert(c.combat.hound_focus_target()==marked&&c.unit(h)->target_handle==marked&&length(c.unit(h)->velocity)>10);
  for(int tick=0;tick<180;++tick)c.step(1.0/60);
  assert(c.unit(marked)->hp<10000);++checks;
 }
 {
  Crowd c;setup(c);auto h=pet(c);auto marked=foe(c,1,{32,0,0});
  c.combat.set_targets({hero()},0,0,HOUND_ATTACK,1,marked);c.step(1.0/60);c.despawn(h);c.step(1.0/60);
  assert(!c.combat.hound_focus_target());++checks;
 }
 std::cout<<"PET_DEFENSE_RESULT checks="<<checks<<" failures=0\n";
}
