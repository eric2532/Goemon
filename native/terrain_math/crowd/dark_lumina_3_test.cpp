#include "core.h"
#include "../../../tests/forest-shrine/reference/finale_kit.h"
#include <cassert>
#include <iostream>
#include <chrono>
using namespace army;
KitData kit(){
 KitData k;k.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};k.status_bits={1,2,4,8,16,32,64};k.phase_ticks={40,24,40,40,24};k.contact_ticks={28,14,15,18};k.bullet_speed=8.64;k.bullet_life=4;k.bullet_radius=.2;
 k.soldier_kinds={18};k.soldier_profiles={18000,5.4,65,72,5,2.88};
 k.enemy_kits={40,24,40,40,24,28,14,15,18,0,3.456f,-1.296f,0,4.32f,-12.096f,2.1f,0,0,0,-1.65f,0,-1.5f,1.65f,7.5f,1.5f,-1};
 for(int i=0;i<8;++i){k.soldier_pose_meta.push_back(0);k.soldier_pose_meta.push_back(1);}k.soldier_pose_rows={0};
 finale_fixture(k);return k;
}
int main(){
 const int releases[]={3,22,6,32,1,10};
 for(double dt:{1.0/20,1.0/30,1.0/60})for(int move=0;move<6;++move){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;auto data=kit();assert(c.combat.configure(data));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,1.3);auto victim=c.spawn(2,1,12,{0,0,-5},100000,.4);
  auto u=c.unit(h);u->target_handle=victim;u->landing_goal={0,0,-5};u->action=300+move;u->action_active=true;
  int count=0,peak=0;float peak_y=0;bool secondary=false;
  for(int i=0;i<1500;++i){
   c.step(dt);peak_y=std::max(peak_y,u->position.y);
   for(auto e:c.combat.events())if(e.kind==STATUS_EVENT&&e.unit_kind==18&&e.action_index>=311&&e.action_index<=317){++count;if(move==0)assert(e.source_tick==88||e.source_tick==127||e.source_tick==139);}
   c.combat.clear_events();peak=std::max(peak,int(c.combat.active_projectiles().size()));
   for(auto& shot:c.combat.active_projectiles())secondary|=shot.power&&shot.effect_kind==move;
   if(!u->action_active)break;
  }
  assert(count==releases[move]);assert(!u->action_active);assert(u->pose_row>=0);
  if(move==2||move==3)assert(secondary);
  assert(peak<128);if(move==4)assert(peak_y>1);
  if(move==0)assert(c.unit(victim)->hp<100000);
  u->action=303;u->action_active=true;u->phase_tick=0;Hit hit;hit.amount=1;c.combat.hit(c,h,hit);assert(!u->action_active);
  c.clear();assert(c.combat.active_projectiles().empty());
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;auto data=kit();assert(data.finale_scale==3);assert(c.combat.configure(data));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto near=c.spawn(2,1,12,{0,0,-48},10000,.4);auto far=c.spawn(3,1,12,{0,0,-52},10000,.4);
  auto u=c.unit(h);u->action=301;u->action_active=true;u->phase_tick=59;u->target_handle=near;
  c.step(1.0/30);assert(c.unit(near)->hp==10000);assert(c.unit(far)->hp==10000);assert(c.unit(near)->knockback.z<-20);
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto victim=c.spawn(2,1,12,{0,0,-5},10000,.4);
  auto u=c.unit(h);u->action=301;u->action_active=true;u->phase_tick=59;u->target_handle=victim;
  c.step(1.0/30);assert(c.unit(victim)->knockback.z<-20);
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto victim=c.spawn(2,1,12,{6,0,-30},10000,.4);
  auto u=c.unit(h);u->action=301;u->action_active=true;u->phase_tick=59;u->target_handle=victim;
  for(int i=0;i<40;++i)c.step(1.0/60);
  assert(c.unit(victim)->hp<10000);
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto near=c.spawn(2,1,12,{80,0,0},10000,.4);auto far=c.spawn(3,1,12,{86,0,0},10000,.4);
  auto u=c.unit(h);u->action=304;u->action_active=true;u->phase_tick=39;u->sweep_marker=1;u->target_handle=near;
  c.step(1.0/30);assert(std::abs(c.unit(near)->hp-(10000-65*7.5))<.001);assert(c.unit(far)->hp==10000);
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto victim=c.spawn(2,1,12,{0,.1f,-18},10000,.4);
  auto u=c.unit(h);u->action=300;u->action_active=true;u->phase_tick=87;u->target_handle=victim;
  for(int i=0;i<25;++i)c.step(1.0/60);
  assert(c.unit(victim)->hp<10000);
 }
 for(float yaw:{0.f,float(M_PI/4),float(M_PI/2),float(5*M_PI/4)})for(int tick:{88,127,139}){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto victim=c.spawn(2,1,12,{100,0,-100},10000,.4);
  auto u=c.unit(h);u->yaw=yaw;u->action=300;u->action_active=true;u->phase_tick=tick-1;u->target_handle=victim;
  c.step(1.0/30);assert(c.combat.active_projectiles().size()==1);
  const auto& p=c.combat.active_projectiles()[0];assert(p.power==(tick>88));assert(p.yaw_offset==0);
  assert(dot(p.direction,Vec3{-std::sin(yaw),0,-std::cos(yaw)})>.9999f);
  assert(std::abs(p.position.y-(tick==88?.075:3.9))<.001);
 }
 for(int tick:{88,127,139}){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);auto victim=c.spawn(2,1,12,{0,0,-8},10000,.4);
  auto u=c.unit(h);u->action=300;u->action_active=true;u->phase_tick=tick-1;u->target_handle=victim;
  bool impact=false;
  for(int i=0;i<6;++i){
   c.step(1.0/60);
   for(const auto& e:c.combat.events())if(e.kind==PROJECTILE_IMPACT&&e.unit_kind==18&&e.action_index==0){impact=true;assert(e.source_tick==(tick>88?1:0));}
   c.combat.clear_events();
  }
  assert(impact&&c.unit(victim)->hp<10000);
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,18,{0,0,0},18000,3.9);std::vector<Handle> victims;
  for(int i=0;i<3;++i)victims.push_back(c.spawn(10+i,1,12,{float((i-1)*15),0,-30},10000,.4));
  c.spawn(20,1,12,{0,0,10},10000,.4);c.spawn(21,1,12,{0,0,-70},10000,.4);
  auto u=c.unit(h);u->action=301;u->action_active=true;u->phase_tick=59;u->target_handle=victims[1];
  c.step(1.0/30);assert(c.combat.active_projectiles().size()==7);assert(u->action_hits.size()==3);
  for(const auto& p:c.combat.active_projectiles())assert(std::abs(p.damage-65*2.25*.5)<.001);
  for(int i=0;i<12;++i)c.step(1.0/30);
  assert(u->action_hits.size()==3);int fresh=0;for(const auto& p:c.combat.active_projectiles())if(p.id>=8)++fresh;assert(fresh==4);
  for(int i=0;i<45;++i)c.step(1.0/30);
  for(auto target:victims)assert(c.unit(target)->hp<10000);
 }
 {
  Crowd c;c.configure(256,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  std::vector<Handle> bosses;
  for(int i=0;i<6;++i)bosses.push_back(c.spawn(i+1,0,18,{float(i*2-5),0,0},18000,3.9));
  for(int i=0;i<96;++i)c.spawn(100+i,1,12,{float((i%12-5.5)*4),0,float(-18-(i/12)*3)},100000,.4);
  size_t peak=0;double worst=0;
  for(int repeat=0;repeat<3;++repeat){
   for(auto h:bosses){auto u=c.unit(h);u->action=301;u->action_active=true;u->phase_tick=59;u->action_hits.clear();}
   for(int tick=0;tick<360;++tick){auto begin=std::chrono::steady_clock::now();c.step(1.0/60);worst=std::max(worst,std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count());peak=std::max(peak,c.combat.active_projectiles().size());c.combat.clear_events();}
  }
  assert(peak>=96&&peak<2000);
  std::cout<<"WIND_ARMY_STRESS bosses=6 allies=96 repeats=3 projectile_peak="<<peak<<" step_max_ms="<<worst<<"\n";
 }
 for(double dt:{1.0/20,1.0/30,1.0/60})for(int scenario:{0,1,2}){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;auto data=kit();data.finale_ranges[0]=.001;
  if(scenario==0)data.finale_shots[9]=.1;
  assert(c.combat.configure(data));NavigationData nav;
  if(scenario==2)for(int i=0;i<6;++i){
   float x=float(i*20-50);
   nav.ray_min.insert(nav.ray_min.end(),{{x-5.5f,0,94.5f},{x+5,0,94.5f},{x-5,0,94.5f},{x-5,0,105}});
   nav.ray_max.insert(nav.ray_max.end(),{{x-5,5,105.5f},{x+5.5f,5,105.5f},{x+5,5,95},{x+5,5,105.5f}});
  }
  c.set_navigation(nav);std::vector<Handle> bosses;
  for(int i=0;i<6;++i){auto h=c.spawn(i+1,0,18,{float(i*20-50),0,0},18000,3.9);bosses.push_back(h);auto u=c.unit(h);u->action=302;u->action_active=true;u->phase_tick=59.9;u->landing_goal={float(i*20-50),0,100};}
  int parents=0,children=0,born=0;size_t peak=0;
  for(int tick=0;tick<int(7/dt);++tick){
   c.step(dt);
   if(tick==0)for(auto h:bosses){auto u=c.unit(h);u->action_active=false;u->action=0;u->recovery_left=100;}
   for(const auto& shot:c.combat.active_projectiles())if(shot.owner_kind==18&&shot.effect_kind==2&&shot.power){assert(std::abs(shot.damage-65*3.5*.5)<.001);assert(shot.direction.y==0);assert(std::abs(length(shot.direction)-1)<.0001);if(shot.age<=dt+1e-6)++born;}
   for(const auto& e:c.combat.events())if(e.kind==PROJECTILE_IMPACT&&e.unit_kind==18&&e.action_index==2){if(e.source_tick)++children;else ++parents;}
   peak=std::max(peak,c.combat.active_projectiles().size());c.combat.clear_events();
  }
  assert(parents==(scenario==0?0:6)&&born==(scenario==0?0:30)&&children==(scenario==2?30:0)&&c.combat.active_projectiles().empty());assert(peak<=30);
  std::cout<<"WATER_CONTACT_PASS bosses=6 scenario="<<scenario<<" parent_pops="<<parents<<" child_pops="<<children<<" rate="<<1/dt<<" peak="<<peak<<"\n";
 }
 auto bad=kit();bad.finale_meta[0]=-1;assert(!valid_kit_data(bad));bad=kit();bad.finale_frames[1]=8;assert(!valid_kit_data(bad));bad=kit();bad.finale_scale=0;assert(!valid_kit_data(bad));bad=kit();bad.finale_ranges.clear();assert(!valid_kit_data(bad));bad=kit();bad.finale_ranges[0]=-1;assert(!valid_kit_data(bad));
 std::cout<<"DARK_LUMINA_3_NATIVE_PASS six_moves rates=20,30,60 secondary_effects cancellation cleanup validation\n";
}
