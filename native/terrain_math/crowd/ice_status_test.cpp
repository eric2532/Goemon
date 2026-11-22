#include "core.h"
#include "instance_buffers.h"
#include <cassert>
#include <iostream>
using namespace army;
int main(){
 Crowd c;c.configure(64,32);NavigationData nav;nav.origin={-240,0,-240};c.set_navigation(nav);
 KitData k;k.soldier_kinds={0};k.soldier_profiles={192,4.32f,11,2.5f,5,2.304f};
 k.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};k.status_bits={1,2,4,8,16,32,64};
 k.phase_ticks={20,10,24,30,30};k.contact_ticks={13,14,15,18};k.melee_from={0,1,0};k.melee_to={0,1,-1.44f};k.muzzle={0,1.44f,-.864f};k.bullet_speed=8.64f;k.bullet_life=3.34;k.bullet_tail=.576f;k.bullet_radius=.576f;
 for(int clip=0;clip<8;++clip){k.soldier_pose_meta.push_back(clip*3);k.soldier_pose_meta.push_back(3);for(int frame=0;frame<3;++frame)k.soldier_pose_rows.push_back(clip*3+frame);}
 assert(c.combat.configure(k));auto h=c.spawn(1,0,0,{0,0,0},192,1.3);Hit slow;slow.effect=2;slow.slow_factor=.4;slow.status_seconds=.3;
 assert(c.combat.hit(c,h,slow).accepted);assert(c.unit(h)->ice_visual()==0);c.step(.4);assert(c.unit(h)->ice_visual()==0);
 slow.effect=6;assert(c.combat.hit(c,h,slow).accepted);assert(c.unit(h)->ice_visual()==.42f);
 c.step(.4);assert(c.unit(h)->ice_visual()<0&&c.unit(h)->ice_thaw>0);c.step(2.1);assert(c.unit(h)->ice_visual()==0);
 Hit freeze;freeze.effect=1;freeze.status_seconds=1;
 assert(c.combat.hit(c,h,freeze).accepted);auto u=c.unit(h);assert(u->ice_visual()==1&&u->pose_row==21);
 c.step(.1);assert(u->pose_row==23&&u->frozen>0);auto position=u->position;c.step(.3);assert(u->pose_row==23&&length(u->position-position)==0);
 auto elapsed=u->ice_time;assert(c.combat.hit(c,h,freeze).accepted&&u->ice_time==elapsed);
 c.step(1.1);assert(u->ice_visual()<0&&u->hp==192);int thaw_events=0;for(const auto& e:c.combat.events())if(e.action_index==6000)++thaw_events;assert(thaw_events==2);
 c.combat.clear_events();c.step(2.1);assert(u->ice_visual()==0);assert(c.combat.events().empty());
 freeze.amount=1;freeze.status_seconds=3;assert(c.combat.hit(c,h,freeze).accepted);c.step(1.1);assert(u->frozen>0&&u->flash_left==0&&u->hp==191);
 c.despawn(h);auto clean=c.spawn(2,0,0,{0,0,0},192,1.3);assert(c.unit(clean)->ice_visual()==0&&c.unit(clean)->ice_time==0);
 for(float cold:{.42f,1.f,-1.f,-.42f}){
  InstanceRow row;row.kind=SLIME_KIND;row.team=0;row.pose_row=0;row.ice=cold;row.ice_time=.6f;row.status=cold==1?1:0;row.max_hp=row.hp=192;
  auto data=instance_buffers({row},{});assert(data.valid&&data.submitted==1);auto& b=data.batches[0].buffer;
  float fractional=b[13]-std::floor(b[13]);float decoded=fractional>.1875f?-(fractional-.25f)*8:fractional*8;
  assert(std::abs(decoded-cold)<.00001f);if(row.status&1)assert(int(b[13])%8==3&&b[14]==.6f);
 }
 std::cout<<"ICE_STATUS_NATIVE_RESULT failures=0\n";
}
