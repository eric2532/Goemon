#include "core.h"
#include <cassert>
#include <iostream>
#include <cmath>
#include <set>
using namespace army;
static KitData kits(){
 KitData d;d.ruby_boss=true;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={60000,3.6f,10,4.3f,5,1.65f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=20;d.slime_attacks[i+3]=135;}
 return d;
}
static void steps(Crowd& c,int n){for(int i=0;i<n;++i)c.step(1.0/60);}
int main(){
 Crowd c;c.configure(32,32);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
 auto boss=c.spawn(1,0,SLIME_KIND,{0,0,0},60000,1);c.unit(boss)->hp=30000;
 for(int i=0;i<5;++i){auto h=c.spawn(10+i,0,SLIME_KIND,{float(i*3+15),0,0},12000,1);c.unit(h)->pose_row=1;c.unit(h)->frozen=1000;}
 c.combat.set_targets({ExternalTarget{0,0,{0,0,10},10000,true}});
 std::set<int> seen;
 for(int tick=0;tick<7200;++tick){c.step(1.0/60);for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.source_id==1&&e.source_tick==30)seen.insert(e.action_index);c.combat.clear_events();}
 int missing=0;for(int spell:{707,750,751,752,753,754,755,756,757,758,759})if(!seen.count(spell)){++missing;std::cout<<"MISSING_RUBY_SPELL "<<spell<<"\n";}

 if(missing)return 1;
 for(int i=0;i<3;++i){for(auto h:c.query({-100,-5,-100},{100,5,100},0))if(c.unit(h)->logical_id==10+i)c.despawn(h);}
 seen.clear();
 for(int tick=0;tick<2400;++tick){c.step(1.0/60);for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.source_id==1&&e.source_tick==30)seen.insert(e.action_index);c.combat.clear_events();}
 assert(seen.count(RUBY_FROST)&&seen.count(RUBY_METEOR)&&seen.count(RUBY_CONFUSION));
 auto cast=[&](int spell){auto u=c.unit(boss);u->stun=u->frozen=0;u->skill_left=1000;u->action=spell;u->action_active=true;u->action_time=.99;u->target_goal={0,0,10};c.combat.clear_events();c.step(.02);};
 auto clean=[&](){auto u=c.unit(boss);u->ruby_ward_left={};u->ruby_ward_hits={};u->ruby_holy_left=0;u->recover_left=0;u->hp=40000;u->stun=0;u->action_active=false;};
 int checks=0;
 for(int spell:{RUBY_PHYSICAL_ABSORB,RUBY_MAGIC_ABSORB,RUBY_PHYSICAL_REFLECT,RUBY_MAGIC_REFLECT,RUBY_PHYSICAL_NULL,RUBY_MAGIC_NULL}){
  clean();cast(spell);auto u=c.unit(boss);const int channel=(spell-RUBY_PHYSICAL_ABSORB)%2;
  Hit h;h.amount=123;h.source_id=0;h.magical=!bool(channel);
  const auto before=u->hp;assert(c.combat.hit(c,boss,h).accepted&&u->hp==before-123);++checks;
  u->stun=0;h.magical=bool(channel);const auto wounded=u->hp;c.combat.clear_events();
  assert(!c.combat.hit(c,boss,h).accepted);++checks;
  if(spell==RUBY_PHYSICAL_ABSORB||spell==RUBY_MAGIC_ABSORB){assert(u->hp==wounded+123);++checks;}
  else {assert(u->hp==wounded);++checks;}
  if(spell==RUBY_PHYSICAL_REFLECT||spell==RUBY_MAGIC_REFLECT){
   int returns=0;for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.target_id==0&&e.amount==123&&e.action_index==(channel?RUBY_MAGIC_RETURN:RUBY_PHYSICAL_RETURN));++returns;}
   assert(returns==1);++checks;
  }
  if(spell>=RUBY_PHYSICAL_NULL){assert(u->ruby_ward_hits[channel]==1);assert(!c.combat.hit(c,boss,h).accepted);++checks;}
  assert(c.combat.hit(c,boss,h).accepted);++checks;
 }
 clean();cast(RUBY_PHYSICAL_ABSORB);c.combat.set_targets({});steps(c,361);
 Hit ordinary;ordinary.amount=100;assert(c.combat.hit(c,boss,ordinary).accepted);++checks;
 clean();cast(RUBY_MAGIC_NULL);c.unit(boss)->frozen=10;steps(c,361);
 assert(c.unit(boss)->ruby_ward_left[1]==0);++checks;
 c.unit(boss)->frozen=0;
 clean();cast(RUBY_HOLY_SHIELD);double total=0;c.combat.clear_events();
 for(int i=0;i<100;++i){auto u=c.unit(boss);const double hp=u->hp;u->stun=0;ordinary.magical=i%2;c.combat.hit(c,boss,ordinary);double damage=hp-u->hp;assert(damage>=0&&damage<=50);total+=damage;}
 assert(total>2000&&total<3000);checks+=101;
 int holy_contacts=0;for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index==RUBY_WARD_BLOCK&&e.amount==RUBY_HOLY_SHIELD){assert(e.source_id==1&&e.source_tick>0);++holy_contacts;}
 assert(holy_contacts==100);++checks;
 c.combat.set_targets({});steps(c,181);c.combat.clear_events();ordinary.magical=false;c.unit(boss)->stun=0;c.combat.hit(c,boss,ordinary);
 for(const auto& e:c.combat.events())assert(!(e.kind==STATUS_EVENT&&e.action_index==RUBY_WARD_BLOCK&&e.amount==RUBY_HOLY_SHIELD));++checks;
 clean();cast(RUBY_RECOVER);c.unit(boss)->skill_left=1000;const auto recover_hp=c.unit(boss)->hp;steps(c,361);
 assert(std::abs(c.unit(boss)->hp-recover_hp-9000)<1e-6&&c.unit(boss)->recover_left==0);++checks;
 clean();cast(RUBY_GROUP_RECOVER);c.unit(boss)->skill_left=1000;const auto group_hp=c.unit(boss)->hp;steps(c,601);
 assert(std::abs(c.unit(boss)->hp-group_hp-7500)<1e-6&&c.unit(boss)->recover_left==0);++checks;
 clean();cast(RUBY_HEAL);assert(c.unit(boss)->hp==46000);++checks;
 clean();cast(RUBY_MEND);assert(c.unit(boss)->hp==43600);++checks;
 clean();auto frozen=c.unit(boss);frozen->action=RUBY_HEAL;frozen->action_active=true;frozen->action_time=.99;frozen->frozen=.5;
 steps(c,20);assert(frozen->hp==40000&&frozen->action_time==.99);++checks;
 steps(c,20);assert(frozen->hp==46000);++checks;
 auto ally=c.spawn(100,1,7,{0,0,10},1000,.5);
 clean();cast(RUBY_MAGIC_REFLECT);Hit magic;magic.amount=123;magic.magical=true;magic.source_id=100;
 c.combat.hit(c,boss,magic);assert(c.unit(ally)->hp==877);++checks;
 c.unit(ally)->avatar_left=10;c.unit(ally)->invuln=0;cast(RUBY_FROST);assert(c.unit(ally)->hp==877);++checks;
 cast(RUBY_METEOR);assert(c.unit(ally)->hp==877);++checks;
 c.unit(ally)->avatar_left=0;c.unit(ally)->invuln=0;cast(RUBY_CONFUSION);assert(c.unit(ally)->confusion_left>3.97&&c.unit(ally)->confusion_left<=4);++checks;
 c.unit(ally)->stun=0;c.unit(boss)->frozen=1000;
 auto home=c.unit(ally)->position;c.set_goal(ally,home+Vec3{0,0,10},3);steps(c,30);
 assert(c.unit(ally)->position.z<home.z&&c.unit(ally)->goal.z==home.z+10);++checks;
 steps(c,241);assert(c.unit(ally)->confusion_left==0);++checks;
 c.despawn(ally);auto replacement=c.spawn(100,1,7,{0,0,10},1000,.5);
 assert(replacement!=ally&&c.unit(replacement)->confusion_left==0&&c.unit(replacement)->recover_left==0);++checks;
 clean();cast(RUBY_PHYSICAL_NULL);Hit lethal;lethal.amount=100000;lethal.magical=true;
 assert(c.combat.hit(c,boss,lethal).dead);steps(c,120);assert(!c.valid(boss));++checks;
 auto fresh=c.spawn(1,0,SLIME_KIND,{0,0,0},60000,1);auto u=c.unit(fresh);
 assert(u->ruby_ward_hits[0]==0&&u->ruby_ward_left[0]==0&&u->ruby_support==0&&!u->ruby_enraged);++checks;
 auto plain=kits();plain.ruby_boss=false;assert(c.combat.configure(plain));c.combat.set_targets({ExternalTarget{0,0,{0,0,10},10000,true}});
 c.combat.clear_events();steps(c,300);for(const auto& e:c.combat.events())assert(!ruby_spell_action(e.action_index));++checks;
 std::cout<<"RUBY_SPELLS_RESULT early_spells=11 late_spells=3 checks="<<checks<<" failures=0\n";
}
