#include "core.h"
#include <cassert>
#include <iostream>
using namespace army;
static int checks=0;
#define expect(ok) (assert(ok), ++checks)
static KitData kits(){
 KitData d;d.soldier_kinds={SLIME_KIND,BEAR_KIND,HOUND_KIND};
 for(int i=0;i<3;++i)d.soldier_profiles.insert(d.soldier_profiles.end(),{5000,3,30,2,6,6});
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};d.bullet_speed=8.64;d.bullet_life=3.34;d.bullet_tail=.576;d.bullet_radius=.576;
 for(auto kind:d.soldier_kinds){auto& rows=kind==HOUND_KIND?d.hound_attacks:kind==BEAR_KIND?d.bear_attacks:d.slime_attacks;rows.resize(pet_skin_count(kind)*8*HOUND_TIMELINE_STRIDE);
  for(size_t i=0;i<rows.size();i+=HOUND_TIMELINE_STRIDE){rows[i]=30;rows[i+1]=1;rows[i+2]=10;rows[i+3]=10135;}}
 return d;
}
static ExternalTarget hero(){ExternalTarget t;t.kind=0;t.hp=100000;return t;}
static void setup(Crowd& c,KitData d=kits()){
 c.configure(1200,1200);NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};c.set_navigation(nav);
 expect(c.combat.configure(d));c.combat.set_targets({hero()});
}
static Handle enemy(Crowd& c,int id,Vec3 p,int kind=SLIME_KIND){
 auto h=c.spawn(id,0,kind,p,5000,.3);expect(h!=0);c.unit(h)->external_kind=0;return h;
}
static std::vector<Handle> pack(Crowd& c,int count){
 std::vector<Handle> result;
 for(int i=0;i<count;++i){float a=float(i)*6.283185f/std::max(1,count);auto h=enemy(c,i+1,{8*std::cos(a),0,8*std::sin(a)});c.unit(h)->frozen=1000;result.push_back(h);}
 return result;
}
int main(){
 for(int hz:{20,30,60})for(int kind:{SLIME_KIND,BEAR_KIND,HOUND_KIND})for(int count:{1,3,4,6,8,30}){
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,1},kind);auto others=pack(c,count-1);
  const double pressure=std::clamp((count-3)/5.,0.,1.);
  const double pause=count<=3?0:1+.25*std::min(count-4,4);
  std::vector<double> contacts,starts;double first_wait=-1;
  for(int tick=0;tick<hz*5;++tick){
   c.combat.clear_events();c.step(1./hz);auto u=c.unit(h);
   if(tick==0)expect(std::abs(u->crowd_attack_pressure-pressure)<1e-8);
   if(!u->action_active&&first_wait<0)first_wait=u->crowd_attack_wait;
   for(const auto& e:c.combat.events())if(e.source_id==100){
    if(e.kind==ATTACK_STARTED)starts.push_back(double(tick)/hz);
    if(e.kind==EXTERNAL_DAMAGE){expect(std::abs(e.amount-30*(1+.5*pressure))<1e-6);contacts.push_back(double(tick)/hz);}
   }
  }
  expect(contacts.size()>=2&&starts.size()>=2);
  expect(first_wait>=pause-1./hz-1e-8&&first_wait<=pause+1e-8);
  expect(std::abs(contacts[0]-1./3)<1./hz+1e-8);
  expect(contacts[1]-contacts[0]>=1+pause-1./hz-1e-8);
  expect(contacts[1]-contacts[0]<=1+pause+2./hz+1e-8);
 }
 // Distant, upper-floor, pet-engaged and boss enemies cannot inflate pressure.
 for(int scenario=0;scenario<6;++scenario){
  Crowd c;auto d=kits();if(scenario==4)d.habaru_bears=true;setup(c,d);
  auto h=enemy(c,100,{0,0,1},HOUND_KIND);auto others=pack(c,10);
  ExternalTarget pet;pet.id=-20;pet.kind=3;pet.hp=1000;pet.foot={8,0,0};
  c.combat.set_targets({hero(),pet});
  auto ally=scenario==3?c.spawn(-20,1,0,{8,0,0},1000,.3):0;
  for(auto other:others){auto u=c.unit(other);
   if(scenario==0)u->position={0,0,12.01f};
   if(scenario==1)u->position.y=3.51f;
   if(scenario==2){u->external_kind=3;u->external_target=-20;}
   if(scenario==3)u->target_handle=ally;
   if(scenario==4)u->pose_row=0;
   if(scenario==5)c.despawn(other);
  }
  c.step(1./60);expect(c.unit(h)->crowd_attack_pressure==0);
 }
 // A committed swing retains its original contact and damage after the crowd clears.
 for(int hz:{20,30,60}){
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,1});auto others=pack(c,7);c.step(1./hz);
  expect(c.unit(h)->crowd_attack_pressure==1);for(auto other:others)c.despawn(other);
  bool hit=false;
  for(int tick=0;tick<hz&&!hit;++tick){c.combat.clear_events();c.step(1./hz);
   for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){expect(e.amount==45);hit=true;}}
  expect(hit);
  for(int tick=0;tick<hz*2;++tick)c.step(1./hz);
  expect(c.unit(h)->crowd_attack_wait==0&&c.unit(h)->crowd_attack_pressure==0);
  c.despawn(h);auto reused=enemy(c,101,{0,0,1});expect(c.unit(reused)->crowd_attack_wait==0&&c.unit(reused)->crowd_attack_pressure==0);
  c.clear();c.combat.set_targets({hero()});h=enemy(c,102,{0,0,1});c.step(1./hz);expect(c.unit(h)->crowd_attack_pressure==0);
 }
 // Waiting never prevents chasing an escaped player or makes pet hits stronger.
 {
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,1});auto others=pack(c,7);c.step(1./60);
  auto u=c.unit(h);u->action_active=false;u->crowd_attack_wait=2;
  c.set_pose(h,{0,0,7},0);c.combat.before_move(c,1./60);expect(u->has_goal&&u->crowd_attack_wait>0);
  ExternalTarget pet;pet.id=-20;pet.kind=3;pet.hp=1000;c.combat.set_targets({hero(),pet});
  u->external_kind=3;u->external_target=-20;u->think_left=10;c.set_pose(h,{0,0,1},0);
  c.step(1./60);expect(u->crowd_attack_wait==0&&u->crowd_attack_pressure==0);
  bool hit=false;for(int i=0;i<60&&!hit;++i){c.combat.clear_events();c.step(1./60);for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.source_id==100){expect(e.external_kind==3&&e.amount==30);hit=true;}}
  expect(hit);
 }
 // A later charge cannot inherit an ordinary swing's stored damage bonus.
 {
  Crowd c;setup(c);auto h=enemy(c,100,{0,0,1});pack(c,7);c.step(1./60);auto u=c.unit(h);
  expect(u->crowd_attack_pressure==1);u->action=ENEMY_CHARGE_RUSH;u->action_active=true;u->primary_hit=false;
  u->action_time=0;u->dash_previous=u->position;u->dash_direction={0,0,-1};u->live_delta=1./60;
  c.combat.clear_events();c.combat.after_move(c,1./60);
  bool hit=false;for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.source_id==100){expect(e.amount==30);hit=true;}
  expect(hit);
 }
 std::cout<<"CROWD_PRESSURE_RESULT checks="<<checks<<" failures=0\n";
}
