#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.falken_boss=true;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={60000,3.6f,10,4.3f,5,1.65f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=20;d.slime_attacks[i+3]=135;}
 return d;
}
int main(){
 Crowd c;c.configure(32,32);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto boss=c.spawn(1,0,SLIME_KIND,{0,0,0},60000,1);
 auto guard=c.spawn(2,0,SLIME_KIND,{6,0,0},12000,1);c.unit(guard)->pose_row=2;c.unit(guard)->frozen=10000;
 c.combat.set_targets({ExternalTarget{0,0,{0,0,10},10000,true}});
 std::set<int> seen;
 for(int tick=0;tick<12000;++tick){
  c.unit(boss)->hp=60000;c.step(1.0/60);
  for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.source_id==1&&e.source_tick==30)seen.insert(e.action_index);
  c.combat.clear_events();
 }
 for(int spell:{RUBY_HOLY_SHIELD,RUBY_PHYSICAL_REFLECT,RUBY_MAGIC_REFLECT,FALKEN_DRAIN,FALKEN_DEATH})assert(seen.count(spell));
 assert(!seen.count(FALKEN_SUMMON)&&!seen.count(RUBY_GROUP_RECOVER)&&!seen.count(RUBY_FROST)&&!seen.count(RUBY_METEOR));
 auto cast=[&](int spell){auto u=c.unit(boss);u->stun=u->frozen=0;u->skill_left=1000;u->action=spell;u->action_active=true;u->action_time=.99;u->external_kind=0;u->external_target=0;u->target_handle=0;u->target_goal={0,0,10};u->position={0,0,0};c.combat.clear_events();c.step(.02);};
 auto clean=[&](){auto u=c.unit(boss);u->ruby_ward_left={};u->ruby_ward_hits={};u->ruby_holy_left=0;u->recover_left=0;u->hp=20000;};
 for(int spell:{RUBY_PHYSICAL_REFLECT,RUBY_MAGIC_REFLECT}){
  clean();cast(spell);Hit h;h.amount=123;h.source_id=0;h.magical=spell==RUBY_MAGIC_REFLECT;
  assert(!c.combat.hit(c,boss,h).accepted);
  int replies=0;for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.amount==123)++replies;
  assert(replies==1);
 }
 clean();cast(FALKEN_DRAIN);int drains=0;
 for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.amount==245&&e.ticket_id==boss);++drains;}
 assert(drains==1);double wounded=c.unit(boss)->hp;c.combat.confirm_zombie_drain(c,boss,100);assert(c.unit(boss)->hp==wounded+100);
 c.unit(boss)->falken_death_draws=0;int deaths=0;
 for(int i=0;i<10;++i){cast(FALKEN_DEATH);for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.amount==10000);++deaths;}}
 assert(deaths==1);
 clean();cast(RUBY_GROUP_RECOVER);assert(c.unit(boss)->recover_left>0&&c.unit(guard)->recover_left>0);
 clean();cast(RUBY_HOLY_SHIELD);Hit strike;strike.amount=100;double before=c.unit(boss)->hp;
 assert(c.combat.hit(c,boss,strike).accepted&&c.unit(boss)->hp>=before-50);
 c.despawn(guard);c.unit(boss)->falken_family_draws=0;std::set<int> families;
 for(int i=0;i<2;++i){cast(FALKEN_SUMMON);for(const auto& e:c.combat.events())if(e.action_index==FALKEN_SUMMON_EFFECT)families.insert(int(e.amount));}
 assert(families==std::set<int>({1,2}));
 seen.clear();c.unit(boss)->skill_left=0;c.unit(boss)->action_active=false;
 for(int tick=0;tick<12000;++tick){
  c.unit(boss)->hp=20000;c.step(1.0/60);
  for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.source_tick==30)seen.insert(e.action_index);
  c.combat.clear_events();
 }
 assert(seen.count(FALKEN_SUMMON)&&seen.count(RUBY_GROUP_RECOVER)&&!seen.count(FALKEN_DEATH));
 std::cout<<"FALKEN_SPELLS_PASS source spell set, conditional guards/recovery, reflection, confirmed drain, 1-in-10 death bag and summon family bag\n";
}
