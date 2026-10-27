#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
namespace army {
struct DarkLuminaTest {
static KitData kit(){
 KitData k;k.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};k.status_bits={1,2,4,8,16,32,64};k.phase_ticks={19,24,170,98,90};k.contact_ticks={13,14,15,18};k.bullet_speed=8.64;k.bullet_life=4;k.bullet_radius=.2;
 k.dark_lumina={13,47,8.5,6,62,134,54,51.84,3.5,5.85,400.0/4096*2*M_PI,72,.3,0,10.5,-9.3,3,3,160,320,720,2,2};
 for(int frame=0;frame<28;++frame){k.dark_lumina_spin.push_back(100+std::min(frame,26));k.dark_lumina_spin.push_back(200+std::min(frame,26));k.dark_lumina_spin.push_back(((frame>=4?-112:0)+240*std::clamp(frame-6,0,18))*2*M_PI/4096);}
 for(int i=0;i<8;++i){k.soldier_pose_meta.push_back(0);k.soldier_pose_meta.push_back(1);}k.soldier_pose_rows={0};
 k.soldier_kinds={17};k.soldier_profiles={5000,21.6,400,42,2.8,17.28};
 k.enemy_kits={51,24,170,98,90,13,14,15,18,0,1.728f,-5.184f,0,2.88f,-29.376f,4.8,0,0,0,-12.096f,0,-8.64f,12.096f,15.552f,6.048f,-1};return k;
}
static void run(){
 for(double dt:{1.0/20,1.0/30,1.0/60}){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,17,{0,0,0},5000,12.096);auto victim=c.spawn(2,1,12,{0,0,-3},100000,.4);
  auto u=c.unit(h);u->target_handle=victim;u->landing_goal={0,0,-10};
  c.combat.lumina_begin(*u,FIRE);int releases=0,maxshots=0;double fire_elapsed=0;
  for(int i=0;i<250;++i){c.step(dt);fire_elapsed+=dt;for(auto e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index==207){assert(std::abs(fire_elapsed-(47+8.5*releases)/60)<=dt+.0001);++releases;}c.combat.clear_events();maxshots=std::max(maxshots,int(c.combat.active_projectiles().size()));if(!u->action_active)break;}
  assert(releases==6&&maxshots>=2);
  c.combat.lumina_begin(*u,FIRE);c.combat.lumina_advance(c,*u,47.0/60);
  const auto& shot=c.combat.active_projectiles().back();assert(std::abs(shot.speed*shot.life-181.44)<.001&&std::abs(shot.radius-5.85)<.001&&shot.damage==200);
  c.combat.lumina_begin(*u,RELOAD);int pulses=0;float high=0;bool plunged=false;
  for(int i=0;i<400;++i){c.step(dt);high=std::max(high,u->position.y);plunged|=u->air_phase&&u->special_time<=-160;for(auto e:c.combat.events())if(e.kind==STATUS_EVENT&&(e.action_index==208||e.action_index==209)){assert(!u->air_phase&&u->position.y<.01);++pulses;}c.combat.clear_events();if(!u->action_active)break;}
  std::cerr<<"slam dt="<<dt<<" pulses="<<pulses<<" high="<<high<<" y="<<u->position.y<<" phase="<<u->phase_tick<<" air="<<u->air_phase<<"\n";
  assert(pulses==2&&plunged&&high>30&&high<45&&u->position.y<.01);
  c.set_pose(h,{0,0,0},0);c.set_pose(victim,{0,0,-42},0);u->target_handle=victim;c.combat.lumina_begin(*u,MELEE_A);bool grabbed=false;int contacts=0;double first_contact=0,elapsed=0;
  for(int i=0;i<500;++i){c.step(dt);elapsed+=dt;grabbed|=u->soldier_phase==MELEE_B;for(auto e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE||e.kind==DAMAGE&&e.target_id==2){++contacts;if(first_contact==0)first_contact=elapsed;}c.combat.clear_events();if(!u->action_active)break;}
  assert(grabbed&&contacts==3);assert(std::abs(first_contact-13.0/90)<=dt+.0001);assert(elapsed<2.5);
  c.combat.lumina_begin(*u,FIRE);Hit damage;damage.amount=1;c.combat.hit(c,h,damage);assert(!u->action_active);
  int before=int(c.combat.active_projectiles().size());for(int i=0;i<10;++i)c.step(dt);assert(int(c.combat.active_projectiles().size())<=before);
  c.clear();assert(c.combat.active_projectiles().empty());
  h=c.spawn(1,0,17,{0,0,0},5000,12.096);victim=c.spawn(2,1,12,{0,0,-24},100000,.4);u=c.unit(h);
  auto outside=c.spawn(3,1,12,{0,0,-31},100000,.4);
  for(int sign:{-1,1}){
   c.unit(victim)->invuln=0;u->yaw=0;u->landing_goal={float(sign),0,-10};c.combat.lumina_begin(*u,LUMINA_SPIN);assert(u->chain_count==sign);
   double hp=c.unit(victim)->hp;double total=0;int contacts=0;
   while(u->soldier_phase==LUMINA_SPIN){
    c.combat.clear_events();c.combat.lumina_advance(c,*u,dt);total+=dt;
    c.combat.pose_frame(*u);
    if(u->soldier_phase==LUMINA_SPIN)assert(u->pose_row>=(sign==1?100:200)&&u->pose_row<=(sign==1?126:226));
    for(auto e:c.combat.events())if(e.kind==DAMAGE&&e.target_id==2){++contacts;assert(total+.000001>=7.0/30&&total<7.0/30+dt+.00001);}
   }
   assert(contacts==1&&c.unit(victim)->hp==hp-400&&c.unit(outside)->hp==100000);
   assert(std::abs(u->yaw-sign*4208.0*2*M_PI/4096)<.00001);
  }
  u->landing_goal={0,0,-10};c.combat.lumina_begin(*u,LUMINA_SPIN);c.combat.lumina_advance(c,*u,3.0/30);
  damage.amount=1;c.combat.hit(c,h,damage);assert(!u->action_active&&u->action!=LUMINA_SPIN_ACTION);
  u->stun=0;u->action=0;u->walk_phase=0;u->air_phase=0;u->velocity={17.28f,0,0};c.combat.clear_events();
  int steps=0;
  for(int i=0;i<int(2/dt+.5);++i){u->live_delta=dt;c.combat.animation_step(c,dt);for(auto e:c.combat.events())if(e.action_index==214)++steps;c.combat.clear_events();}
  assert(steps==4);
  u->live_delta=0;c.combat.animation_step(c,1);assert(c.combat.events().empty());
  c.clear();
 }
 {
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  for(int i=0;i<12;++i){auto h=c.spawn(i+1,0,17,{float((i%4)*40),0,float((i/4)*40)},5000,12.096);c.combat.lumina_begin(*c.unit(h),RELOAD);}
  std::set<int> first,second;
  for(int frame=0;frame<240;++frame){c.step(1.0/60);for(auto e:c.combat.events())if(e.kind==STATUS_EVENT){if(e.action_index==208)first.insert(e.source_id);if(e.action_index==209)second.insert(e.source_id);}c.combat.clear_events();}
  std::cerr<<"simultaneous pulses first="<<first.size()<<" second="<<second.size()<<"\n";assert(first.size()==12&&second.size()==12);
 }
 {
  Crowd c;c.configure(128,128);assert(c.combat.configure(kit()));c.set_navigation(NavigationData{});
  auto h=c.spawn(1,0,17,{0,0,0},5000,12.096);auto u=c.unit(h);
  auto first=c.spawn(2,1,12,{0,0,-48},10000,.4),second=c.spawn(3,1,12,{0,0,-65},10000,.4),outside=c.spawn(4,1,12,{0,0,-75},10000,.4);
  c.combat.lumina_begin(*u,RELOAD);u->phase_tick=53;c.combat.lumina_advance(c,*u,1.0/30);
  assert(c.unit(first)->hp==9600&&c.unit(second)->hp==10000&&c.unit(outside)->hp==10000);
  c.combat.lumina_advance(c,*u,10.0/30);
  assert(c.unit(second)->hp==9600&&c.unit(outside)->hp==10000);
 }
 auto bad=kit();bad.dark_lumina_spin.clear();assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina_spin[0]=1e30f;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina_spin[1]=.5f;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[17]=0;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[2]=100;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[3]=6.5;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[21]=0;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[22]=0;assert(!valid_kit_data(bad));
 bad=kit();bad.dark_lumina[5]=171;assert(!valid_kit_data(bad));
 std::cout<<"DARK_LUMINA_NATIVE_PASS rates=3 volley=6_pairs fire_tempo=2 damage=400 spin_reach=28.8 slam=2 grab=3_contacts claw_tempo=3 body_scale=3 fire_range=181.44 fire_radius=5.85 jump_height=30_to_45 cancellation=ok spin=both_directions spin_contact=once walk=4_steps_per_2_cycles\n";
}
};
}
int main(){army::DarkLuminaTest::run();}
