#include "core.h"
#include "guardian_rules.h"
#include <cassert>
#include <iostream>
#include <set>
using namespace army;
static KitData kits(int floor){
 KitData d;d.cursed_guardian=floor;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={60000,3.6f,100,6,5,1.65f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={45,10,36,30,30};d.contact_ticks={18,18,18,18};d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1;d.bullet_radius=.5;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=45;d.slime_attacks[i+1]=5;for(int j=0;j<5;++j){d.slime_attacks[i+2+2*j]=10+5*j;d.slime_attacks[i+3+2*j]=135;}}
 return d;
}
static void steps(Crowd& c,int n){for(int i=0;i<n;++i)c.step(1./60);}
int main(){
 int checks=0;std::set<int> exercised;
 for(int profile=1;profile<=7;++profile){
  Crowd c;c.configure(64,64);c.set_navigation(NavigationData{});assert(c.combat.configure(kits(std::min(profile,6))));
  auto boss=c.spawn(1,0,SLIME_KIND,{0,0,0},60000,1);auto u=c.unit(boss);u->pose_row=profile<=5?2:profile==6?3:4;
  auto attendant=c.spawn(2,0,SLIME_KIND,{3,0,0},10000,1);c.unit(attendant)->pose_row=0;c.unit(attendant)->frozen=10000;
  auto victim=c.spawn(100,1,7,{0,0,-2},100000,1);c.unit(victim)->frozen=0;
  auto cast=[&](int tech){u=c.unit(boss);u->position={0,0,0};u->target_goal={0,0,-2};u->target_handle=victim;u->external_kind=-1;u->stun=u->frozen=u->invuln=0;u->guardian_tech=tech;u->guardian_hits=0;u->skill_left=1000;u->action=GUARDIAN_CAST;u->action_active=true;u->action_time=1.99;c.combat.clear_events();c.step(.02);};
  for(const auto& rule:GUARDIAN_RULES[profile-1]){
   const int tech=rule.tech;if(!tech)continue;exercised.insert(tech);if(!c.valid(victim)||c.unit(victim)->hp<=0){c.despawn(victim);victim=c.spawn(100,1,7,{0,0,-2},100000,1);}u->hp=30000;u->ruby_holy_left=0;u->ruby_ward_left={};u->ruby_ward_hits={};
   c.unit(victim)->hp=100000;c.unit(victim)->invuln=0;
   if(tech==7300||tech==50||tech==104||tech==105||tech==304||tech==305||tech==505||tech==8150){
    u->guardian_tech=tech;u->guardian_hits=0;u->guardian_combo=tech==50?4:1;u->skill_left=1000;
    u->target_handle=victim;u->external_kind=-1;u->action=1;u->action_active=true;u->action_time=0;u->phase_tick=0;u->attack_tick=0;u->soldier_phase=0;u->yaw=0;u->stun=0;
    c.unit(victim)->blocking=tech==505;steps(c,tech==50?400:100);
    if(tech==304||tech==305)for(int attempt=0;attempt<10&&c.unit(victim)->hp==100000;++attempt){u->guardian_tech=tech;u->guardian_hits=0;u->guardian_combo=1;u->skill_left=1000;u->target_handle=victim;u->action=1;u->action_active=true;u->action_time=u->phase_tick=u->attack_tick=0;u->stun=0;steps(c,100);}
assert(c.unit(victim)->hp<100000);++checks;
    if(tech==50)assert(c.unit(victim)->hp<=100000-80*4);
    if(tech==8150)assert(u->hp>30000);
   }else{
    cast(tech);bool impact=false;for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index==GUARDIAN_IMPACT&&e.amount==tech)impact=true;
    assert(impact);++checks;
    if(tech==850)assert(u->ruby_holy_left>0);
    if(tech>=5500&&tech<=6050){const int channel=(tech/100)%2?0:1;assert(u->ruby_ward_left[channel]>0);Hit strike;strike.amount=123;strike.magical=channel;strike.source_id=100;const auto hp=u->hp;assert(!c.combat.hit(c,boss,strike).accepted);if(tech/100==57||tech/100==58)assert(u->hp==hp+123);++checks;}
    if(tech==6104||tech==6350)assert(u->hp>30000||c.unit(attendant)->hp>10000);
    if(tech==6602)assert(u->recover_left>0&&c.unit(attendant)->recover_left>0);
    if(tech==1104||tech==1105)assert(u->counter_chance>0);
    if(tech==1000)assert(u->guardian_magic_guard>0);
    if(tech==3105){assert(c.unit(victim)->hp==100000-288);assert(u->hp==30288);}
    if(tech>=2702&&tech<=3005)assert(c.unit(victim)->hp<100000);
   }
  }
  if(profile==5){
   c.unit(victim)->frozen=0;u->guardian_status_draws=0;
   for(int status=0;status<6;++status){
    int applications=0;for(int i=0;i<4;++i){c.unit(victim)->invuln=0;cast(4453+status*100);for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index==GUARDIAN_AFFLICTION+status&&e.target_id==100)++applications;}
    assert(applications==1);++checks;
   }
   u->frozen=1000;c.unit(victim)->invuln=0;c.unit(victim)->afflictions[0]=2;c.unit(victim)->afflicted=1;c.unit(victim)->hp=100000;steps(c,121);assert(c.unit(victim)->hp<100000);++checks;
   c.unit(victim)->afflictions.fill(.05);c.unit(victim)->afflicted=63;c.combat.clear_events();c.step(.1);
   int cleared=0;for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index>=GUARDIAN_AFFLICTION&&e.action_index<GUARDIAN_AFFLICTION+6&&e.amount==0){assert(e.target_id==100&&e.ticket_id==victim&&e.unit_kind==7);++cleared;}
   assert(cleared==6&&c.unit(victim)->afflicted==0);++checks;
   c.unit(victim)->afflictions[1]=4;c.unit(victim)->afflicted=2;c.unit(victim)->invuln=0;c.combat.clear_events();
   Hit wake;wake.amount=10;wake.source_id=1;assert(c.combat.hit(c,victim,wake).accepted);
   assert(c.unit(victim)->afflictions[1]==0&&c.unit(victim)->afflicted==0);++checks;
   cleared=0;for(const auto& e:c.combat.events())if(e.kind==STATUS_EVENT&&e.action_index==GUARDIAN_AFFLICTION+1&&e.amount==0){assert(e.target_id==100&&e.ticket_id==victim);++cleared;}
   assert(cleared==1);++checks;
   c.despawn(victim);auto fresh=c.spawn(100,1,7,{0,0,-2},10000,1);assert(c.unit(fresh)->afflicted==0&&c.unit(fresh)->confusion_left==0);++checks;
  }
  if(profile==6){
   c.combat.set_targets({ExternalTarget{0,0,{0,0,-2},100000,true}});
   u->target_handle=0;u->external_kind=0;u->external_target=0;u->guardian_tech=8150;u->guardian_hits=0;u->guardian_combo=1;
   u->blocking=false;u->guard_left=0;u->action=1;u->action_active=true;u->action_time=u->phase_tick=u->attack_tick=0;u->stun=0;u->skill_left=1000;
   c.combat.clear_events();steps(c,100);int drains=0;
   for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.action_index==ZOMBIE_DRAIN&&e.ticket_id==boss);++drains;}
   assert(drains==1&&!magical_attack(SLIME_KIND,ZOMBIE_DRAIN,false));++checks;
   const auto hp=u->hp;c.combat.confirm_zombie_drain(c,boss,23);assert(u->hp==hp+23);++checks;
  }
  if(profile==7){
   u->guardian_death_draws=0;int deaths=0,cues=0;
   for(int i=0;i<10;++i){
    c.despawn(victim);victim=c.spawn(100,1,7,{0,0,-2},100000,1);cast(8652);
    for(const auto& e:c.combat.events()){
     if(e.kind==DEATH&&e.target_id==100)++deaths;
     if(e.kind==STATUS_EVENT&&e.action_index==FALKEN_DEATH_EFFECT){assert(e.target_id==100&&e.external_kind==-1&&std::abs(e.position.x)<.01&&std::abs(e.position.z+2)<.01);++cues;}
    }
   }
   assert(deaths==1);++checks;
   assert(cues==10);++checks;
   c.despawn(victim);c.combat.set_targets({ExternalTarget{0,0,{0,0,-2},100000,true}});u->guardian_death_draws=0;
   int fatal=0; cues=0;
   for(int i=0;i<10;++i){cast(8652);for(const auto& e:c.combat.events()){
    if(e.kind==EXTERNAL_DAMAGE&&e.action_index==GUARDIAN_FATAL)++fatal;
    if(e.kind==STATUS_EVENT&&e.action_index==FALKEN_DEATH_EFFECT){assert(e.target_id==0&&e.external_kind==0);++cues;}
   }}
   assert(cues==10&&fatal==1);++checks;
   c.combat.set_targets({ExternalTarget{0,0,{20,0,-2},100000,true}});cast(8652);
   for(const auto& e:c.combat.events())assert(e.action_index!=FALKEN_DEATH_EFFECT);++checks;
  }
  if(profile>=6){
   // A living partner suppresses each king's conditional opening; death enables it.
   auto partner=c.spawn(3,0,SLIME_KIND,{3,0,0},60000,1);c.unit(partner)->pose_row=profile==6?4:3;c.unit(partner)->frozen=10000;
   auto observe=[&](int ticks){std::set<int> seen;u->skill_left=0;u->action_active=false;u->guardian_tech=0;u->guardian_draws.clear();for(int i=0;i<ticks;++i){c.step(1./60);for(const auto&e:c.combat.events())if(e.action_index==GUARDIAN_CAST)seen.insert(int(e.amount));c.combat.clear_events();}return seen;};
   c.despawn(victim);c.combat.set_targets({ExternalTarget{0,0,{0,0,-2},100000,true}});u->target_handle=0;u->external_kind=0;u->external_target=0;auto paired=observe(12000);assert(!paired.count(profile==6?8850:8652));++checks;
   c.despawn(partner);auto lone=observe(18000);if(!lone.count(profile==6?8850:8652)){std::cerr<<"PHASE profile="<<profile<<" seen=";for(auto t:lone)std::cerr<<t<<",";std::cerr<<" target="<<u->target_handle<<" skill="<<u->skill_left<<" frozen="<<u->frozen<<" hp="<<u->hp<<" tech="<<u->guardian_tech<<" pos="<<u->position.x<<","<<u->position.z<<"\n";}assert(lone.count(profile==6?8850:8652));++checks;
  }
  c.despawn(boss);auto fresh=c.spawn(1,0,SLIME_KIND,{0,0,0},60000,1);assert(c.unit(fresh)->guardian_tech==0&&c.unit(fresh)->guardian_draws.empty()&&c.unit(fresh)->ruby_ward_hits[0]==0);++checks;
 }
 auto invalid=kits(7);assert(!valid_kit_data(invalid));++checks;
 for(int hz:{30,60,120}){
  Crowd c;c.configure(16,16);c.set_navigation({});assert(c.combat.configure(kits(1)));
  auto h=c.spawn(7,0,SLIME_KIND,{0,0,0},1000,.65);auto u=c.unit(h);u->pose_row=1;
  c.combat.set_targets({ExternalTarget{0,0,{0,0,-1},10000,true}});
  assert(!c.combat.begin_enemy_arrival(c,0));++checks;
  assert(c.combat.begin_enemy_arrival(c,h)&&c.combat.begin_enemy_arrival(c,h));++checks;
  int starts=0;for(const auto& e:c.combat.events())if(e.action_index==GUARDIAN_ARRIVAL){assert(e.source_id==7&&e.ticket_id==h&&e.amount==GUARDIAN_ARRIVAL_DURATION);++starts;}
  assert(starts==1);++checks;
  Hit early;early.amount=50;early.source_id=0;assert(!c.combat.hit(c,h,early).accepted);++checks;
  Hit interrupted=early;interrupted.effect=1;interrupted.status_seconds=5;interrupted.flinch=.3;interrupted.impulse={3,0,0};
  assert(!c.combat.hit(c,h,interrupted).accepted&&u->frozen==0&&u->stun==0&&u->action==GUARDIAN_ARRIVAL);++checks;
  double elapsed=0;
  while(elapsed+1e-8<GUARDIAN_ARRIVAL_DURATION){
   c.combat.clear_events();c.step(1.0/hz);elapsed+=1.0/hz;
   for(const auto& e:c.combat.events())assert(e.kind!=EXTERNAL_DAMAGE&&e.kind!=MELEE);
   assert(u->position.x==0&&u->position.z==0&&u->radius==float(.65)&&u->body_scale==1);++checks;
   if(elapsed+1e-8<GUARDIAN_ARRIVAL_DURATION)assert(u->action==GUARDIAN_ARRIVAL);
  }
  assert(u->action!=GUARDIAN_ARRIVAL&&u->pose_time>0&&u->invuln<1e-8);++checks;
  assert(c.combat.hit(c,h,early).accepted);++checks;
  c.despawn(h);h=c.spawn(7,0,SLIME_KIND,{0,0,0},1000,.65);assert(c.combat.begin_enemy_arrival(c,h));
  c.despawn(h);auto fresh=c.spawn(7,0,SLIME_KIND,{0,0,0},1000,.65);
  assert(c.unit(fresh)->action!=GUARDIAN_ARRIVAL&&c.unit(fresh)->invuln==0);++checks;
 }
 std::cout<<"CURSED_GUARDIANS_PASS profiles=7 source_skills="<<exercised.size()<<" checks="<<checks<<"\n";
}
