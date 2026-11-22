#include "core.h"
#include "instance_buffers.h"
#include <cassert>
#include <iostream>
using namespace army;
static KitData kits(bool boost=true){
 KitData d;d.slime_guard=true;d.slime_approach_boost=boost;d.soldier_kinds={SLIME_KIND,0};
 d.soldier_profiles={5000,3,30,7.5,6,6,192,3,11,2.5,5,2.304};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};d.bullet_speed=8.64;d.bullet_life=3.34;d.bullet_tail=.576;d.bullet_radius=.576;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=10;d.slime_attacks[i+3]=135;}
 return d;
}

static ExternalTarget hero(int64_t serial=1){ExternalTarget t;t.kind=0;t.hp=100000;t.foot=t.minimum=t.maximum={0,0,0};t.attack_serial=serial;t.attack_facing={1,0,0};t.attack_reach=8;return t;}
static KitData pet_kits(bool guard){
 auto d=kits();d.slime_guard=guard;
 d.soldier_kinds.push_back(HOUND_KIND);
 d.soldier_profiles.insert(d.soldier_profiles.end(),{10000,4.5,10,3.4,6,1.75});
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.hound_attacks[i]=30;d.hound_attacks[i+1]=1;d.hound_attacks[i+2]=15;d.hound_attacks[i+3]=131;}
 return d;
}
static Handle setup(Crowd& c){
 c.configure(128,128);NavigationData nav;nav.bounds_min={-100,0,-100};nav.bounds_max={100,0,100};c.set_navigation(nav);
 assert(c.combat.configure(kits()));auto h=c.spawn(1,0,SLIME_KIND,{9,0,0},1000,1);auto u=c.unit(h);
 u->external_kind=0;u->external_target=0;u->yaw=M_PI/2;u->rng=1;c.combat.set_targets({hero()});return h;
}
int main(){
 int checks=0;
 for(int hz:{20,30,60}){
  double dt=1.0/hz;Crowd c;auto h=setup(c);auto u=c.unit(h);c.step(dt);
  assert(u->guard_reaction>=.075&&u->guard_reaction<=.125&&!u->blocking);++checks;
  double reaction=u->guard_reaction,elapsed=0;
  while(!u->blocking&&elapsed<.5){c.step(dt);elapsed+=dt;if(elapsed+1e-8<reaction)assert(!u->blocking);++checks;}
  assert(u->blocking&&elapsed>=reaction&&elapsed<=reaction+dt+1e-8&&u->action==13&&u->guard_left>=.95-dt&&u->guard_left<=.95);++checks;
  const auto cue_matches=[&](const Event& event){return event.kind==STATUS_EVENT&&event.action_index==ENEMY_GUARD_RAISED&&event.ticket_id==h;};
  assert(std::count_if(c.combat.events().begin(),c.combat.events().end(),cue_matches)==1);++checks;
  c.step(dt);
  assert(std::count_if(c.combat.events().begin(),c.combat.events().end(),cue_matches)==1);++checks;
  Hit hit;hit.amount=100;hit.direction={1,0,0};hit.impulse={4,3,0};hit.flinch=.2;
  auto result=c.combat.hit(c,h,hit);assert(result.accepted&&result.hp==975&&u->stun==0&&length(u->knockback)==0&&u->blocking);++checks;
  assert(c.combat.events().back().action_index==13&&c.combat.events().back().amount==25);++checks;
  hit.projectile=true;assert(c.combat.hit(c,h,hit).hp==950);++checks;
  hit.direction={-1,0,0};assert(c.combat.hit(c,h,hit).hp==850&&!u->blocking&&u->stun>0);++checks;
  c.despawn(h);h=setup(c);u=c.unit(h);c.step(dt);while(!u->blocking)c.step(dt);
  while(u->blocking)c.step(dt);
  assert(u->guard_cooldown>=.6);++checks;
  u->position={9,0,0};u->action_active=false;c.combat.set_targets({hero(2)});c.step(dt);
  assert(!u->blocking&&u->guard_reaction==0);++checks;
  u->guard_cooldown=0;u->action_active=false;u->position={9,0,0};u->rng=1;c.step(dt);
  assert(u->guard_reaction==0);++checks; // One decision per attack, including cooldown rejection.
  c.combat.set_targets({hero(3)});u->rng=1;u->action_active=false;c.step(dt);assert(u->guard_reaction>0);++checks;
  auto gone=hero(3);gone.targetable=false;c.combat.set_targets({gone});c.step(dt);assert(!u->blocking&&u->guard_reaction==0);++checks;
  c.despawn(h);auto fresh=c.spawn(2,0,SLIME_KIND,{9,0,0},1000,1);u=c.unit(fresh);
  assert(!u->blocking&&u->guard_reaction==0&&u->guard_cooldown==0&&u->guard_seen_attack==0&&!c.valid(h));++checks;
  for(int scenario=0;scenario<5;++scenario){
   Crowd other;auto g=setup(other);auto v=other.unit(g);auto t=hero();
   if(scenario==0)v->yaw=-M_PI/2;
   if(scenario==1)t.attack_facing={-1,0,0};
   if(scenario==2)t.attack_serial=0;
   if(scenario==3){v->action_active=true;v->action=1;}
   if(scenario==4)v->stun=1;
   other.combat.set_targets({t});other.step(dt);assert(!v->blocking&&v->guard_reaction==0);++checks;
  }
  int chosen=0;
  for(int seed=1;seed<=1000;++seed){Crowd other;auto g=setup(other);other.unit(g)->rng=seed;other.step(dt);chosen+=other.unit(g)->guard_reaction>0;}
  assert(chosen>550&&chosen<650);++checks;
  std::cout<<"GUARD_CHANCE hz="<<hz<<" chosen="<<chosen<<" attempts=1000\n";

  for(bool break_guard:{false,true}){
   Crowd fight;const auto enemy=setup(fight);auto& fighter=*fight.unit(enemy);
   fight.set_pose(enemy,{1.3f,0,0},M_PI/2);
   fight.combat.set_targets({hero(0)});
   if(break_guard)fighter.external_kind=-1;
   Hit basic;basic.amount=10;basic.direction={1,0,0};basic.joint_attack=true;
   Hit breaker;breaker.amount=12;breaker.direction={1,0,0};breaker.guard_break=true;
   auto miss=fight.combat.hit(fight,enemy,breaker);
   assert(!miss.accepted&&miss.hp==1000&&fight.combat.events().empty());++checks;
   for(int hit=1;hit<=3;++hit){
    if(hit>1)for(int i=0;i<hz/5;++i)fight.step(dt);
    assert(fight.combat.hit(fight,enemy,basic).hp==1000-hit*10&&!fighter.blocking);++checks;
   }
   for(int i=0;i<hz/3&&!fighter.blocking;++i)fight.step(dt);
   assert(fighter.blocking&&fighter.guard_left>=1.15-dt&&fighter.guard_pressure_hits==0);++checks;
   const auto& cue=fight.combat.events().back();
   assert(cue.kind==STATUS_EVENT&&cue.action_index==ENEMY_GUARD_RAISED&&cue.ticket_id==enemy&&cue.amount==1.15);++checks;
   if(break_guard){
    for(int i=0;i<hz*4/5;++i)fight.step(dt);
    breaker.direction={-1,0,0};
    assert(!fight.combat.hit(fight,enemy,breaker).accepted&&fighter.blocking);++checks;
    breaker.direction={1,0,0};
    assert(fight.combat.hit(fight,enemy,breaker).hp==958&&!fighter.blocking&&fighter.stun>0&&fighter.light_recoil_grace==0);++checks;
    assert(fight.combat.events().back().action_index==GUARD_BREAK_HIT);++checks;
   }else{
    assert(fight.combat.hit(fight,enemy,basic).hp==967.5&&fighter.guard_left==.85);++checks;
    bool struck=false;
    for(int frame=1;frame<=2*hz&&!struck;++frame){
     fight.step(dt);
     for(const auto& event:fight.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.target_id==0)struck=true;
     if(!struck&&frame%(hz/10)==0)fight.combat.hit(fight,enemy,basic);
    }
    assert(struck);++checks;
   }
  }

  for(int scenario=0;scenario<4;++scenario){
   Crowd fight;const auto enemy=setup(fight);const auto& fighter=*fight.unit(enemy);
   fight.set_pose(enemy,{1.3f,0,0},M_PI/2);
   auto target=hero(0);target.guarding=scenario!=3;
   fight.combat.set_targets({target});fight.step(dt);
   assert(fighter.action_active&&(fighter.action==ENEMY_GUARD_BREAK_WINDUP)==target.guarding);++checks;
   if(target.guarding){
    const auto& cue=fight.combat.events().back();
    assert(cue.kind==STATUS_EVENT&&cue.action_index==ENEMY_GUARD_BREAK_WINDUP&&cue.ticket_id==enemy);++checks;
   }
   int contacts=0,swings=target.guarding?0:1;
   for(int frame=0;frame<2*hz&&fighter.action_active&&swings<2;++frame){
    if(frame==hz/4&&scenario==1)target.guarding=false;
    if(frame==hz/4&&scenario==2)target.foot=target.minimum=target.maximum={-20,0,0};
    fight.combat.clear_events();fight.combat.set_targets({target});fight.step(dt);
    for(const auto& event:fight.combat.events()){
     if(event.kind==ATTACK_STARTED&&++swings==2)break;
     if(event.kind!=EXTERNAL_DAMAGE)continue;
     assert((event.action_index==GUARD_BREAK_HIT)==(scenario!=3));
     assert(event.amount==(scenario==3?30:36));
     assert(scenario==3||frame>=hz/2);
     ++contacts;
    }
    if(scenario==1&&!target.guarding&&swings<2)assert(fight.combat.hero_dodge_threat().seconds<0);
   }
   assert((!fighter.action_active||swings==2)&&contacts==(scenario==0||scenario==3?1:0));++checks;
  }

  {
   Crowd fight;const auto first=setup(fight);fight.set_pose(first,{1.3f,0,0},M_PI/2);
   const auto second=fight.spawn(2,0,SLIME_KIND,{-1.3f,0,0},1000,.2f);
   fight.set_pose(second,{-1.3f,0,0},-M_PI/2);
   auto target=hero(0);target.guarding=true;fight.combat.set_targets({target});fight.step(dt);
   assert(fight.unit(first)->action==ENEMY_GUARD_BREAK_WINDUP&&fight.unit(second)->action!=ENEMY_GUARD_BREAK_WINDUP);++checks;
   fight.despawn(first);
   fight.combat.clear_events();
   for(int frame=0;frame<hz*2;++frame)fight.step(dt);
   assert(std::none_of(fight.combat.events().begin(),fight.combat.events().end(),[](const Event& e){
    return e.kind==STATUS_EVENT&&e.action_index==ENEMY_GUARD_BREAK_WINDUP;
   }));++checks;
  }

  for(bool from_guard:{false,true}){
   Crowd fight;auto enemy=setup(fight);auto fighter=fight.unit(enemy);
   if(from_guard){
    for(int frame=0;frame<hz/3&&!fighter->blocking;++frame)fight.step(dt);
    assert(fighter->blocking);
   }else{
    fight.despawn(enemy);enemy=fight.spawn(2,0,0,{1.3f,0,0},1000,.2f);fighter=fight.unit(enemy);
    fight.combat.set_targets({hero(0)});
   }
   fight.set_pose(enemy,{1.3f,0,0},M_PI/2);
   Hit basic;basic.amount=10;basic.direction={1,0,0};basic.joint_attack=true;
   const auto opening=fight.combat.hit(fight,enemy,basic);
   assert(opening.hp==(from_guard?997.5:990));++checks;
   const double first_stun=fighter->stun;
   assert(from_guard?first_stun==0:first_stun>0);++checks;
   bool struck=false;
   for(int frame=1;frame<=hz*2&&!struck;++frame){
    fight.step(dt);
    for(const auto& event:fight.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.target_id==0)struck=true;
    if(struck)break;
    if(frame%(hz/10)==0){
     const double before=fighter->hp;
     const bool block=fighter->blocking;
     assert(fight.combat.hit(fight,enemy,basic).hp==before-(block?2.5:10));
     if(!block)assert(fighter->stun<first_stun||(from_guard&&fighter->stun==0));
    }
   }
   assert(struck&&fighter->action_active&&fighter->light_recoil_grace==0);++checks;
   for(int interrupt=0;interrupt<4;++interrupt){
    fighter->light_recoil_grace=1;
    Hit breaker=basic;
    if(interrupt==0)breaker.heavy=true;
    if(interrupt==1)breaker.direction={-1,0,0};
    if(interrupt==2){breaker.amount=0;breaker.effect=1;breaker.status_seconds=1;}
    if(interrupt==3){breaker.amount=0;breaker.effect=4;breaker.status_seconds=1;}
    assert(fight.combat.hit(fight,enemy,breaker).accepted&&fighter->light_recoil_grace==0);
    assert(interrupt==2?fighter->frozen==1:!fighter->action_active&&fighter->stun>0);++checks;
   }
   fight.despawn(enemy);enemy=fight.spawn(3,0,SLIME_KIND,{1.3f,0,0},1000,.2f);
   assert(!fight.unit(enemy)->light_stagger&&fight.unit(enemy)->light_recoil_grace==0);++checks;
  }
  // Five pets strike a patroller from alternating sides while its first stagger recovers.
  for(bool guard:{false,true}){
   Crowd fight;auto enemy=setup(fight);
   assert(fight.combat.configure(pet_kits(guard)));
   fight.set_pose(enemy,{0,0,0},0);fight.set_guard(enemy,{0,0,0},14);
   std::vector<Handle> pets;
   for(int i=0;i<5;++i){
    float angle=i*2*M_PI/5;
    auto pet=fight.spawn(-i-1,1,HOUND_KIND,{2*std::sin(angle),0,2*std::cos(angle)},10000,.2f);
    fight.set_guard(pet,fight.unit(pet)->position,18);pets.push_back(pet);
   }
   auto target=hero(0);target.foot=target.minimum=target.maximum={40,0,40};
   fight.combat.set_targets({target},0,0,HOUND_HOLD,1);
   auto fighter=fight.unit(enemy);
   Hit basic;basic.amount=10;basic.joint_attack=basic.joint_pet=true;
   for(int i=0;i<5;++i){
    basic.source_id=-i-1;basic.direction=normalized(fighter->position-fight.unit(pets[i])->position);
    assert(fight.combat.hit(fight,enemy,basic).hp==990-i*10);++checks;
   }
   assert(fighter->stun>0&&fighter->light_recoil_grace>fighter->stun&&fighter->retaliation>0);++checks;
   int returns=0;double damage=0;
   fight.combat.set_targets({target},0,0,HOUND_ATTACK,2,enemy);
   for(int frame=0;frame<hz*10;++frame){
    fight.step(dt);
    for(const auto& event:fight.combat.events()){
     if(event.kind==DAMAGE&&event.source_id==1){++returns;damage+=event.amount;}
    }
    fight.combat.clear_events();
   }
   std::cout<<"PET_RETALIATION hz="<<hz<<" guard="<<guard<<" contacts="<<returns<<" damage="<<damage<<" hp="<<fighter->hp<<std::endl;
   assert(returns>=2&&damage==returns*30&&fighter->hp<950);++checks;
   for(int interrupt=0;interrupt<4;++interrupt){
    fighter->stun=fighter->frozen=fighter->guard_left=0;fighter->blocking=false;
    fighter->action_active=true;fighter->light_recoil_grace=1;
    Hit breaker=basic;
    if(interrupt==0)breaker.heavy=true;
    if(interrupt==1){breaker.amount=0;breaker.effect=1;breaker.status_seconds=1;}
    if(interrupt==2){breaker.amount=0;breaker.effect=4;breaker.status_seconds=1;}
    if(interrupt==3){breaker.impulse={3,0,0};breaker.flinch=.2;}
    assert(fight.combat.hit(fight,enemy,breaker).accepted&&fighter->light_recoil_grace==0);++checks;
    assert(interrupt==1?fighter->frozen==1:!fighter->action_active);++checks;
   }
   fight.despawn(enemy);auto reused=fight.spawn(3,0,SLIME_KIND,{0,0,0},1000,.2f);
   assert(!fight.valid(enemy)&&fight.unit(reused)->light_recoil_grace==0&&fight.unit(reused)->retaliation==0);++checks;
  }
  {
   Crowd fight;fight.configure(16,16);fight.set_navigation({});assert(fight.combat.configure(pet_kits(true)));
   auto enemy=fight.spawn(1,0,SLIME_KIND,{0,0,0},1000,.2f);
   auto pet=fight.spawn(-1,1,HOUND_KIND,{0,0,-2},10000,.2f);
   fight.set_guard(enemy,{0,0,0},14);fight.set_guard(pet,{0,0,-2},18);
   auto t=hero(0);t.foot=t.minimum=t.maximum={40,0,40};fight.combat.set_targets({t},0,0,HOUND_HOLD,1);
   int guards=0;
   for(int swing=1;swing<=5;++swing){
    auto u=fight.unit(enemy);u->action_active=u->blocking=false;u->stun=u->guard_left=u->guard_reaction=u->guard_cooldown=0;
    u->target_handle=pet;u->external_kind=-1;u->yaw=0;
    auto p=fight.unit(pet);p->action_active=true;p->action=1;p->attack_serial=swing;p->target_handle=enemy;p->yaw=M_PI;p->phase_tick=p->attack_tick=0;
    for(int i=0;i<hz/5;++i)fight.step(dt);
    if(u->blocking){++guards;assert(u->action==13&&(u->status&16));}
    assert(u->hp==1000);++checks;
   }
   assert(guards==3);++checks;
  }
 }
 {
  Crowd c;setup(c);c.clear();std::vector<Handle> units;
  for(int i=0;i<64;++i){
   float angle=(i%8-3.5f)*.04f;float radius=7.8f+(i/8)*.02f;
   auto h=c.spawn(i+1,0,SLIME_KIND,{radius*std::cos(angle),0,radius*std::sin(angle)},1000,.03f);
   auto u=c.unit(h);u->external_kind=0;u->external_target=0;u->yaw=M_PI/2-angle;u->rng=1;units.push_back(h);
  }
  c.combat.set_targets({hero()});for(int i=0;i<24;++i)c.step(1.0/60);
  int guarded=0;for(auto h:units)guarded+=c.unit(h)->blocking;
  assert(guarded==64);++checks;
  auto u=c.unit(units[0]);u->frozen=1;c.step(1.0/60);assert(!u->blocking&&u->guard_left==0);++checks;
  auto h=units[1];Hit hit;hit.amount=10000;hit.direction={1,0,0};assert(c.combat.hit(c,h,hit).dead&&!c.valid(h));++checks;
 }
 InstanceRow row;row.kind=SLIME_KIND;row.team=0;row.action=13;row.pose_row=2;row.flash=.1;
 auto buffer=instance_buffers({row},{});assert(buffer.valid&&buffer.submitted==1&&buffer.batches[0].buffer[13]==6);++checks;
 row.status=16;row.render_time=.125;row.pose_time=3;
 buffer=instance_buffers({row},{});assert(buffer.batches[0].buffer[13]==262&&buffer.batches[0].buffer[14]==.125f);++checks;
 row.status=1;buffer=instance_buffers({row},{});assert(buffer.batches[0].buffer[13]==11.125f);++checks;
 std::cout<<"GUARD_RESULT checks="<<checks<<" failures=0\n";
}
