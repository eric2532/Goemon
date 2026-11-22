#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
#include <map>
using namespace army;
#include "pet_skills_fixture.h"
int main(){
 int checks=0;std::set<int> choices;
 for(int hz:{20,30,60})for(bool blocked:{false,true})for(int order:{HOUND_HOLD,HOUND_ATTACK,HOUND_DEFEND}){
  Crowd c;auto h=setup(c);auto foe=c.query({-1,-1,-3},{1,3,-1},0)[0];
  c.set_pose(foe,{0,0,-12},0);
  NavigationData nav;nav.origin={-30,0,-30};nav.width=21;nav.spacing=3;
  nav.heights.assign(441,0);nav.covered.assign(441,1);
  if(blocked){nav.ray_min={{-8,-1,-7}};nav.ray_max={{8,8,-6}};nav.obstacle_min=nav.ray_min;nav.obstacle_max=nav.ray_max;}
  c.set_navigation(nav);
  assert(c.set_pet_skills(h,{3,0,0}));
  ExternalTarget hero;hero.id=7;hero.hp=10000;
  c.combat.set_targets({hero},0,0,order,1,order==HOUND_ATTACK?foe:0);
  int starts=0,contacts=0;
  for(int frame=0;frame<hz/2;++frame){
   c.step(1.0/hz);
   for(const auto& e:c.combat.events()){
    // An explicit attack command may close distance before the committed cast.
    if(e.kind==PET_SKILL_STARTED){assert(e.target_id==1&&length(e.position-c.unit(foe)->position)<=16&&
      (order!=HOUND_HOLD||length(e.position-c.unit(foe)->position)>10));++starts;}
    if(e.kind==PET_SKILL_CONTACT){assert(e.target_id==1&&length(e.position-c.unit(foe)->position)<=16&&
      (order!=HOUND_HOLD||length(e.position-c.unit(foe)->position)>10));++contacts;}
   }
   c.combat.clear_events();
  }
  assert(starts==(blocked?0:1)&&contacts==(blocked?0:1));++checks;
 }
 {
  Crowd c;auto h=setup(c);auto foe=c.query({-1,-1,-3},{1,3,-1},0)[0];
  c.set_pose(foe,{0,0,-12},0);
  assert(c.set_pet_skills(h,{3,0,0}));c.step(1.0/60);
  assert(c.unit(h)->pet_skill==3);
  c.set_pose(foe,{0,0,-17},0);
  for(int frame=0;frame<60;++frame)c.step(1.0/60);
  for(const auto& e:c.combat.events())assert(e.kind!=PET_SKILL_CONTACT);
  ++checks;
 }
 for(int hz:{20,30,60}){
  Crowd c;auto h=setup(c);auto data=kits();
  data.pet_mana=50;data.pet_mana_regen=1;data.pet_skill_costs.resize(PET_SKILL_COUNT);
  data.pet_skill_costs[0]=8;data.pet_skill_costs[1]=18;
  assert(c.combat.configure(data)&&c.set_pet_skills(h,{1,2,0}));
  assert(!c.set_pet_mana(h,-1)&&!c.set_pet_mana(h,51)&&c.set_pet_mana(h,0));
  auto* pet=c.unit(h);const double dt=1.0/hz;
  int basics=0,casts=0;
  for(int frame=0;frame<hz*12;++frame){
   const double before=pet->pet_mana;
   c.step(dt);
   bool cast=false;
   for(const auto& event:c.combat.events()){
    if(event.kind==DAMAGE&&event.source_id==-1)++basics;
    if(event.kind==PET_SKILL_STARTED){
     assert(event.action_index==1&&frame>=hz*8-1);
     cast=true;++casts;
    }
   }
   c.combat.clear_events();
   assert(std::abs(pet->pet_mana-std::max(0.0,before+dt-(cast?8:0)))<1e-7);++checks;
  }
  assert(basics>0&&casts==1);++checks;
  assert(c.set_pet_mana(h,49));c.combat.rest_tick(c,2);
  assert(pet->pet_mana==50);++checks;
 }
 for(int hz:{20,30,60})for(int skin=0;skin<HOUND_SKINS;++skin){
  Crowd c;auto h=setup(c,skin);assert(!c.set_pet_skills(h,{1,1,3}));++checks;
  assert(!c.set_pet_skills(h,{1,3}));assert(!c.set_pet_skills(h,{1,3,PET_SKILL_COUNT+1}));checks+=2;
  for(int retired=12;retired<=21;++retired){assert(!c.set_pet_skills(h,{retired,0,0}));++checks;}
  assert(!c.set_pet_skill_ready(h,8));++checks;
  assert(c.set_pet_skills(h,{1,3,6}));++checks;
  int contacts=0,basics=0;std::map<int,double> last;
  for(int frame=0;frame<hz*16;++frame){
   c.step(1.0/hz);
   for(const auto& e:c.combat.events()){
    if(e.kind==PET_SKILL_STARTED){
     assert(e.ticket_id==h&&e.amount==.5&&e.unit_kind==HOUND_KIND&&e.team==1);++checks;
     if(last.count(e.action_index)){assert(double(frame)/hz-last[e.action_index]>=5.0-1.01/hz);++checks;}
     last[e.action_index]=double(frame)/hz;choices.insert(e.action_index);
    }
    if(e.kind==PET_SKILL_CONTACT){assert(e.amount==.5&&e.action_index>=1&&e.action_index<=6);++contacts;++checks;}
    if(e.kind==DAMAGE&&e.source_id==-1)++basics;
   }
   c.combat.clear_events();
  }
  assert(contacts>0&&basics>0&&last.size()==3);checks+=3;
  auto cooldowns=c.unit(h)->pet_cooldowns;assert(c.set_pet_skills(h,{6,1,3})&&c.unit(h)->pet_cooldowns==cooldowns);++checks;
  c.rest_allies();assert((c.unit(h)->pet_skills==std::array<int,3>({6,1,3})&&c.unit(h)->pet_cooldowns==cooldowns));++checks;
 }
 assert(choices==std::set<int>({1,3,6}));++checks;
 for(int hz:{20,30,60}){
  Crowd c;auto h=setup(c);auto zero=kits();
  for(size_t row=0;row<zero.hound_attacks.size();row+=HOUND_TIMELINE_STRIDE)zero.hound_attacks[row+2]=0;
  assert(c.combat.configure(zero)&&c.set_pet_skills(h,{1,0,0}));
  bool started=false,first_contact=false;
  for(int frame=0;frame<hz*2;++frame){
   c.step(1.0/hz);
   for(const auto& e:c.combat.events()){
    if(e.kind==PET_SKILL_STARTED)started=true;
    if(e.kind==PET_SKILL_CONTACT){assert(started);if(e.source_tick==0)first_contact=true;}
   }
   c.combat.clear_events();
  }
  assert(first_contact);++checks;
 }
 {
  Crowd c;auto h=setup(c);
  assert(!c.set_pet_skills(h,{2,0,0},0)&&!c.set_pet_skills(h,{2,0,0},129));++checks;
  for(int count:{3,17,41,128}){
   assert(c.set_pet_skills(h,{2,0,0},count)&&c.unit(h)->pet_combo_limit==count);++checks;
   assert(c.unit(h)->action_hits.capacity()>=size_t(count));++checks;
  }
  c.unit(h)->pet_combo_left=7;c.unit(h)->pet_cooldowns[1]=4.0;
  assert(c.set_pet_skills(h,{2,0,0},17)&&c.unit(h)->pet_combo_left==7&&c.unit(h)->pet_cooldowns[1]==4.0);++checks;
 }
 for(int hz:{20,30,60}){
  Crowd c;auto h=setup(c);assert(c.set_pet_skills(h,{2,0,0}));++checks;
  for(int i=2;i<=9;++i)c.spawn(i,0,12,{float((i-2)%3)*6-6,0,-8-float((i-2)/3)*6},1,.5);
  c.unit(c.query({-1,-1,-3},{1,3,-1},0)[0])->hp=1;
  std::set<int64_t> hit;int contacts=0;bool started=false;
  for(int frame=0;frame<hz*15;++frame){
   c.step(1.0/hz);
   for(const auto& e:std::vector<Event>(c.combat.events()))if(e.kind==PET_SKILL_CONTACT){
    ++contacts;started=true;
    for(auto target:c.query(e.position-Vec3{32,8,32},e.position+Vec3{32,8,32},0))if(c.unit(target)->logical_id==e.target_id){Hit strike;strike.amount=100;strike.source_id=-1;c.combat.hit(c,target,strike);hit.insert(e.target_id);break;}
   }
   c.combat.clear_events();if(started&&c.unit(h)->pet_skill==0)break;
  }
  assert(hit.size()==1&&contacts==16);++checks;
  c.combat.set_targets({},0,0,HOUND_HOLD,1);c.step(1.0/hz);
  assert(c.unit(h)->pet_combo_left==0&&c.unit(h)->pet_skill==0);++checks;
 }
 std::cout<<"PET_SKILLS_RESULT checks="<<checks<<" failures=0\n";
}
