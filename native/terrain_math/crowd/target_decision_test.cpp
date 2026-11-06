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
static void large_body(){
 Crowd c;c.configure(10,10);c.set_navigation(NavigationData{});auto h=c.spawn(1,0,0,{16,0,0},100,1);auto& u=*c.unit(h);u.external_kind=0;
 ExternalTarget hero;hero.kind=0;hero.hp=100;hero.minimum={-15,0,-20};hero.maximum={15,25,20};c.combat.set_targets({hero});
 Vec3 point;assert(c.combat.target(c,u,point)&&point.x==15&&point.y==0);
 auto& k=c.combat.soldiers_[0].kit;k[9]=0;k[10]=1;k[11]=0;k[12]=-2;k[13]=1;k[14]=0;k[15]=.2;
 assert(c.combat.melee_contact(c,u));
 u.position.x=18;assert(!c.combat.melee_contact(c,u));
 auto fire=[&](float height){Projectile p;p.source_team=0;p.source_id=1;p.owner_kind=1;p.position={17,height,0};p.direction={-1,0,0};p.speed=120;p.life=2;p.radius=.2;p.damage=5;c.combat.projectiles_.push_back(p);c.combat.projectiles(c,.05);};
 fire(20);assert(c.combat.events().size()==2&&c.combat.events()[0].kind==EXTERNAL_DAMAGE);
 c.combat.clear_events();fire(26);assert(c.combat.events().empty());c.combat.projectiles_.clear();
 hero.minimum=hero.maximum={};c.combat.set_targets({hero});u.position={16,0,0};assert(!c.combat.melee_contact(c,u));
 c.combat.clear_events();fire(1);assert(c.combat.events().empty());
}
static void taunt(Crowd& c,Handle h){c.combat.first_taunt_=h;}

};
}
using namespace army;
static ExternalTarget point(int id,Vec3 position,int kind=1){ExternalTarget t;t.id=id;t.kind=kind;t.hp=100;t.foot=t.minimum=t.maximum=position;return t;}
static ExternalTarget building(int id,Vec3 low,Vec3 high,int priority=0){auto t=point(id,(low+high)*.5f,2);t.minimum=low;t.maximum=high;t.assault_priority=priority;return t;}
static NavigationData ground(){NavigationData d;d.origin={-60,0,-60};d.width=81;d.spacing=3;d.heights.assign(81*81,0);d.covered.assign(81*81,1);return d;}
static void enclose(NavigationData& d){d.obstacle_min={{-9,0,-9},{3,0,-9},{-9,0,-9},{-9,0,3}};d.obstacle_max={{-3,20,9},{9,20,9},{9,20,-3},{9,20,9}};}
int main(){
 TargetDecisionTest::large_body();int checks=0;
 Crowd c;c.configure(4000,2000);auto nav=ground();c.set_navigation(nav);
 auto h=c.spawn(1,0,0,{-30,0,0},100,1.3);auto& u=*c.unit(h);
 auto choose=[&](){TargetDecisionTest::choose(c,u);++checks;};
 // A closer target sealed behind solids must lose to a farther reachable one.
 enclose(nav);c.set_navigation(nav);auto trapped=point(10,{0,0,0}),open=point(11,{-30,0,42});
 c.combat.set_targets({trapped,open});choose();assert(u.external_target==11&&u.external_kind==1);
 c.combat.set_targets({trapped});choose();assert(u.external_kind<0&&!u.target_handle&&!u.has_goal);
 // Unreachable taunts and retaliation cannot pin an enemy to the same obstacle.
 c.set_pose(h,{-24,0,0},0);trapped.taunting=true;c.combat.set_targets({trapped,open});choose();assert(u.external_target==11);
 auto ally=c.spawn(-1,1,11,{0,0,0},100,.4);c.unit(ally)->buff_left=10;TargetDecisionTest::taunt(c,ally);
 u.retaliation=4;u.retaliation_source=-1;c.combat.set_targets({trapped,open});choose();assert(u.external_target==11);
 c.despawn(ally);TargetDecisionTest::taunt(c,0);u.retaliation=0;
 // The shrine is the objective; a reachable gate is the breach target until it opens.
 auto shrine=building(20,{-2,0,-2},{2,10,2},2),gate=building(21,{-9,0,-9},{-3,20,9},1);
 auto distraction=building(22,{-38,0,36},{-32,8,42});
 c.combat.set_targets({distraction,shrine,gate});choose();assert(u.external_target==21);
 nav.obstacle_min.erase(nav.obstacle_min.begin());nav.obstacle_max.erase(nav.obstacle_max.begin());c.set_navigation(nav);
 c.combat.set_targets({distraction,shrine});choose();assert(u.external_target==20);
 // A nearby reachable defender can intercept the assault; one behind the wall cannot.
 auto defender=c.spawn(-2,1,11,{-30,0,8},100,.4);choose();assert(u.target_handle==defender);
 c.despawn(defender);
 // Nearby players remain targets without an assault building; hidden, dead and
 // unreachable players cannot distract troops from a reachable objective.
 auto hero=point(0,{-24,0,8},0);c.combat.set_targets({distraction,hero});choose();assert(u.external_kind==0);
 hero.targetable=false;c.combat.set_targets({distraction,hero});choose();assert(u.external_target==22&&u.external_kind==2);
 hero.targetable=true;hero.hp=0;c.combat.set_targets({distraction,hero});choose();assert(u.external_target==22);
 hero.hp=100;hero.foot=hero.minimum=hero.maximum={0,0,0};enclose(nav);c.set_navigation(nav);
 c.combat.set_targets({shrine,gate,hero});choose();assert(u.external_target==21&&u.external_kind==2);
 // Closing the route invalidates connectivity immediately; reopening restores it.
 enclose(nav);c.set_navigation(nav);c.combat.set_targets({shrine,gate});choose();assert(u.external_target==21);
 nav=ground();nav.obstacle_min={{-1.25f,0,-1.25f}};nav.obstacle_max={{1.25f,1000,1.25f}};c.set_navigation(nav);
 // The goal lies beyond a real trunk: choose it, follow the detour and stay clear.
 c.combat.set_targets({point(30,{30,0,0})});choose();assert(u.external_target==30);
 for(int hz:{20,30,60}){
  c.set_pose(h,{-30,0,0},0);u.routing=false;c.set_goal(h,{30,0,0},6);
  float detour=0;
  for(int tick=0;tick<hz*30;++tick){c.step(1.0/hz);assert(c.terrain.clear(u.position,u.radius,0));detour=std::max(detour,std::abs(u.position.z));}
  assert(length(u.position-Vec3{30,0,0})<.1f&&detour>2.5f);++checks;
 }
 // A blocked closest building face still allows another clear approach.
 c.set_pose(h,{-12,0,0},0);auto fort=building(40,{6,0,-6},{18,10,6},2);
 nav.obstacle_min.push_back(fort.minimum);nav.obstacle_max.push_back(fort.maximum);c.set_navigation(nav);c.combat.set_targets({fort});choose();
 assert(u.external_target==40&&c.terrain.clear(u.target_goal,u.radius,0)&&c.terrain.reachable(u.position,u.target_goal,u.radius,0));
 for(int tick=0;tick<1800;++tick){c.set_goal(h,u.target_goal,6);c.step(1.0/60);assert(c.terrain.clear(u.position,u.radius,0));}
 assert(length(u.position-u.target_goal)<.1f);
 // Body width matters at a narrow passage, even when a small troop can pass.
 nav=ground();nav.obstacle_min={{-3,0,-60},{-3,0,3}};nav.obstacle_max={{3,20,-3},{3,20,180}};
 c.set_pose(h,{-30,0,0},0);u.radius=3.9f;c.set_navigation(nav);
 c.combat.set_targets({point(60,{30,0,0}),point(61,{-30,0,100})});choose();assert(u.external_target==61);
 u.radius=1.3f;c.set_navigation(nav);choose();assert(u.external_target==60);
 // Same id, new position and death retain the external row lifetime contract.
 auto worker=point(50,{-12,0,20});c.combat.set_targets({worker});choose();Vec3 foot;
 worker.foot=worker.minimum=worker.maximum={-12,0,30};c.combat.set_targets({worker});assert(TargetDecisionTest::foot(c,u,foot)&&foot.z==30);++checks;
 worker.hp=0;c.combat.set_targets({worker});choose();assert(u.external_kind<0);
 // March on the castle; only nearby military buildings interrupt the assault.
 nav=ground();c.set_navigation(nav);c.set_pose(h,{-30,0,0},0);
 shrine=building(20,{20,0,-4},{28,10,4},2);
 auto barracks=building(70,{60,0,-4},{68,12,4},4),tower=building(71,{-4,0,20},{4,18,28},4);
 c.combat.set_targets({shrine,barracks,tower});choose();assert(u.external_kind==2&&u.external_target==20);
 c.set_pose(h,{-10,0,20},0);choose();assert(u.external_target==71);
 worker=point(50,{-9,0,20});c.combat.set_targets({worker,shrine,barracks,tower});choose();assert(u.external_target==71);
 tower.hp=0;c.combat.set_targets({shrine,barracks,tower});choose();assert(u.external_target==20);
 tower.hp=100;tower.targetable=false;c.combat.set_targets({shrine,tower});choose();assert(u.external_target==20);
 tower.targetable=true;barracks=building(70,{-8,0,30},{0,12,38},4);c.combat.set_targets({shrine,barracks});choose();assert(u.external_target==70);
 c.set_pose(h,{-50,0,20},0);choose();assert(u.external_target==20);
 // Measure aggro from the footprint edge, including the exact 28-unit boundary.
 c.set_pose(h,{-32,0,20},0);c.combat.set_targets({shrine,tower});choose();assert(u.external_target==71);
 c.set_pose(h,{-32.1f,0,20},0);choose();assert(u.external_target==20);
 hero=point(0,{-30,0,20},0);c.combat.set_targets({shrine,tower,hero});choose();assert(u.external_kind==0);
 c.combat.set_targets({shrine,tower});defender=c.spawn(-3,1,11,{-30,0,20},100,.4);choose();assert(u.target_handle==defender);c.despawn(defender);
 hero.taunting=true;c.combat.set_targets({shrine,tower,hero});choose();assert(u.external_kind==0);
 hero.taunting=false;u.retaliation=4;u.retaliation_source=0;c.combat.set_targets({shrine,tower,hero});choose();assert(u.external_kind==0);u.retaliation=0;
 // Sealed nearby defenses cannot pin an assault: breach the gate first.
 c.set_pose(h,{-24,0,0},0);enclose(nav);c.set_navigation(nav);
 tower=building(71,{-2,0,-2},{2,18,2},4);shrine=building(20,{-2,0,-2},{2,10,2},2);gate=building(21,{-9,0,-9},{-3,20,9},1);
 c.combat.set_targets({tower,shrine,gate});choose();assert(u.external_target==21);
 nav.obstacle_min.erase(nav.obstacle_min.begin());nav.obstacle_max.erase(nav.obstacle_max.begin());c.set_navigation(nav);
 c.combat.set_targets({tower,shrine});choose();assert(u.external_target==71);
 tower.hp=0;c.combat.set_targets({tower,shrine});choose();assert(u.external_target==20);
 // With no reachable contact, advance toward the main base on clear ground.
 nav=ground();enclose(nav);c.set_navigation(nav);c.set_pose(h,{-48,0,0},0);
 c.combat.set_targets({shrine});choose();assert(u.external_kind<0&&u.has_goal&&u.base_marching);
 assert(horizontal(u.target_goal,shrine.foot)<horizontal(u.position,shrine.foot));
 assert(c.terrain.reachable(u.position,u.target_goal,u.radius,0));
 auto distant_worker=point(90,{-48,0,70});auto distant_ally=c.spawn(-90,1,11,{-48,0,80},100,.4);
 c.combat.set_targets({shrine,distant_worker});choose();assert(u.external_kind<0&&u.has_goal);c.despawn(distant_ally);
 auto staging=u.target_goal;choose();assert(length(staging-u.target_goal)<.001f); // reuse without inventing a combat target
 c.combat.set_targets({shrine,gate});choose();assert(u.external_target==21&&!u.base_marching);
 // Death and stealth discard the old target and immediately resume the base assault.
 nav=ground();c.set_navigation(nav);c.set_pose(h,{-30,0,0},0);
 shrine=building(20,{20,0,-4},{28,10,4},2);hero=point(0,{-28,0,0},0);
 c.combat.set_targets({shrine,hero});choose();assert(u.external_kind==0);
 hero.targetable=false;c.combat.set_targets({shrine,hero});choose();assert(u.external_kind==2&&u.external_target==20);
 hero.targetable=true;hero.hp=0;c.combat.set_targets({shrine,hero});choose();assert(u.external_target==20);
 c.combat.set_targets({});choose();assert(!u.has_goal&&u.external_kind<0);
 std::cout<<"ARMY_TARGET_DECISION_RESULT checks="<<checks<<" failures=0\n";
}
