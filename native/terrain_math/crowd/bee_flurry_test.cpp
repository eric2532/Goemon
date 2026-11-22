#include "core.h"
#include <cassert>
#include <iostream>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={HOUND_KIND};d.soldier_profiles={3000,4.5f,60,3.4f,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.hound_attacks[i]=30;d.hound_attacks[i+1]=3;d.hound_attacks[i+2]=4;d.hound_attacks[i+3]=117;d.hound_attacks[i+4]=10;d.hound_attacks[i+5]=131;d.hound_attacks[i+6]=20;d.hound_attacks[i+7]=132;}
 return d;
}
static Handle setup(Crowd& c,int skin){
 c.configure(16,16);c.set_navigation({});assert(c.combat.configure(kits()));
 ExternalTarget hero;hero.id=7;hero.hp=10000;c.combat.set_targets({hero});
 auto h=c.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);c.unit(h)->pose_row=skin;c.set_guard(h,{0,0,0},18);
 c.spawn(1,0,12,{0,0,-5},100000,.5);assert(c.set_pet_skills(h,{PET_BEE_FLURRY,0,0}));return h;
}
int main(){
 int checks=0;
 for(int hz:{20,30,60})for(int skin=0;skin<HOUND_SKINS;++skin){
  Crowd c;auto h=setup(c,skin);int starts=0,moves=0,hits=0;Vec3 origin,previous;double start=-1;
  for(int frame=0;frame<hz*5;++frame){
   c.step(1.0/hz);
   for(auto e:c.combat.events()){
    if(e.kind==PET_SKILL_STARTED){++starts;origin=e.position;start=double(frame)/hz;assert(e.action_index==PET_BEE_FLURRY);++checks;}
    if(e.kind==PET_SKILL_CONTACT){++hits;assert(e.target_id==1&&e.amount==1&&double(frame)/hz-start>=.45/BEE_FLURRY_RATE);++checks;}
    if(e.kind==PET_SKILL_MOVE){
     ++moves;
     if(moves==1){assert(std::abs(double(frame)/hz-start-.45/BEE_FLURRY_RATE)<=1.01/hz);++checks;}
     if(moves<=5){Vec3 side=normalized(e.position-Vec3{0,0,-5});if(moves>1){assert(dot(side,previous)<-.45);++checks;}previous=side;}
     else {assert(length(e.position-origin)<1e-5);++checks;}
    }
   }
   if(starts&&moves<6){Hit incoming;incoming.amount=1;assert(!c.combat.hit(c,h,incoming).accepted);++checks;}
   c.combat.clear_events();if(moves==6)break;
  }
  assert(starts==1&&moves==6&&hits==5&&c.unit(h)->pet_skill==0);++checks;
  c.step(1.0/hz);Hit incoming;incoming.amount=1;assert(c.combat.hit(c,h,incoming).accepted);++checks;
 }
 for(int hz:{20,30,60})for(int lethal_contact:{1,3}){
  Crowd c;auto h=setup(c,61);auto target=c.query({-1,-1,-6},{1,2,-4},0)[0];
  int hits=0,moves=0,deaths=0;bool killed=false;Vec3 origin;
  for(int frame=0;frame<hz*5;++frame){
   c.step(1.0/hz);auto events=std::vector<Event>(c.combat.events());c.combat.clear_events();
   for(auto e:events){
    if(e.kind==PET_SKILL_STARTED)origin=e.position;
    if(e.kind==PET_SKILL_MOVE)++moves;
    if(e.kind==PET_SKILL_CONTACT){
     ++hits;assert(e.target_id==1);
     if(hits==lethal_contact){Hit strike;strike.amount=1000000;auto result=c.combat.hit(c,target,strike);assert(result.dead&&!c.valid(target));killed=true;
      // Reuse the freed slot; its new generation must never inherit overkill.
      auto replacement=c.spawn(2,0,12,{15,0,-5},100000,.5);assert(replacement!=target);
     }else if(killed){Hit strike;strike.amount=1;assert(!c.combat.hit(c,target,strike).accepted);}
    }
   }
   for(auto e:c.combat.events())if(e.kind==DEATH)++deaths;
   c.combat.clear_events();if(moves==6)break;
  }
  assert(killed&&hits==5&&moves==6&&deaths==1&&c.unit(h)->pet_skill==0&&length(c.unit(h)->position-origin)<.01);++checks;
 }
 for(int mode=0;mode<5;++mode){
  Crowd c;auto h=setup(c,61);Vec3 origin;bool started=false;
  for(int frame=0;frame<180;++frame){c.step(1.0/60);for(auto e:c.combat.events())if(e.kind==PET_SKILL_STARTED){origin=e.position;started=true;}c.combat.clear_events();if(started&&c.unit(h)->pet_combo_left<5)break;}
  assert(started);
  if(mode==0)c.combat.set_targets({},0,0,HOUND_HOLD,1);
  if(mode==1)c.combat.set_targets({},0,0,HOUND_RETURN,1);
  if(mode==2)assert(c.set_pet_skills(h,{0,0,0}));
  if(mode==3)c.despawn(c.query({-1,-1,-6},{1,2,-4},0)[0]);
  if(mode==4)c.rest_allies();
  c.step(1.0/60);assert(c.unit(h)->pet_skill==0&&length(c.unit(h)->position-origin)<.2);++checks;
  for(auto e:c.combat.events())assert(e.kind!=PET_SKILL_CONTACT);
 }
 std::cout<<"BEE_FLURRY_NATIVE_RESULT checks="<<checks<<" failures=0\n";
}
