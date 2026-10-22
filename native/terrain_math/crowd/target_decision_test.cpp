#include "core.h"
#include <algorithm>
#include <cassert>
#include <iostream>
#include <random>
namespace army {
static float horizontal(Vec3 a,Vec3 b){return std::hypot(a.x-b.x,a.z-b.z);}
struct TargetDecisionTest {
static void choose(Crowd& c,Unit& u){c.combat.choose_target(c,u);}
static bool foot(Crowd& c,const Unit& u,Vec3& p){return c.combat.target(c,u,p);}
static void taunt(Crowd& c,Handle h){c.combat.first_taunt_=h;}
static void reference(Crowd& crowd,Unit& unit){
    const auto& targets_=crowd.combat.targets_;auto first_taunt_=crowd.combat.first_taunt_;
    unit.target_handle=0;unit.external_kind=-1;
    // Gate leaders are inserted before hired allies in the source defender map.
    for(const auto& other:targets_)if(other.hp>0&&other.targetable&&other.taunting){unit.external_target=other.id;unit.external_kind=other.kind;return;}
    if(auto taunt=crowd.unit(first_taunt_);taunt&&taunt->buff_left>0){unit.target_handle=taunt->handle;return;}
    const ExternalTarget* hero=nullptr;
    for(const auto& other:targets_)if(other.kind==0&&other.hp>0&&other.targetable){hero=&other;break;}
    if(unit.retaliation>0){
        for(const auto& other:crowd.packed_source())if(other.logical_id==unit.retaliation_source&&other.alive&&other.team==1&&other.shelter_mode!=2&&horizontal(other.position,unit.position)<28){unit.target_handle=other.handle;return;}
        for(const auto& other:targets_)if(other.kind==3&&other.id==unit.retaliation_source&&other.hp>0&&other.targetable&&horizontal(other.foot,unit.position)<28){unit.external_target=other.id;unit.external_kind=other.kind;return;}
        if(hero&&horizontal(hero->foot,unit.position)<=28){unit.external_target=hero->id;unit.external_kind=0;return;}
    }
    float score=INFINITY;
    // Original order: building edge, worker, gate defender, paid ally, hero fallback.
    for(int kind:{2,1,3})for(const auto& other:targets_){
        if(other.kind!=kind||other.hp<=0||!other.targetable)continue;
        Vec3 point=kind==2?Vec3{std::clamp(unit.position.x,other.minimum.x,other.maximum.x),other.minimum.y,std::clamp(unit.position.z,other.minimum.z,other.maximum.z)}:other.foot;
        float distance=horizontal(unit.position,point);
        if(distance<score){score=distance;unit.external_target=other.id;unit.external_kind=kind;}
    }
    if(std::any_of(crowd.packed_source().begin(),crowd.packed_source().end(),[](const auto& u){return u.alive&&u.team==1;})){
        float extent=std::isfinite(score)?score:3e8f;
        // Prove the nearest root locally before considering farther cells. The
        // source score is horizontal: tall tower/deck positions remain eligible.
        for(float radius=std::min(8.0f,extent);;radius=std::min(radius*2,extent)){
            Vec3 pad{radius,3e8f,radius};
            for(auto handle:crowd.query(unit.position-pad,unit.position+pad,1,false)){
                auto other=crowd.unit(handle);if(!other||other->shelter_mode==2)continue;
                float distance=horizontal(unit.position,other->position);
                if(distance<score||(distance==score&&unit.target_handle&&other->logical_id<crowd.unit(unit.target_handle)->logical_id)){
                    score=distance;unit.target_handle=handle;unit.external_kind=-1;
                }
            }
            if(score<=radius||radius>=extent)break;
        }
    }
    if(!unit.target_handle&&unit.external_kind<0&&hero){unit.external_target=hero->id;unit.external_kind=0;}
}
};
}
using namespace army;
int main(){
 Crowd c;c.configure(4000,2000);int checks=0;
 std::mt19937 rng(1022);std::uniform_real_distribution<float> pos(-50,50);
 auto soldier=c.spawn(1,0,0,{0,0,0},192,3.9);
 std::vector<Handle> allies;
 for(int i=0;i<180;++i)allies.push_back(c.spawn(-i-1,1,11,{pos(rng),pos(rng),pos(rng)},200,.4));
 auto compare=[&](){
  auto& actual=*c.unit(soldier);Unit expected=actual;
  TargetDecisionTest::reference(c,expected);TargetDecisionTest::choose(c,actual);
  assert(actual.target_handle==expected.target_handle&&actual.external_kind==expected.external_kind);
  if(actual.external_kind>=0)assert(actual.external_target==expected.external_target);
  ++checks;
 };
 for(int round=0;round<120;++round){
  std::vector<ExternalTarget> targets;
  for(int i=0;i<110;++i){ExternalTarget t;t.id=100+i/8;t.kind=i%4;t.foot={pos(rng),pos(rng),pos(rng)};t.hp=i%7?100:0;t.targetable=i%5;t.taunting=(round%13==0&&i%29==0);t.minimum=t.foot-Vec3{2,1,2};t.maximum=t.foot+Vec3{2,1,2};targets.push_back(t);}
  std::shuffle(targets.begin(),targets.end(),rng);c.combat.set_targets(targets);
  for(size_t i=0;i<allies.size();++i){auto u=c.unit(allies[i]);u->shelter_mode=(i+round)%7==0?2:0;u->buff_left=i==0&&round%11==0?1:0;}
  TargetDecisionTest::taunt(c,allies[0]);
  for(int query=0;query<50;++query){
   auto u=c.unit(soldier);u->position={pos(rng),pos(rng),pos(rng)};u->retaliation=query%3?0:4;u->retaliation_source=query%2?-1:102;compare();
   // Every repeated target read must agree with the original first live match.
   if(u->external_kind>=0){Vec3 point,again;const ExternalTarget* expected=nullptr;
    for(const auto& t:targets)if(t.id==u->external_target&&t.kind==u->external_kind&&t.hp>0&&t.targetable){expected=&t;break;}
    assert(expected);auto p=expected->kind==2?Vec3{std::clamp(u->position.x,expected->minimum.x,expected->maximum.x),expected->minimum.y,std::clamp(u->position.z,expected->minimum.z,expected->maximum.z)}:expected->foot;
    assert(TargetDecisionTest::foot(c,*u,point)&&length(point-p)==0);assert(TargetDecisionTest::foot(c,*u,again)&&length(again-p)==0);++checks;
   }
  }
 }
 // Equal distances retain building/worker/defender priority and source order.
 c.clear();soldier=c.spawn(1,0,0,{0,0,0},192,3.9);
 ExternalTarget worker;worker.id=10;worker.kind=1;worker.hp=100;worker.foot={5,0,0};worker.minimum=worker.maximum=worker.foot;
 auto building=worker;building.id=20;building.kind=2;auto second=building;second.id=21;
 c.combat.set_targets({worker,building,second});compare();assert(c.unit(soldier)->external_target==20);++checks;
 Vec3 point;auto u=c.unit(soldier);assert(TargetDecisionTest::foot(c,*u,point));
 building.foot=building.minimum=building.maximum={9,0,0};c.combat.set_targets({second,building,worker});assert(TargetDecisionTest::foot(c,*u,point)&&point.x==9);++checks;
 building.hp=0;c.combat.set_targets({building});assert(!TargetDecisionTest::foot(c,*u,point));++checks;
 c.combat.set_targets({});compare();assert(!TargetDecisionTest::foot(c,*u,point));++checks;
 std::cout<<"ARMY_TARGET_DECISION_RESULT checks="<<checks<<" failures=0\n";
}
