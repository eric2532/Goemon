#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
namespace army {
struct SkullpionTest {
static KitData kit(){
 KitData k;k.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};k.status_bits={1,2,4,8,16,32,64};k.phase_ticks={20,20,24,30,20};k.contact_ticks={13,14,15,18};k.bullet_speed=8.64;k.bullet_life=4;k.bullet_radius=.2;k.skullpion={3,30};return k;
}
static void box(NavigationData& nav,Vec3 a,Vec3 b,int64_t owner){
 Vec3 p[]={{a.x,a.y,a.z},{a.x,a.y,b.z},{a.x,b.y,a.z},{a.x,b.y,b.z},{b.x,a.y,a.z},{b.x,a.y,b.z},{b.x,b.y,a.z},{b.x,b.y,b.z}};
 for(auto face:{std::array<int,4>{0,1,3,2},{4,6,7,5},{0,4,5,1},{2,3,7,6},{0,2,6,4},{1,5,7,3}})
  for(auto triangle:{std::array<int,3>{0,1,2},{0,2,3}}){for(int corner:triangle)nav.air_faces.push_back(p[face[corner]]);nav.air_owner.push_back(owner);}
}
static void climb(){
 NavigationData nav;nav.bounds_min={-100,0,-100};nav.bounds_max={100,0,100};
 box(nav,{-40,0,0},{40,16,6},42);
 Crowd c;c.configure(10,10);c.parallel_movement_enabled=false;c.combat.configure(kit());c.set_navigation(nav);
 auto h=c.spawn(2,0,4,{0,0,-24},30000,18);auto u=c.unit(h);
 ExternalTarget hero;hero.kind=0;hero.id=0;hero.hp=1000;hero.foot={0,0,-26};c.combat.set_targets({hero});
 auto wall=c.terrain.climb_surface(u->position,12,35);
 assert(wall.valid&&wall.owner==42&&std::abs(wall.base.z+12.05f)<.01&&std::abs(wall.crest.y-15.5f)<.01);
 // At full health, the castle takes priority over a hero standing beside him.
 auto& state=c.combat.skullpions_[h];state.wait=0;c.combat.boss_decide(c,*u,.01);
 assert(u->action==106&&u->air_phase==1&&std::abs(u->yaw)<.001);
 u->velocity.y=100; // A prior floor correction must never launch the climb.
 std::set<int> phases;float highest=0;bool hit=false;Vec3 previous=u->position;
 for(int tick=0;tick<900&&u->action==106;++tick){
  if(u->air_phase==5){hero.foot={0,0,-38};c.combat.set_targets({hero});}
  c.step(.01);phases.insert(u->air_phase);highest=std::max(highest,u->position.y);
  assert(length(u->position-previous)<.36f);assert(u->position.z<=-11.99f);assert(u->position.y>=-.001f);
  if(u->air_phase==2||u->air_phase==3)assert(std::abs(u->position.z+12.05f)<.31f);
  for(const auto& e:c.combat.events())hit|=e.kind==EXTERNAL_DAMAGE&&e.action_index==106;
  previous=u->position;
 }
 assert(phases.count(1)&&phases.count(2)&&phases.count(3)&&phases.count(5)&&phases.count(0));
 assert(highest>16.4f&&u->action==100&&u->position.y<.01f&&!hit&&state.followup);
 assert(u->position.z<-28);
 c.combat.clear_events();c.step(1.1);assert(u->action==101&&!state.followup);
 bool ground_attack=false;for(const auto& e:c.combat.events())ground_attack|=e.kind==EXTERNAL_DAMAGE&&e.action_index==101;
 assert(ground_attack);
 // Removing the supporting castle collision makes him fall instead of hovering.
 c.set_pose(h,{0,0,-12.05f},0);u=c.unit(h);state.climb=wall;c.combat.boss_enter(*u,6,wall.crest);
 for(int i=0;i<600&&u->position.y<8;++i)c.step(.01);
 assert(u->position.y>=8);
 float before=u->position.y;c.set_navigation(NavigationData{});c.step(.1);
 assert(u->air_phase==4&&u->position.y<before);
 for(int i=0;i<500&&u->action==106;++i)c.step(.01);
 assert(u->action==100&&u->position.y<.01f);
 // Breaking armor at height interrupts the grip and settles under gravity.
 c.set_navigation(nav);c.set_pose(h,{0,0,-12.05f},0);u=c.unit(h);u->hp=30000;state.climb=wall;state.armor=0;c.combat.boss_enter(*u,6,wall.crest);
 for(int i=0;i<600&&u->position.y<8;++i)c.step(.01);
 assert(u->position.y>=8);
 Hit hit_core;hit_core.amount=1000;hit_core.heavy=true;
 for(int i=0;i<8;++i)c.combat.hit(c,h,hit_core);
 assert(u->action==107);before=u->position.y;c.step(.1);assert(u->position.y<before);
 c.step(4.1);assert(u->action==100&&u->position.y<.01f);
 // Unsupported gate headers, open fields and walls behind another solid are rejected.
 NavigationData header;box(header,{-40,11,0},{40,22,6},43);c.set_navigation(header);
 assert(!c.terrain.climb_surface({0,0,-24},12,35).valid);
 c.set_navigation(NavigationData{});assert(!c.terrain.climb_surface({0,0,-24},12,35).valid);
 NavigationData low;box(low,{-40,0,0},{40,16,6},42);box(low,{15,0,-25},{25,6,-15},47);c.set_navigation(low);
 assert(c.terrain.climb_surface({0,0,-30},12,35).owner==42);
 box(nav,{-40,0,-20},{40,4,-18},44);c.set_navigation(nav);assert(!c.terrain.climb_surface({0,0,-40},12,35).valid);
 // Rotation and a raised foundation use the same real face query.
 NavigationData rotated;box(rotated,{0,-3,-40},{6,22,40},45);c.set_navigation(rotated);
 auto side=c.terrain.climb_surface({-24,0,0},12,35);assert(side.valid&&side.normal.x<-.99&&std::abs(side.base.x+12.05f)<.01);
 // An overhang stops ascent; he releases and returns to a supported floor.
 NavigationData ceiling;box(ceiling,{-40,0,0},{40,16,6},42);box(ceiling,{-40,28,-40},{40,30,6},46);c.set_navigation(ceiling);
 c.set_pose(h,{0,0,-12.05f},0);u=c.unit(h);state.climb=wall;c.combat.boss_enter(*u,6,wall.crest);highest=0;
 for(int i=0;i<800&&u->action==106;++i){c.step(.01);highest=std::max(highest,u->position.y);}
 assert(highest<4.1f&&u->action==100&&u->position.y<.01f);
}
static void pattern(){
 NavigationData nav;nav.bounds_min={-100,0,-100};nav.bounds_max={100,0,100};box(nav,{-40,0,0},{40,16,6},42);
 nav.obstacle_min={{-40,0,0}};nav.obstacle_max={{40,16,6}};
 Crowd c;c.configure(10,10);c.parallel_movement_enabled=false;c.combat.configure(kit());c.set_navigation(nav);
 ExternalTarget fort;fort.kind=2;fort.id=42;fort.hp=100000;fort.minimum={-40,0,0};fort.maximum={40,16,6};fort.foot={0,0,3};
 ExternalTarget hero;hero.kind=0;hero.hp=100000;hero.foot={0,0,-72};c.combat.set_targets({hero,fort});
 auto h=c.spawn(10,0,4,{-20,0,-70},30000,18),second=c.spawn(11,0,4,{20,0,-70},30000,18);
 c.combat.skullpions_[h].wait=0;c.combat.boss_decide(c,*c.unit(h),.01);
 assert(c.unit(h)->has_goal&&c.unit(h)->goal.z>-30&&c.unit(h)->action==100);
 int attacks[2]={},jumps[2]={};bool landed[2]={},jumping[2]={};int64_t handles[]={h,second};
 for(int tick=0;tick<5000&&(attacks[0]<2||attacks[1]<2);++tick){
  c.step(.02);
  for(int i=0;i<2;++i){auto u=c.unit(handles[i]);
   if(u->action==106&&u->air_phase==5&&!jumping[i]){++jumps[i];jumping[i]=true;}
   if(u->action==100&&jumping[i]){assert(u->position.y<.02);landed[i]=true;jumping[i]=false;}
   if(u->action>=101&&u->action<=108&&u->action!=106&&landed[i]){++attacks[i];landed[i]=false;assert(jumps[i]==attacks[i]);}
  }
 }
 assert(attacks[0]>=2&&attacks[1]>=2&&jumps[0]>=2&&jumps[1]>=2);
 for(const auto& event:c.combat.events())assert(event.kind!=EXTERNAL_DAMAGE||event.action_index!=106);
}
static void sand_beam(){
 for(double dt:{1.0/20,1.0/30,1.0/60}){
  Crowd c;c.configure(128,128);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));
  NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};c.set_navigation(nav);
  auto h=c.spawn(1,0,4,{0,0,0},30000,18);auto u=c.unit(h);
  ExternalTarget hero;hero.hp=10000;hero.foot={0,0,200};c.combat.set_targets({hero});
  c.combat.boss_enter(*u,3,hero.foot);c.combat.clear_events();
  double elapsed=0;int pulses=0;double first=0;
  while(u->action_active){c.step(dt);elapsed+=dt;for(auto e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){++pulses;if(!first)first=elapsed;}c.combat.clear_events();}
  assert(pulses==9&&first>=2.33/5&&first<=2.33/5+dt+.00001&&elapsed<2.9);
  // Fitted beam width, finite end plane and side cover match the held player's rules.
  u->position={0,0,0};u->yaw=0;hero.foot={12,0,200};c.combat.set_targets({hero});c.combat.boss_sand(c,*u);assert(c.combat.events().size()==1);c.combat.clear_events();
  for(auto point:{Vec3{40,0,200},Vec3{0,0,280},Vec3{0,0,-5}}){hero.foot=point;c.combat.set_targets({hero});c.combat.boss_sand(c,*u);assert(c.combat.events().empty());}
  nav.obstacle_min={{-3,0,100}};nav.obstacle_max={{3,20,101}};c.set_navigation(nav);hero.foot={0,0,200};c.combat.set_targets({hero});c.combat.boss_sand(c,*u);assert(c.combat.events().empty());
  ExternalTarget fort;fort.kind=2;fort.id=42;fort.hp=10000;fort.minimum={-3,0,100};fort.maximum={3,20,101};nav.ray_owner={42};c.set_navigation(nav);c.combat.set_targets({hero,fort});c.combat.boss_sand(c,*u);
  assert(c.combat.events().size()==1&&c.combat.events()[0].target_id==42);c.combat.clear_events();nav.ray_owner.clear();
  nav.obstacle_min={{4,0,100}};nav.obstacle_max={{9,20,101}};c.set_navigation(nav);hero.foot={12,0,200};c.combat.set_targets({hero});c.combat.boss_sand(c,*u);assert(c.combat.events().empty());
  nav.obstacle_min.clear();nav.obstacle_max.clear();c.set_navigation(nav);c.combat.set_targets({});
  std::vector<ExternalTarget> victims;
  for(int i=0;i<12;++i){ExternalTarget victim;victim.id=100+i;victim.hp=10000;victim.foot={float(i*70),0,200};victims.push_back(victim);}
  c.combat.set_targets(victims);c.combat.clear_events();
  for(int i=0;i<12;++i){auto boss=c.spawn(i+2,0,4,{float(i*70),0,0},30000,18);c.unit(boss)->external_kind=0;c.unit(boss)->external_target=100+i;c.combat.boss_enter(*c.unit(boss),3,{float(i*70),0,200});}
  int pulses_by_boss[12]={};
  for(int frame=0;frame<int(3/dt);++frame){c.step(dt);for(auto e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE&&e.source_id>=2&&e.source_id<14)++pulses_by_boss[e.source_id-2];c.combat.clear_events();}
  for(auto pulses:pulses_by_boss)assert(pulses==9);
  assert(c.combat.projectiles_.empty());
 }
}
static void run(){
 sand_beam();
 Crowd c;c.configure(20,20);c.parallel_movement_enabled=false;assert(c.combat.configure(kit()));
 NavigationData nav;nav.width=21;nav.spacing=10;nav.origin={-100,0,-100};nav.bounds_min={-100,0,-100};nav.bounds_max={100,0,100};nav.heights.resize(441);nav.covered.resize(441,1);c.set_navigation(nav);
 auto h=c.spawn(1,0,4,{0,0,0},10000,18.0f);auto u=c.unit(h);
 assert(c.combat.enemy_contact(*u,{40,40,40}).x==15);
 assert(c.combat.enemy_contact(*u,{40,40,40}).y==25);
 assert(c.combat.enemy_contact(*u,{40,40,40}).z==20);
 assert(c.combat.enemy_segment(*u,{-40,24,0},{40,24,0},0)>=0);
 assert(c.combat.enemy_segment(*u,{-40,26,0},{40,26,0},0)<0);
 ExternalTarget hero;hero.kind=0;hero.id=0;hero.hp=1000;hero.foot={0,0,5};c.combat.set_targets({hero});
 Hit hit;hit.amount=100;auto armor=c.combat.hit(c,h,hit);assert(armor.accepted&&std::abs(armor.hp-9985)<.01);
 hit.amount=300;hit.heavy=true;
 for(int i=0;i<7;++i){c.combat.hit(c,h,hit);assert(u->action!=107);}
 c.combat.hit(c,h,hit);assert(u->action==107);
 double before=u->hp;hit.heavy=false;hit.amount=100;c.combat.hit(c,h,hit);assert(std::abs(before-u->hp-100)<.01);
 c.step(4.1);assert(u->action!=107);
 c.combat.boss_enter(*u,6,{0,5,5});
 hit.amount=300;hit.heavy=true;
 for(int i=0;i<7;++i){c.combat.hit(c,h,hit);assert(u->action==106);}
 c.combat.hit(c,h,hit);assert(u->action==107);
 c.step(4.1);assert(u->action!=107);
 std::set<int> moves;
 for(int move=1;move<=5;++move){
  c.set_pose(h,{0,0,0},0);c.combat.clear_events();u=c.unit(h);u->stun=0;u->frozen=0;
  hero.foot={0,0,move==3?30.0f:5.0f};c.combat.set_targets({hero});
  Vec3 aim=move==6?Vec3{0,5,5}:hero.foot;
  c.combat.boss_enter(*u,move,aim);c.step(move==3||move==5?4.65:(move==2?3.29:(move==6?3.99:2.49)));
  bool damage=false,poison=false;
  for(const auto& e:c.combat.events()){if(e.kind==EXTERNAL_DAMAGE&&e.amount>0){damage=true;poison|=e.action_index==105;}if(e.kind==STATUS_EVENT&&e.unit_kind==4)moves.insert(e.action_index);}
  assert(damage);if(move==5)assert(poison);assert(finite(u->position));
 }
 assert(moves.size()==5);
 // Source phase-three volley releases three independently simulated bouncing shots.
 c.set_pose(h,{0,0,0},0);u=c.unit(h);c.combat.set_targets({});c.combat.clear_events();
 c.combat.boss_enter(*u,8,{0,0,60});c.step(2.34);
 assert(c.combat.projectiles_.size()==3);
 auto initial_ball=c.combat.projectiles_[0].position;
 for(int i=0;i<50;++i)c.step(.02);
 assert(c.combat.projectiles_.size()==3&&length(c.combat.projectiles_[0].position-initial_ball)>10);
 bool bounce=false;for(const auto& e:c.combat.events())bounce|=e.kind==PROJECTILE_IMPACT&&e.unit_kind==4&&e.amount==1;
 assert(bounce);
 c.combat.projectiles_.clear();hero.foot={0,0,30};c.combat.set_targets({hero});c.combat.clear_events();
 c.set_pose(h,{0,0,0},0);u=c.unit(h);c.combat.boss_enter(*u,8,hero.foot);c.step(2.34);
 for(int i=0;i<20;++i)c.step(.02);
 bool volley_damage=false;for(const auto& e:c.combat.events())volley_damage|=e.kind==EXTERNAL_DAMAGE&&e.unit_kind==4&&e.action_index==108;
 assert(volley_damage);c.combat.projectiles_.clear();
 // Low targets can jump over a tail sweep; a wall blocks sand damage.
 c.combat.clear_events();u=c.unit(h);u->position={0,0,0};u->yaw=0;hero.foot={0,2,5};c.combat.set_targets({hero});c.combat.boss_area(c,*u,u->position,14,30,3.15f,false,true);
 assert(c.combat.events().empty());
 nav.obstacle_min={{-5,0,2}};nav.obstacle_max={{5,8,3}};c.set_navigation(nav);hero.foot={0,0,5};c.combat.set_targets({hero});c.combat.boss_area(c,*u,u->position,25,30,.3f);assert(c.combat.events().empty());
 c.combat.clear_events();nav.obstacle_min.clear();nav.obstacle_max.clear();c.set_navigation(nav);
 hero.foot={0,0,30};c.combat.set_targets({hero});c.combat.boss_area(c,*u,u->position,8,30,3.15f);
 assert(!c.combat.events().empty());hero.foot={0,0,41};c.combat.set_targets({hero});c.combat.clear_events();
 c.combat.boss_area(c,*u,u->position,8,30,3.15f);assert(c.combat.events().empty());
 hero.foot={0,0,5};c.combat.set_targets({hero});
 // Source phase gating: the first four moves remain available; later phases add drill/climb.
 nav.obstacle_min.clear();nav.obstacle_max.clear();c.set_navigation(nav);c.set_pose(h,{0,0,0},0);u=c.unit(h);u->action_active=false;u->hp=u->max_hp;auto& b=c.combat.skullpions_[h];b.wait=0;b.serial=4;c.combat.boss_decide(c,*u,.01);assert(u->action==101);
 u->action_active=false;u->hp=u->max_hp*.25;b.wait=0;b.serial=4;c.combat.boss_decide(c,*u,.01);assert(u->action==105);
 auto bad=kit();bad.skullpion={-1,30};assert(!c.combat.configure(bad));
 c.combat.configure(kit());c.despawn(h);assert(c.combat.skullpions_.empty());
 c.combat.clear();assert(c.combat.skullpions_.empty());
 climb();
 pattern();
 std::cout<<"Skullpion: castle priority at full HP, climb/jump/ground attack, removed support, ceiling, core interrupt, volley, armor and lifecycle PASS\n";
}
};}
int main(){army::SkullpionTest::run();}
