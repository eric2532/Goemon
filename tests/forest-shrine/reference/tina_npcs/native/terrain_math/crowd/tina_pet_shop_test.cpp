#include "pet_skills_fixture.h"
#include <iostream>
#include <set>
int main(){
 int checks=0;
 const int costs[]={50,50,50,25,50,50,50,42,25,75};
 for(int hz:{20,30,60})for(int skin:{0,21,41,61,81})for(int skill=12;skill<=21;++skill){
  if(skill==17)continue;
  Crowd c;auto h=setup(c,skin);auto d=kits();d.pet_mana=100;d.pet_mana_regen=1;
  d.pet_skill_costs.resize(PET_SKILL_COUNT);
  for(int i=0;i<10;++i)d.pet_skill_costs[11+i]=costs[i];
  assert(c.combat.configure(d));auto pet=c.unit(h);pet->pet_mana=90;pet->hp=1500;
  auto foe=c.query({-1,-1,-3},{1,3,-1},0)[0];auto enemy=c.unit(foe);enemy->pet_mana=80;
  if(skill==15){enemy->blocking=true;enemy->guard_left=100;enemy->yaw=3.141592653589793;}
  assert(c.set_pet_skills(h,{skill,0,0}));
  bool started=false;int elapsed=0;int cycles=0;uint64_t serial=0;
  for(int frame=0;frame<hz*5;++frame){
   c.step(1.0/hz);++elapsed;
   for(const auto& e:c.combat.events())if(e.kind==PET_SKILL_STARTED){started=true;serial=e.projectile_id;++cycles;assert(e.action_index==skill&&serial==1);}
   c.combat.clear_events();
   if(started&&c.unit(h)->pet_skill==0)break;
  }
  pet=c.unit(h);enemy=c.unit(foe);assert(started&&pet&&enemy);++checks;
  if(std::abs(pet->pet_mana-std::min(100.,90-costs[skill-12]+double(elapsed)/hz))>=1e-6)std::cerr<<"MANA hz="<<hz<<" skill="<<skill<<" skin="<<skin<<" got="<<pet->pet_mana<<" elapsed="<<elapsed<<" cycles="<<cycles<<"\n";
  assert(std::abs(pet->pet_mana-std::min(100.,90-costs[skill-12]+double(elapsed)/hz))<1e-6);++checks;
  if(skill==12){assert(cycles>=1&&cycles<=3&&enemy->hp<100000);++checks;}
  if(skill==13||skill==14||skill==15||skill==19){assert(enemy->hp<100000);++checks;}
  if(skill==16){assert(enemy->pet_mana==60&&enemy->hp==100000);++checks;}
  if(skill==21){assert(pet->hp>=1650&&pet->hp<=2400&&enemy->hp==100000);++checks;}
  if(skill==18){Hit hit;hit.amount=100;hit.provoke=false;hit.magical=true;double before=pet->hp;c.combat.hit(c,h,hit);assert(before-pet->hp>=25-1e-6&&before-pet->hp<=35+1e-6);++checks;}
  if(skill==13){Hit hit;hit.amount=100;hit.provoke=false;double before=pet->hp;c.combat.hit(c,h,hit);assert(std::abs(before-pet->hp-150)<1e-6);++checks;}
  auto remaining=pet->pet_tina_combo;auto mana=pet->pet_mana;auto hp=pet->hp;
  c.rest_allies();pet=c.unit(h);assert(pet->pet_tina_combo==remaining&&pet->pet_mana==mana&&pet->hp==hp&&pet->pet_tina_buff==0);++checks;
  assert(c.set_pet_skills(h,{0,0,0})&&pet->pet_tina_buff==0&&pet->pet_tina_left==0);++checks;
  c.despawn(h);auto reused=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);
  assert(reused!=h&&c.unit(reused)->pet_tina_buff==0&&c.unit(reused)->pet_tina_choices==0);++checks;
 }
 // Source draws cover every intended outcome before refilling.
 {
  Crowd c;auto h=setup(c);auto pet=c.unit(h);pet->pet_tina_buff=18;pet->pet_tina_left=100;
  std::set<int> damage;
  for(int i=0;i<11;++i){pet->invuln=0;pet->dodge_left=0;Hit hit;hit.amount=100;hit.provoke=false;hit.magical=true;double hp=pet->hp;c.combat.hit(c,h,hit);damage.insert(int(std::round(hp-pet->hp)));}
  assert(damage.size()==11&&*damage.begin()==25&&*damage.rbegin()==35);checks+=3;
  pet->pet_tina_buff=19;pet->hp=3000;int evades=0;
  for(int i=0;i<20;++i){pet->invuln=0;Hit hit;hit.amount=1;hit.provoke=false;double hp=pet->hp;c.combat.hit(c,h,hit);evades+=pet->hp==hp;}
  assert(evades==7);++checks;
  pet->pet_tina_buff=20;pet->hp=3000;int counters=0;
  for(int i=0;i<4;++i){pet->invuln=0;pet->counter_pending=false;Hit hit;hit.amount=1;hit.source_id=1;c.combat.hit(c,h,hit);counters+=pet->counter_pending;}
  assert(counters==1);++checks;
 }
 // A ready source bodyguard intercepts the player's physical melee hit only.
 {
  Crowd c;c.configure(256,256);c.set_navigation({});auto d=kits();d.soldier_kinds.push_back(0);
  d.soldier_profiles.insert(d.soldier_profiles.end(),{3000,.01f,40,3.4f,6,1.75f});d.pet_mana=100;d.pet_skill_costs.resize(PET_SKILL_COUNT);d.pet_skill_costs[16]=50;assert(c.combat.configure(d));
  ExternalTarget hero;hero.id=0;hero.hp=10000;hero.foot={0,0,0};c.combat.set_targets({hero},0,0,HOUND_HOLD);
  auto h=c.spawn(-1,1,HOUND_KIND,{6,0,0},3000,.5);auto pet=c.unit(h);pet->pose_row=0;pet->pet_mana=100;assert(c.set_pet_skills(h,{17,0,0}));
  c.set_guard(h,{6,0,0},18);c.spawn(1,0,0,{0,0,-2},3000,.5);
  int player_hits=0;
  for(int frame=0;frame<120;++frame){c.step(1./60);for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.target_id==0)++player_hits;c.combat.clear_events();}
  assert(c.unit(h)->hp<3000&&player_hits==0);assert(c.unit(h)->pet_mana<100&&std::fmod(c.unit(h)->pet_mana,50)==0);checks+=3;
 }
 std::cout<<"TINA_PET_SHOP_RESULT checks="<<checks<<" failures=0\n";
}
