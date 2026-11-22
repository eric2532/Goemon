#include "pet_skills_fixture.h"
#include <iostream>
namespace army {
struct BodyguardTest {
 static void run(){
  int checks=0;
  for(int hz:{20,30,60})for(int skill:{PET_BODYGUARD}){
   Crowd c;auto guard=setup(c);c.set_pose(guard,{6,0,0},0);
   auto victim=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);
   auto& combat=c.combat;combat.bodyguards_={guard};
   assert(c.set_pet_skills(guard,{skill,0,0}));
   Hit strike;strike.amount=40;strike.source_id=1;strike.direction={0,0,1};
   // Every two eligible contacts draw one failure and one success.
   for(int pair=0;pair<30;++pair){
    int rescues=0;
    for(int draw=0;draw<2;++draw){
     c.set_pose(guard,{6,0,0},0);c.set_pose(victim,{0,0,0},0);
     auto pet=c.unit(guard);pet->hp=3000;pet->stun=pet->frozen=0;
     c.unit(victim)->hp=3000;c.unit(victim)->invuln=0;
     double before=pet->hp;
     combat.hit(c,victim,strike);
     if(!combat.rescues_.empty()){
      ++rescues;assert(c.unit(victim)->hp==3000&&pet->hp==before&&pet->bodyguard_left>0);++checks;
      assert(c.unit(victim)->position.z>1);++checks;
      pet->invuln=10;pet->dodge_chance=1;
      for(int frame=0;frame<hz;++frame)combat.advance_rescues(c,1.0/hz);
      if(pet->hp!=before-40||pet->bodyguard_left!=0||c.unit(victim)->hp!=3000)std::cerr<<"RESCUE hp="<<pet->hp<<" before="<<before<<" left="<<pet->bodyguard_left<<" victim="<<c.unit(victim)->hp<<" pending="<<combat.rescues_.size()<<"\n";
      assert(pet->hp==before-40&&pet->bodyguard_left==0&&c.unit(victim)->hp==3000);++checks;
      assert(pet->target_handle!=0);++checks;
     }else{assert(c.unit(victim)->hp==2960&&pet->hp==before);++checks;}
     combat.clear_events();
    }
    if(rescues!=1)std::cerr<<"PAIR hz="<<hz<<" pair="<<pair<<" rescues="<<rescues<<" level="<<c.unit(guard)->bodyguard_level<<" bag="<<c.unit(guard)->bodyguard_bag<<" x="<<c.unit(guard)->position.x<<" z="<<c.unit(guard)->position.z<<"\n";
    assert(rescues==1);++checks;
   }
   // Unequipping, dead/stunned guards and blocked straight paths cannot rescue.
   c.unit(guard)->bodyguard_bag=2;c.unit(guard)->stun=2;c.set_pose(victim,{0,0,0},0);
   assert(!combat.rescue(c,victim,strike,{}));++checks;c.unit(guard)->stun=0;
   assert(c.set_pet_skills(guard,{0,0,0}));assert(!combat.rescue(c,victim,strike,{}));++checks;
   c.set_pet_skills(guard,{skill,0,0});c.set_pose(guard,{6,0,0},0);
   NavigationData nav;nav.ray_min={{2,-1,-5}};nav.ray_max={{3,8,5}};c.set_navigation(nav);
   assert(!combat.rescue(c,victim,strike,{}));++checks;
   c.set_navigation({});
   // A pet can rescue the real player from a projectile, then take exactly that damage.
   ExternalTarget hero;hero.id=0;hero.hp=10000;hero.foot={0,0,0};combat.set_targets({hero});
   c.unit(guard)->bodyguard_bag=2;
   Event shot;shot.kind=EXTERNAL_DAMAGE;shot.external_kind=0;shot.source_id=1;shot.amount=30;shot.projectile=true;shot.direction={0,0,1};
   combat.external_hit(c,shot);assert(combat.rescues_.size()==1);++checks;
   double hp=c.unit(guard)->hp;combat.advance_rescues(c,1);assert(c.unit(guard)->hp==hp-30);++checks;
   // The player can rescue a pet, including during another action; native emits one transferred hit.
   combat.bodyguards_.clear();hero.bodyguard=true;hero.foot={6,0,0};combat.set_targets({hero});combat.hero_bodyguard_bag_=2;
   c.set_pose(victim,{0,0,0},0);combat.clear_events();
   assert(combat.rescue(c,victim,strike,{}));++checks;
   combat.advance_rescues(c,1);
   int taken=0;for(const auto& e:combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.intercepted&&e.amount==40&&e.source_id==1);++taken;}
   assert(taken==1&&!combat.hero_rescuing_);++checks;
   combat.clear();assert(combat.rescues_.empty()&&combat.bodyguards_.empty()&&!combat.hero_rescuing_);++checks;
   c.despawn(guard);auto reused=c.spawn(-3,1,HOUND_KIND,{6,0,0},3000,.5);
   assert(reused!=guard&&c.unit(reused)->bodyguard_bag==0&&c.unit(reused)->bodyguard_left==0);++checks;
  }
  {
   Crowd c;auto guard=setup(c);auto& combat=c.combat;
   auto victim=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);
   auto closer=c.spawn(2,0,12,{0,0,-4},100000,.5);
   auto source=c.query({-1,-1,-3},{1,3,-1},0)[0];c.set_pose(source,{0,0,-12},0);
   c.set_pet_skills(guard,{PET_BODYGUARD,0,0});c.set_pose(guard,{6,0,0},0);
   ExternalTarget hero;hero.id=7;hero.hp=100000;combat.set_targets({hero},0,0,HOUND_HOLD);
   c.step(1./60);combat.bodyguards_={guard};c.unit(guard)->bodyguard_bag=2;
   Hit strike;strike.amount=30;strike.source_id=1;strike.direction={0,0,1};
   assert(combat.rescue(c,victim,strike,{}));++checks;
   c.step(1./60);assert(c.unit(guard)->position.y>0&&c.unit(guard)->position.x<6&&c.unit(guard)->position.x>0);++checks;
   for(int i=0;i<150;++i)c.step(1./60);
   assert(c.unit(closer)->hp<100000&&c.unit(source)->hp==100000);++checks;
   // A retired guard's pending hit cannot damage a recycled body.
   c.set_pose(victim,{0,0,0},0);c.set_pose(guard,{6,0,0},0);c.unit(guard)->stun=0;c.unit(guard)->bodyguard_bag=2;
   assert(combat.rescue(c,victim,strike,{}));c.despawn(guard);
   auto recycled=c.spawn(-3,1,HOUND_KIND,{6,0,0},3000,.5);combat.advance_rescues(c,1);
   assert(c.unit(recycled)->hp==3000&&combat.rescues_.empty());++checks;
  }
  {
   Crowd c;setup(c);auto& combat=c.combat;combat.bodyguards_.clear();
   ExternalTarget hero;hero.id=0;hero.hp=10000;combat.set_targets({hero});
   for(int i=0;i<5;++i){
    auto h=c.spawn(-10-i,1,HOUND_KIND,{float(3+i),0,0},3000,.5);
    c.set_pet_skills(h,{PET_BODYGUARD,0,0});c.unit(h)->bodyguard_bag=2;combat.bodyguards_.push_back(h);
   }
   Event attack;attack.kind=EXTERNAL_DAMAGE;attack.source_id=1;attack.external_kind=0;attack.amount=40;attack.direction={0,0,1};
   combat.external_hit(c,attack);int starts=0;
   for(const auto& e:combat.events())starts+=e.kind==STATUS_EVENT&&e.action_index==BODYGUARD_START;
   assert(starts==1&&combat.rescues_.size()==1);++checks;
   combat.advance_rescues(c,1);int wounded=0;
   for(auto h:combat.bodyguards_)wounded+=c.unit(h)->hp<3000;
   assert(wounded==1&&combat.rescues_.empty());++checks;
  }
  {
   Crowd c;auto guard=setup(c);auto data=kits();data.zombie_boss=true;
   data.soldier_kinds.push_back(SLIME_KIND);data.soldier_profiles.insert(data.soldier_profiles.end(),{1000,0,40,4,6,2});
   data.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
   for(size_t i=0;i<data.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){data.slime_attacks[i]=30;data.slime_attacks[i+1]=1;data.slime_attacks[i+2]=15;data.slime_attacks[i+3]=135;}
   assert(c.combat.configure(data));
   auto source=c.spawn(55,0,SLIME_KIND,{0,0,-8},1000,.5);auto zombie=c.unit(source);zombie->hp=500;zombie->action=ZOMBIE_DRAIN;
   auto victim=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);c.set_pet_skills(guard,{PET_BODYGUARD,0,0});
   c.set_pose(guard,{6,0,0},0);c.unit(guard)->bodyguard_bag=2;c.combat.bodyguards_={guard};
   Hit drain;drain.source_id=55;drain.amount=40;drain.direction={0,0,1};drain.magical=true;
   assert(c.combat.rescue(c,victim,drain,{}));c.combat.advance_rescues(c,1);
   assert(zombie->hp==532&&c.unit(victim)->hp==3000&&c.unit(guard)->hp==2960);++checks;
  }
  for(bool player:{false,true}){
   Crowd c;auto guard=setup(c);auto victim=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);auto& combat=c.combat;
   c.set_pet_skills(guard,{PET_BODYGUARD,0,0});combat.bodyguards_=player?std::vector<int64_t>{}:std::vector<int64_t>{guard};
   assert(!c.set_pet_bodyguard_level(guard,0)&&!c.set_pet_bodyguard_level(guard,31)&&!c.set_pet_bodyguard_level(0,2));++checks;
   for(int level=1;level<=30;++level){
    assert(c.set_pet_bodyguard_level(guard,level));int rescued=0;
    for(int draw=0;draw<100;++draw){
     auto pet=c.unit(guard);pet->hp=3000;pet->invuln=pet->stun=pet->frozen=0;c.set_pose(guard,{6,0,0},0);c.set_pose(victim,{0,0,0},0);
     ExternalTarget hero;hero.id=0;hero.hp=10000;hero.foot={6,0,0};hero.bodyguard=player;hero.bodyguard_level=level;combat.set_targets({hero});
     Hit strike;strike.amount=100;strike.source_id=1;strike.direction={0,0,1};combat.clear_events();
     if(!combat.rescue(c,victim,strike,{}))continue;
     ++rescued;combat.advance_rescues(c,1);
     const double expected=100*(1-.01*(level-1));
     if(player){
      int hits=0;for(const auto& e:combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.intercepted&&std::abs(e.amount-expected)<1e-8);++hits;}
      assert(hits==1);++checks;
     }else{assert(std::abs(3000-pet->hp-expected)<1e-8);++checks;}
    }
    assert(rescued==49+level);++checks;
   }
   // The rank bonus is committed to intercepted hits only.
   ExternalTarget hero;hero.id=0;hero.hp=10000;hero.foot={50,0,0};combat.set_targets({hero});
   auto pet=c.unit(guard);pet->invuln=0;pet->hp=3000;Hit ordinary;ordinary.amount=100;ordinary.source_id=1;ordinary.direction={0,0,1};
   combat.hit(c,guard,ordinary);assert(pet->hp==2900);++checks;
   pet->bodyguard_bag=1;assert(c.set_pet_bodyguard_level(guard,29)&&pet->bodyguard_bag==0);++checks;
   pet->bodyguard_bag=1;c.rest_allies();assert(c.unit(guard)->bodyguard_level==29&&c.unit(guard)->bodyguard_bag==1);++checks;
   c.despawn(guard);auto fresh=c.spawn(-3,1,HOUND_KIND,{6,0,0},3000,.5);assert(c.unit(fresh)->bodyguard_level==1&&c.unit(fresh)->bodyguard_bag==0);++checks;
  }
  for(int skill:{0,2,3,PET_BEE_FLURRY})for(bool counter:{false,true}){
   Crowd c;auto guard=setup(c);auto victim=c.spawn(-2,1,HOUND_KIND,{0,0,0},3000,.5);auto& combat=c.combat;
   auto source=c.query({-1,-1,-3},{1,3,-1},0)[0];auto ally=c.unit(victim);auto protector=c.unit(guard);
   c.set_pet_skills(guard,{PET_BODYGUARD,0,0});c.set_pose(guard,{6,0,0},0);combat.bodyguards_={guard};protector->bodyguard_bag=2;
   protector->action_active=true;protector->pet_skill=3;protector->pet_combo_left=2;
   ally->action_active=true;ally->action=1;ally->action_time=.2;ally->phase_tick=ally->attack_tick=6;ally->target_handle=source;
   ally->pet_skill=skill;ally->pet_combo_left=3;ally->pet_cast_serial=7;ally->counter_active=counter;ally->counter_pending=counter;ally->counter_source=source;
   ally->has_goal=true;ally->goal={0,0,-8};ally->velocity={1,2,3};ally->pose_velocity=ally->velocity;ally->invuln=.15;
   Unit corpse;combat.pet_sequence_target(c,*ally,corpse);Unit before=*ally;
   Hit strike;strike.amount=40;strike.source_id=1;strike.direction={0,0,1};
   assert(combat.rescue(c,victim,strike,{}));++checks;
   assert(ally->position.z>1&&ally->hp==before.hp&&ally->yaw==before.yaw);++checks;
   assert(ally->action_active&&ally->action==before.action&&ally->action_time==before.action_time&&ally->phase_tick==before.phase_tick&&ally->attack_tick==before.attack_tick);++checks;
   assert(ally->pet_skill==skill&&ally->pet_combo_left==3&&ally->pet_cast_serial==7&&ally->target_handle==source);++checks;
   assert(ally->counter_active==counter&&ally->counter_pending==counter&&ally->counter_source==source);++checks;
   assert(ally->has_goal&&length(ally->goal-before.goal)==0&&length(ally->velocity-before.velocity)==0&&length(ally->pose_velocity-before.pose_velocity)==0&&ally->invuln==before.invuln);++checks;
   if(skill==2||skill==PET_BEE_FLURRY){assert(combat.pet_sequence_targets_.count(victim)==1);++checks;}
   assert(!protector->action_active&&protector->pet_skill==0&&protector->pet_combo_left==0&&protector->bodyguard_left>0);++checks;
  }
  std::cout<<"BODYGUARD_RESULT checks="<<checks<<" failures=0\n";
 }
};
}
int main(){army::BodyguardTest::run();}
