#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={0};d.soldier_profiles={192,0,11,2.5f,5,2.304f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};
 d.bullet_speed=8.64f;d.bullet_life=3.34f;d.bullet_tail=.576f;d.bullet_radius=.576f;return d;
}
int main(){
 // Stationary shadows retain native targeting and never chase or follow the hero.
 for(double dt:{1.0/20,1.0/30,1.0/60}){
  Crowd shadow;shadow.configure(8,8);shadow.set_navigation(NavigationData{});
  assert(shadow.combat.configure(kits()));
  auto copy=shadow.spawn(-1,1,143,{0,0,0},100,.4);
  assert(!shadow.set_mirror(copy,1,-1,40,{}));
  assert(shadow.set_mirror(copy,1,0,120,{}));
  auto enemy=shadow.spawn(1,0,0,{0,0,140},100000,.4);shadow.unit(enemy)->frozen=100;
  for(int i=0;i<int(2/dt);++i){shadow.step(dt);assert(length(shadow.unit(copy)->position)<.001f);}
  for(const auto& event:shadow.combat.events())assert(event.ticket_id!=copy);
  shadow.set_pose(enemy,{0,0,96},0);shadow.combat.clear_events();
  int volleys=0;
  for(int i=0;i<int(2/dt);++i){
   shadow.step(dt);assert(length(shadow.unit(copy)->position)<.001f);
   for(const auto& event:shadow.combat.events())if(event.ticket_id==copy){assert(event.action_index==400);++volleys;}
   shadow.combat.clear_events();
  }
  assert(volleys>=2);shadow.despawn(enemy);
  for(int i=0;i<int(2/dt);++i){shadow.step(dt);assert(length(shadow.unit(copy)->position)<.001f);}
 }
 {Crowd boundary;boundary.configure(9,8);
  auto kazi=boundary.spawn(-1,1,134,{0,0,0},100,.4);
  auto uru=boundary.spawn(-2,1,135,{0,0,0},100,.4);
  auto maze=boundary.spawn(-3,1,136,{0,0,0},100,.4);
  auto shin=boundary.spawn(-4,1,137,{0,0,0},100,.4);
  auto saizo=boundary.spawn(-5,1,139,{0,0,0},100,.4);
  auto retired=boundary.spawn(-6,1,141,{0,0,0},100,.4);
  auto emilia=boundary.spawn(-7,1,142,{0,0,0},100,.4);
  auto lancelot=boundary.spawn(-8,1,143,{0,0,0},100,.4);
  assert(boundary.set_mirror(kazi,2,7,3,{0,0,-1}));
  assert(boundary.set_mirror(uru,7,7,3,{0,0,-1}));
  assert(boundary.set_mirror(maze,2,7,3,{0,0,-1}));
  assert(boundary.set_mirror(shin,2,7,3,{0,0,-1}));
  assert(boundary.set_mirror(saizo,2,7,3,{0,0,-1}));
  assert(!boundary.set_mirror(retired,2,7,3,{0,0,-1}));
  assert(boundary.set_mirror(emilia,7,7,3,{0,0,-1}));
  assert(boundary.set_mirror(lancelot,2,7,120,{}));
  boundary.despawn(shin);
  for(int kind:{138,140,144,145,146,147,148,149,150,151,152}){
   auto copy=boundary.spawn(-4,1,kind,{0,0,0},100,.4);
   assert(boundary.set_mirror(copy,2,7,3,{0,0,-1})==(kind!=152));
   boundary.despawn(copy);
  }
 }
 {Crowd ranged;ranged.configure(8,8);ranged.set_navigation(NavigationData{});
  assert(ranged.combat.configure(kits()));
  auto maze=ranged.spawn(-1,1,136,{0,0,0},100,.4);
  auto enemy=ranged.spawn(1,0,0,{0,0,28},100000,.4);ranged.unit(enemy)->frozen=100;
  assert(ranged.set_mirror(maze,2,7,120,{}));
  int throws=0;
  for(int i=0;i<120;++i){
   ranged.step(1.0/60);
   assert(length(ranged.unit(maze)->position)<.001f);
   for(const auto& event:ranged.combat.events())
    if(event.ticket_id==maze&&event.action_index>=400){assert(event.target_id==1);++throws;}
   ranged.combat.clear_events();
  }
  assert(throws>=2);
 }
 Crowd c;c.configure(32,16);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto h=c.spawn(-1,1,131,{0,0,0},150,.4);auto e=c.spawn(1,0,0,{0,0,20},100000,.4);c.unit(e)->frozen=100;
 auto close=c.spawn(2,0,0,{0,0,-10},100000,.4);c.unit(close)->frozen=100;
 assert(!c.set_mirror(h,0,7,3,{0,0,-1}));
 assert(!c.set_mirror(h,3,NAN,3,{0,0,-1}));
 assert(!c.set_mirror(h,3,7,0,{0,0,-1}));
 assert(!c.set_mirror(e,3,7,3,{0,0,-1}));
 assert(!c.set_mirror(h,8,7,3,{0,0,-1}));
 assert(!c.set_mirror(h,3,7,3,{NAN,0,0}));
 assert(!c.set_mirror(h,3,7,3,{0,1,0}));
 assert(c.set_mirror(h,3,7,3,{0,0,-1}));
 c.step(1.0/60);
 assert(c.unit(h)->target_handle==close&&c.unit(h)->position.z<0);
 c.despawn(close);c.step(1.0/60);
 assert(c.unit(h)->target_handle==e&&c.unit(h)->has_goal);
 c.set_pose(e,{0,0,2},0);c.combat.clear_events();
 std::set<int> choices;
 for(int i=0;i<900;++i){c.step(1.0/60);for(auto event:c.combat.events())if(event.action_index>=400){assert(event.source_id==-1&&event.target_id==1&&event.unit_kind==131&&event.ticket_id==h);if(choices.empty()){assert(i<60);assert(event.action_index==401);}choices.insert(event.action_index);}c.combat.clear_events();}
 assert(choices.size()==3);
 c.unit(h)->mirror_busy=true;auto before=c.unit(h)->position;
 for(int i=0;i<90;++i){c.step(1.0/60);for(auto event:c.combat.events())assert(event.action_index<400);c.combat.clear_events();}
 assert(length(c.unit(h)->position-before)<.001f);
 c.unit(h)->mirror_busy=false;c.despawn(e);before=c.unit(h)->position;
 for(int i=0;i<120;++i)c.step(1.0/60);
 assert(!c.unit(h)->target_handle&&!c.unit(h)->has_goal&&length(c.unit(h)->position-before)<.001f);
 auto later=c.spawn(3,0,0,{8,0,0},100000,.4);c.unit(later)->frozen=100;for(int i=0;i<13;++i)c.step(1.0/60);
 assert(c.unit(h)->target_handle==later&&c.unit(h)->has_goal);
 c.despawn(h);assert(!c.set_mirror(h,3,7,3,{0,0,-1}));
 auto next=c.spawn(-1,1,132,{0,0,0},100,.4);assert(next!=h&&c.unit(next)->mirror_actions==0);
 Crowd spread;spread.configure(32,16);spread.set_navigation(NavigationData{});assert(spread.combat.configure(kits()));
 auto target=spread.spawn(1,0,0,{0,0,0},100000,.4);spread.unit(target)->frozen=100;
 std::vector<Handle> copies;std::set<int64_t> attackers;
 for(int i=0;i<5;++i){
  float angle=float(i)*float(2*M_PI/5);Vec3 side{std::sin(angle),0,std::cos(angle)};
  auto copy=spread.spawn(-i-1,1,131,{10+float(i)*1.5f,0,12},100,.4);copies.push_back(copy);
  assert(spread.set_mirror(copy,3,7,3,side));
 }
 for(int i=0;i<600;++i){
  spread.step(1.0/60);
  for(auto event:spread.combat.events())if(event.action_index>=400){assert(event.target_id==1);attackers.insert(event.source_id);}
  spread.combat.clear_events();
 }
 assert(attackers.size()==5);
 for(size_t i=0;i<copies.size();++i)for(size_t j=i+1;j<copies.size();++j)assert(length(spread.unit(copies[i])->position-spread.unit(copies[j])->position)>2);
 spread.clear();assert(spread.combat.configure(kits()));copies.clear();
 for(int i=0;i<5;++i){
  auto enemy=spread.spawn(i+1,0,0,{float(i-2)*2,0,0},100000,.4);spread.unit(enemy)->frozen=100;
  auto copy=spread.spawn(-i-1,1,131,{float(i)*.1f,0,10},100,.4);copies.push_back(copy);
  assert(spread.set_mirror(copy,3,7,3,{0,0,1}));
 }
 spread.step(1.0/60);std::set<Handle> chosen;
 for(auto copy:copies)chosen.insert(spread.unit(copy)->target_handle);
 assert(chosen.size()==5&&!chosen.count(0));
 // A blocked approach must still allow attacking from the reachable side.
 NavigationData blocked;blocked.obstacle_min={{-1,0,-4}};blocked.obstacle_max={{1,5,-1.5f}};
 c.clear();c.set_navigation(blocked);assert(c.combat.configure(kits()));
 h=c.spawn(-1,1,131,{0,0,2},100,.4);e=c.spawn(1,0,0,{0,0,0},100000,.4);c.unit(e)->frozen=100;
 assert(c.set_mirror(h,3,7,3,{0,0,-1}));bool attacked=false;
 for(int i=0;i<60;++i){c.step(1.0/60);for(auto event:c.combat.events())if(event.action_index>=400)attacked=true;c.combat.clear_events();}
 assert(attacked&&c.unit(h)->position.z>0);
 // Permanent recruits defend their territory and survive rest.
 c.clear();c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 h=c.spawn(-1,1,131,{0,0,0},100,.4);c.set_guard(h,{0,0,0},18);
 assert(c.set_mirror(h,3,7,3,{0,0,-1}));
 e=c.spawn(1,0,0,{90,0,0},100000,1.3);c.unit(e)->frozen=100;
 c.step(1.0/60);
 assert(!c.unit(h)->target_handle&&!c.unit(h)->has_goal);
 c.set_pose(e,{12,0,0},0);c.unit(h)->think_left=0;c.step(1.0/60);
 assert(c.unit(h)->target_handle==e&&c.unit(h)->position.x>0);
 c.set_pose(h,{8,0,0},0);c.set_pose(e,{90,0,0},0);c.unit(h)->think_left=0;c.step(1.0/60);
 assert(!c.unit(h)->target_handle&&c.unit(h)->has_goal&&c.unit(h)->goal.x==0);
 c.unit(h)->mirror_busy=true;c.rest_allies();
 assert(c.valid(h)&&!c.valid(e)&&c.unit(h)->hp==100);
 assert(c.unit(h)->mirror_actions==3&&c.unit(h)->mirror_speed==7&&c.unit(h)->mirror_reach==3&&c.unit(h)->mirror_busy);
 c.unit(h)->mirror_busy=false;
 e=c.spawn(2,0,0,{-90,0,0},100000,1.3);c.unit(e)->frozen=100;
 c.step(1.0/60);assert(!c.unit(h)->target_handle&&c.unit(h)->has_goal);
 c.set_pose(e,{-12,0,0},0);c.unit(h)->think_left=0;c.step(1.0/60);assert(c.unit(h)->target_handle==e);
 // The normal temporary skill retains its local search and independent waiting.
 c.set_pose(e,{-90,0,0},0);
 auto temporary=c.spawn(-2,1,131,{0,0,0},100,.4);
 assert(c.set_mirror(temporary,3,7,3,{0,0,-1}));c.step(1.0/60);
 assert(!c.unit(temporary)->target_handle&&!c.unit(temporary)->has_goal);
 c.set_pose(e,{-65,0,0},0);
 c.unit(temporary)->mirror_spell_reach=80;
 bool offered_spell=false;
 for(int i=0;i<60;++i){
  c.step(1.0/60);
  for(const auto& event:c.combat.events())if(event.ticket_id==temporary&&event.action_index>=400){
   assert(event.amount==0&&event.target_id==2);offered_spell=true;
  }
  c.combat.clear_events();
 }
 assert(offered_spell&&c.unit(temporary)->target_handle==e&&c.unit(temporary)->position.x<0);
 c.despawn(e);
 ExternalTarget leader;leader.kind=0;leader.hp=100;leader.foot={12,0,0};leader.targetable=false;
 c.combat.set_targets({leader});
 auto follow_start=c.unit(temporary)->position.x;
 for(int i=0;i<60;++i)c.step(1.0/60);
 assert(!c.unit(temporary)->target_handle&&c.unit(temporary)->position.x>follow_start+2);
 // Hills and cover must allow pursuit without allowing attacks through a wall.
 NavigationData hill;hill.origin={-120,0,-120};hill.width=81;hill.spacing=3;
 hill.heights.resize(81*81);hill.covered.assign(81*81,1);
 for(int z=0;z<81;++z)for(int x=0;x<81;++x)hill.heights[z*81+x]=x*.25f;
 hill.obstacle_min={{-1,0,-12}};hill.obstacle_max={{1,30,12}};
 for(int hz:{20,30,60}){
  c.clear();c.set_navigation(hill);assert(c.combat.configure(kits()));
  h=c.spawn(-1,1,131,{-2,118.0f/12,0},100,.4);c.set_guard(h,c.unit(h)->position,18);
  assert(c.set_mirror(h,3,7,6,{0,0,-1}));
  e=c.spawn(1,0,0,{2,122.0f/12,0},100000,1.3);c.unit(e)->frozen=100;
  bool reached=false;
  for(int i=0;i<hz*30;++i){
   c.step(1.0/hz);
   for(auto event:c.combat.events())if(event.action_index>=400){
    assert(c.allied_terrain.ray_clear(c.unit(h)->position+Vec3{0,1,0},event.position));reached=true;
   }
   c.combat.clear_events();
  }
  assert(reached&&c.unit(h)->position.x>1);
 }
 std::cout<<"ARMY_MIRROR_RESULT failures=0 choices="<<choices.size()<<"\n";
}
