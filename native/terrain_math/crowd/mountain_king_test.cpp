#include "core.h"
#include <cassert>
#include <iostream>
#include <limits>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={0};d.soldier_profiles={192,0,11,2.5f,5,2.304f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};d.bullet_speed=8.64f;d.bullet_life=3.34f;d.bullet_tail=.576f;d.bullet_radius=.576f;d.skullpion={3,30};return d;
}
static float charge_distance(float factor){
 Crowd c;c.configure(2,4);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto h=c.spawn(1,0,4,{0,0,0},30000,1);auto u=c.unit(h);u->action=101;u->action_active=true;
 u->attack_slow_factor=factor;u->attack_slow_left=20;
 for(int i=0;i<600&&u->action_active;i++)c.step(.01);
 return u->position.z;
}
static void taunt_targets(){
 for(int hz:{20,30,60}){
  Crowd c;c.configure(32,16);
  NavigationData nav;nav.origin={-60,0,-60};nav.width=81;nav.spacing=3;
  nav.heights.assign(81*81,0);nav.covered.assign(81*81,1);c.set_navigation(nav);
  auto d=kits();d.soldier_profiles[1]=6;assert(c.combat.configure(d));
  auto enemy=c.spawn(1,0,0,{0,0,0},1000,.4);auto u=c.unit(enemy);
  ExternalTarget castle;castle.id=40;castle.kind=2;castle.hp=1000;castle.assault_priority=2;
  castle.foot={10,0,0};castle.minimum={8,0,-2};castle.maximum={12,10,2};
  ExternalTarget hero;hero.kind=0;hero.hp=100;hero.foot=hero.minimum=hero.maximum={0,0,45};
  c.combat.set_targets({castle,hero});c.step(1.0/hz);assert(u->external_kind==2);
  hero.taunting=true;c.combat.set_targets({castle,hero});
  for(int i=0;i<hz;++i)c.step(1.0/hz);
  assert(u->external_kind==0&&u->position.z>1&&u->hp==1000);
  hero.taunting=false;c.combat.set_targets({castle,hero});
  for(int i=0;i<hz/2;++i)c.step(1.0/hz);
  assert(u->external_kind==2);
  c.set_pose(enemy,{0,0,0},0);
  std::vector<Handle> kings;
  Hit taunt;taunt.effect=5;taunt.status_seconds=1;
  assert(!c.combat.hit(c,enemy,taunt).accepted);
  for(int i=0;i<5;++i){
   auto king=c.spawn(-i-1,1,133,{-30.0f+i,0,35},150,.4);kings.push_back(king);
   assert(c.set_mirror(king,5,7,3,{0,0,-1}));c.unit(king)->mirror_busy=true;
   assert(c.combat.hit(c,king,taunt).accepted&&c.unit(king)->hp==150);
  }
  for(int i=0;i<hz/2;++i)c.step(1.0/hz);
  assert(u->target_handle==kings.front()&&u->position.z>0);
  c.despawn(kings.front());
  for(int i=0;i<hz/4;++i)c.step(1.0/hz);
  assert(u->target_handle==kings[1]);
  for(int i=0;i<hz;++i)c.step(1.0/hz);
  assert(c.unit(kings[1])->buff_left==0&&u->external_kind==2&&!u->target_handle);
  for(auto king:kings)c.despawn(king);
  auto reused=c.spawn(-10,1,133,{-30,0,35},150,.4);assert(c.unit(reused)->buff_left==0);
 }
}
int main(){
 taunt_targets();
 assert(std::abs(charge_distance(1)-charge_distance(.5))<.3); // Slowing the attack cannot double its travel.
 Crowd c;c.configure(32,16);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto h=c.spawn(1,0,0,{0,0,0},1000,.4);auto u=c.unit(h);
 Hit slow;slow.effect=2;slow.slow_factor=.5;slow.attack_slow_factor=.5;slow.status_seconds=5;
 assert(c.combat.hit(c,h,slow).accepted&&u->slow_factor==.5&&u->attack_slow_factor==.5);
 u->action_active=true;u->soldier_phase=0;u->action=1;c.step(.1);assert(std::abs(u->phase_tick-1.5)<.001);
 Hit movement;movement.effect=2;movement.slow_factor=.7;movement.status_seconds=10;c.combat.hit(c,h,movement);
 for(int i=0;i<51;i++)c.step(.1);
 assert(u->attack_slow_factor==1&&u->slow_factor==.5); // Separate expiries.
 Hit invalid=slow;invalid.attack_slow_factor=NAN;invalid.slow_factor=NAN;assert(!c.combat.hit(c,h,invalid).accepted);
 Hit stun;stun.effect=4;stun.status_seconds=5;assert(c.combat.hit(c,h,stun).accepted);
 Hit normal;normal.amount=10;c.combat.hit(c,h,normal);assert(u->stun==5); // Later hits cannot erase Storm Bolt.
 auto king=c.spawn(-1,1,133,{10,0,0},150,.4);auto k=c.unit(king);
 assert(c.set_mirror(king,5,7,3,{0,0,-1}));
 auto boss=c.spawn(2,0,4,{50,0,0},30000,18);auto b=c.unit(boss);b->action=101;b->action_active=true;
 stun.status_seconds=3;assert(c.combat.hit(c,boss,stun).accepted&&b->stun==3);
 auto position=b->position;c.step(.1);assert(b->action_time==0&&length(b->position-position)==0);
 Hit avatar;avatar.effect=3;avatar.status_seconds=1;assert(c.combat.hit(c,king,avatar).accepted);
 assert(k->max_hp==650&&k->hp==650);c.combat.hit(c,king,avatar);assert(k->max_hp==650);
 normal.amount=130;auto hit=c.combat.hit(c,king,normal);assert(hit.accepted&&std::abs(k->hp-550)<.001);
 normal.magical=true;k->invuln=0;assert(!c.combat.hit(c,king,normal).accepted&&k->hp==550);
 for(int i=0;i<11;i++)c.step(.1);assert(k->avatar_left==0&&k->max_hp==150&&k->hp==150);
 c.despawn(king);auto next=c.spawn(-2,1,133,{10,0,0},150,.4);assert(next!=king&&c.unit(next)->avatar_left==0);
 assert(!magical_attack(1,0,true)&&magical_attack(17,0,true)&&magical_attack(18,302,true)&&magical_attack(4,105,false));
 std::cout<<"MOUNTAIN_KING_NATIVE_RESULT failures=0\n";
}
