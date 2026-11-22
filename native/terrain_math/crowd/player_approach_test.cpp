#include "core.h"
#include <cassert>
#include <chrono>
#include <iostream>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={SLIME_KIND,BEAR_KIND,HOUND_KIND};
 for(int i=0;i<3;++i)d.soldier_profiles.insert(d.soldier_profiles.end(),{5000,3,30,2,6,6});
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};d.bullet_speed=8.64;d.bullet_life=3.34;d.bullet_tail=.576;d.bullet_radius=.576;
 for(auto kind:d.soldier_kinds){auto& rows=kind==HOUND_KIND?d.hound_attacks:kind==BEAR_KIND?d.bear_attacks:d.slime_attacks;rows.resize(pet_skin_count(kind)*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<rows.size();i+=HOUND_TIMELINE_STRIDE){rows[i]=30;rows[i+1]=1;rows[i+2]=10;rows[i+3]=kind==HOUND_KIND?143:112;}}
 return d;
}
static ExternalTarget hero(){ExternalTarget t;t.kind=0;t.hp=100000;return t;}
static Handle enemy(Crowd& c,int id,Vec3 p,int kind=SLIME_KIND){
 auto h=c.spawn(id,0,kind,p,5000,.3);assert(h);c.unit(h)->external_kind=0;return h;
}
static void setup(Crowd& c,KitData d=kits()){
 c.configure(1200,1200);NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};c.set_navigation(nav);
 assert(c.combat.configure(d));c.combat.set_targets({hero()});
}
static float pace(int others,float distance,int hz,int kind=SLIME_KIND,float slow=1){
 Crowd c;setup(c);
 for(int i=0;i<others;++i){float a=float(i)*6.283185f/std::max(1,others);enemy(c,i+1,{24*std::cos(a),0,24*std::sin(a)});}
 auto h=enemy(c,100,{0,0,distance},kind);auto u=c.unit(h);u->slow_factor=slow;u->slow_left=10;
 auto start=u->position;c.step(1.0/hz);float moved=length(u->position-start)*hz;
 assert(std::abs(moved-u->move_speed*slow)<.04);return u->move_speed;
}
int main(){
 int checks=0;
 for(int hz:{20,30,60})for(int kind:{SLIME_KIND,BEAR_KIND,HOUND_KIND}){
  assert(std::abs(pace(0,160,hz,kind)-9)<.01);++checks;
  assert(std::abs(pace(0,20,hz,kind)-3)<.01);++checks;
  assert(std::abs(pace(10,20,hz,kind)-1.05)<.01);++checks;
  assert(std::abs(pace(10,80,hz,kind)-5.025)<.04);++checks;
  assert(std::abs(pace(10,160,hz,kind)-9)<.01);++checks;
  assert(std::abs(pace(10,20,hz,kind,.5)-1.05)<.01);++checks;
  float previous=10;
  for(float distance:{160,120,100,80,60,40,28,20}){float speed=pace(10,distance,hz,kind);assert(speed<=previous+.01&&speed>=1.04);previous=speed;++checks;}
  previous=4;
  for(int count:{0,1,3,5,8,10,20}){float speed=pace(count,20,hz,kind);assert(speed<=previous+.01&&speed>=1.04);previous=speed;++checks;}
 }
 {
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,30});std::vector<Handle> pack;
  for(int i=0;i<10;++i)pack.push_back(enemy(c,i+1,{24,0,float(i)*.1f}));
  c.combat.before_move(c,1.0/60);assert(std::abs(c.unit(h)->move_speed-1.05)<.01);++checks;
  for(auto g:pack)c.despawn(g);
  c.combat.before_move(c,1.0/60);assert(std::abs(c.unit(h)->move_speed-3)<.01);++checks;
  // Distant pursuers and enemies on another floor cannot slow the player encounter.
  for(int i=0;i<10;++i)enemy(c,i+1,{24,i<5?10.f:0.f,i<5?0.f:100.f});
  c.combat.before_move(c,1.0/60);assert(std::abs(c.unit(h)->move_speed-3)<.01);++checks;
  c.unit(h)->frozen=1;auto before=c.unit(h)->position;c.step(1.0/60);assert(length(c.unit(h)->position-before)==0);++checks;
  c.clear();h=enemy(c,100,{0,0,30});c.combat.set_targets({hero()});c.combat.before_move(c,1.0/60);assert(std::abs(c.unit(h)->move_speed-3)<.01);++checks;
  auto hidden=hero();hidden.targetable=false;c.combat.set_targets({hidden});c.combat.before_move(c,1.0/60);assert(c.unit(h)->external_kind<0&&!c.unit(h)->has_goal);++checks;
 }
 // Boss patterns, non-player targets, and patrol leashes keep their existing pace.
 for(int scenario=0;scenario<7;++scenario){
  auto d=kits();if(scenario==0)d.habaru_bears=true;if(scenario==1)d.zombie_boss=true;if(scenario==2)d.grave_boss=true;if(scenario==3)d.ruby_boss=true;if(scenario==4)d.undersea_boss=true;
  Crowd c;setup(c,d);auto h=enemy(c,100,{0,0,160});auto u=c.unit(h);u->pose_row=scenario==2?2:0;
  if(scenario==5){auto t=hero();t.kind=3;c.combat.set_targets({t});u->external_kind=3;}
  if(scenario==6){c.set_guard(h,u->position,12);c.combat.before_move(c,1.0/60);assert(u->external_kind<0);++checks;continue;}
  c.combat.before_move(c,1.0/60);assert(std::abs(u->move_speed-3)<.01);++checks;
 }
 // Exploration patrols spot a little farther without extending their home boundary.
 for(int hz:{20,30,60})for(float radius:{8.f,14.f,17.f})for(int scenario=0;scenario<10;++scenario){
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,0});auto u=c.unit(h);c.set_guard(h,{0,0,0},radius);
  auto t=hero();t.foot={radius*(scenario==1?1.201f:scenario==2?1.599f:scenario==3?1.601f:1.199f),0,0};
  u->external_kind=scenario==2||scenario==3||scenario==4?0:-1;
  if(scenario==4){u->position={radius,0,0};t.foot={radius*2.01f,0,0};}
  if(scenario==5){u->position={radius*2.01f,0,0};t.foot={radius,0,0};}
  if(scenario==6||scenario==7){
   NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};
   nav.obstacle_min={{radius*.5f,0,-2}};nav.obstacle_max={{radius*.6f,4,2}};c.set_navigation(nav);
   if(scenario==7){u->retaliation=4;u->retaliation_source=0;}
  }
  if(scenario==8)t.targetable=false;
  if(scenario==9)t.hp=0;
  c.combat.set_targets({t});c.combat.before_move(c,1.0/hz);
  assert((u->external_kind==0)==(scenario==0||scenario==2||scenario==7));++checks;
 }
 // Kill awareness grows at each rate; home limits and blocked/hidden players stay authoritative.
 for(int hz:{20,30,60})for(int kills:{0,5,42,1000000})for(int scenario=0;scenario<6;++scenario){
  Crowd c;setup(c);auto h=enemy(c,100,{});auto u=c.unit(h);c.set_guard(h,{},20);
  auto t=hero();t.aggro_kills=kills;t.foot={30,0,0};u->external_kind=-1;
  if(scenario==1)t.foot.x=40.01f;
  if(scenario==2){u->position={40.01f,0,0};t.foot.x=30;}
  if(scenario==3)t.targetable=false;
  if(scenario==4)t.hp=0;
  if(scenario==5){NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};nav.obstacle_min={{10,0,-5}};nav.obstacle_max={{12,4,5}};c.set_navigation(nav);}
  c.combat.set_targets({t});c.combat.before_move(c,1.0/hz);
  assert((u->external_kind==0)==(kills>=42&&scenario==0));++checks;
 }
 // Once a strike begins, changing the crowd cannot cancel or retime its contact.
 {
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,1});auto u=c.unit(h);u->yaw=0;
  c.step(1.0/60);assert(u->action_active);auto action=u->action;auto tick=u->action_time;
  for(int i=0;i<10;++i)enemy(c,i+1,{20,0,float(i)});
  c.step(1.0/60);assert(u->action_active&&u->action==action&&u->action_time>tick);++checks;
 }
 // Same 928-enemy decision workload for before/after diagnostics; no timing gate.
 {
  Crowd c;setup(c);for(int i=0;i<928;++i)enemy(c,i+1,{float(i%32)*8-124,0,float(i/32)*8-112});
  for(int i=0;i<10;++i)c.combat.before_move(c,1.0/60);
  auto start=std::chrono::steady_clock::now();
  for(int i=0;i<120;++i)c.combat.before_move(c,1.0/60);
  std::cout<<"PLAYER_APPROACH_DECISION_MS "<<std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count()/120<<"\n";
 }
 std::cout<<"PLAYER_APPROACH_RESULT checks="<<checks<<" failures=0\n";
}
