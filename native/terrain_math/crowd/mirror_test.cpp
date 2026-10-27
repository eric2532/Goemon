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
 auto later=c.spawn(3,0,0,{8,0,0},100000,.4);c.unit(later)->frozen=100;c.step(1.0/60);
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
 std::cout<<"ARMY_MIRROR_RESULT failures=0 choices="<<choices.size()<<"\n";
}
