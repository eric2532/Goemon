#include "core.h"
#include "instance_buffers.h"
#include <cassert>
#include <iostream>
#include <limits>
namespace army {
struct PetGeometryTest {
 static bool contact(Crowd& c,const Unit& u){return c.combat.melee_contact(c,u);}
 static float segment(Crowd& c,const Unit& u,Vec3 a,Vec3 b){return c.combat.enemy_segment(u,a,b,0);}
 static Vec3 nearest(Crowd& c,const Unit& u,Vec3 p){return c.combat.enemy_contact(u,p);}
 static void shot(Crowd& c,Vec3 point){Projectile p;p.position=point+Vec3{0,0,1};p.direction={0,0,-1};p.speed=20;p.life=2;p.damage=30;p.tail=2;p.radius=.01f;c.combat.projectiles_.push_back(p);c.combat.projectiles(c,.1);}
};
}
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={3000,4.2f,30,3.4f,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};
 d.melee_from={0,1.1f,-.3f};d.melee_to={0,1.4f,-3.8f};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=15;d.slime_attacks[i+3]=135;}
 for(int i=0;i<HOUND_SKINS+SLIME_SKINS+5;++i)d.pet_geometry.insert(d.pet_geometry.end(),{-.9f,0,-.75f,.9f,3.4f,.75f,1});
 auto goblin=d.pet_geometry.data()+(HOUND_SKINS+1)*7;
 goblin[0]=-.65f;goblin[2]=-.55f;goblin[3]=.65f;goblin[4]=2.25f;goblin[5]=.55f;goblin[6]=.73f;
 auto tree=d.pet_geometry.data()+(HOUND_SKINS+4)*7;
 tree[0]=-1.55f;tree[2]=-1.2f;tree[3]=1.55f;tree[4]=6.12f;tree[5]=1.2f;tree[6]=1.15f;
 return d;
}
static NavigationData wall(float z){NavigationData d;d.ray_min={{-4,0,z-.1f}};d.ray_max={{4,10,z+.1f}};d.ray_owner={-1};return d;}
int main(){
 InstanceRow casting;casting.kind=SLIME_KIND;casting.team=0;casting.pose_row=2;casting.hp=casting.max_hp=1000;casting.action=GUARDIAN_CAST;casting.render_time=.7;
 auto cast_buffer=instance_buffers({casting},{});assert(cast_buffer.valid&&cast_buffer.submitted==1&&int(cast_buffer.batches[0].buffer[13])%8==7&&cast_buffer.batches[0].buffer[14]==.7f);
 casting.action=GUARDIAN_ARRIVAL;auto entry_buffer=instance_buffers({casting},{});assert(entry_buffer.valid&&entry_buffer.submitted==0);
 auto data=kits();assert(valid_kit_data(data));
 for(int invalid=0;invalid<4;++invalid){auto bad=data;
  if(invalid==0)bad.pet_geometry.pop_back();
  if(invalid==1)bad.pet_geometry[6]=0;
  if(invalid==2)bad.pet_geometry[4]=bad.pet_geometry[1];
  if(invalid==3)bad.pet_geometry[0]=std::numeric_limits<float>::quiet_NaN();
  assert(!valid_kit_data(bad));
 }
 Crowd c;c.configure(10,10);assert(c.combat.configure(data));c.set_navigation({});
 auto h=c.spawn(1,0,SLIME_KIND,{0,0,0},3000,.65);auto u=c.unit(h);u->pose_row=1;u->yaw=0;
 assert(PetGeometryTest::segment(c,*u,{-4,2.2f,0},{4,2.2f,0})>=0);
 assert(PetGeometryTest::segment(c,*u,{-4,2.3f,0},{4,2.3f,0})<0);
 assert(PetGeometryTest::nearest(c,*u,{0,10,0}).y==2.25f);
 u->pose_row=4;
 assert(PetGeometryTest::segment(c,*u,{-4,6,0},{4,6,0})>=0);
 assert(PetGeometryTest::segment(c,*u,{-4,6.2f,0},{4,6.2f,0})<0);
 u->pose_row=1;
 ExternalTarget hero;hero.id=0;hero.kind=0;hero.hp=10000;hero.foot={0,0,-1.6f};c.combat.set_targets({hero});u->external_kind=0;u->external_target=0;
 assert(PetGeometryTest::contact(c,*u));
 c.set_navigation(wall(-2.3f));assert(PetGeometryTest::contact(c,*u)); // Wall beyond victim.
 c.set_navigation(wall(-.8f));assert(!PetGeometryTest::contact(c,*u)); // Wall between bodies.
 c.set_navigation(wall(-2.3f));
 bool hit=false;
 for(int i=0;i<120;++i){c.step(1.0/60);for(auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.amount==30);hit=true;}c.combat.clear_events();}
 assert(hit);
 auto companions=data;
 companions.soldier_kinds.push_back(HOUND_KIND);
 companions.soldier_profiles.insert(companions.soldier_profiles.end(),{3000,4.5f,30,3.4f,6,1.75f});
 companions.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<companions.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){companions.hound_attacks[i]=30;companions.hound_attacks[i+1]=1;companions.hound_attacks[i+2]=15;companions.hound_attacks[i+3]=i/(8*HOUND_TIMELINE_STRIDE)>=41?138:131;}
 for(int cue:{110,138,191,117,143,161}){auto trial=companions;trial.hound_attacks[3]=cue;assert(valid_kit_data(trial));}
 for(int sound:{0,112,114,116,152,159,162,164,165,171,173,175,180,182,183,184,187,190,214,254,255,282,288,290,296,301,314,316,318,319,321,332,429})for(int tag:{10000,20000}){auto trial=companions;trial.hound_attacks[3]=tag+sound;assert(valid_kit_data(trial));}
 for(int cue:{0,162,173,180,183,184,187,282,301,316,318,319,321,332,20188}){auto trial=companions;trial.hound_attacks[3]=cue;assert(!valid_kit_data(trial));}
 // Dragon-lizard 138 and bee 143 are impacts; swings, aura and buzz are presentation cues.
 for(int cue:{110,138,191,117,143,161,20131,10140,20180,20183,10184,10187,10000})for(float tick:{0.f,15.f}){
  auto trial=companions;for(size_t i=0;i<trial.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){trial.hound_attacks[i+2]=tick;trial.hound_attacks[i+3]=cue;}
  Crowd battle;battle.configure(10,10);assert(battle.combat.configure(trial));battle.set_navigation({});
  auto handle=battle.spawn(-1,0,HOUND_KIND,{0,0,0},3000,.5);auto pet=battle.unit(handle);pet->pose_row=HOUND_SKINS-1;
  ExternalTarget target;target.id=0;target.kind=0;target.hp=10000;target.foot={0,0,-1.5f};battle.combat.set_targets({target});pet->external_kind=0;pet->external_target=0;
  bool damage=false,audio=false;int hits=0,sounds=0;
  for(int i=0;i<180;++i){battle.step(1.0/60);for(auto& e:battle.combat.events()){if(e.kind==EXTERNAL_DAMAGE){assert(e.amount==30);damage=true;++hits;}if(e.action_index==HOUND_CUE_BASE+cue%10000){audio=true;++sounds;}}battle.combat.clear_events();}
  assert(audio==(cue%10000!=0)&&damage==(cue==138||cue==143||cue==10140||cue==10184||cue==10187||cue==10000));
  if(damage&&audio)assert(hits==sounds);
 }
 for(int skin=0;skin<HOUND_SKINS;++skin)for(int outside=0;outside<2;++outside){
  Crowd pets;pets.configure(10,10);assert(pets.combat.configure(companions));pets.set_navigation({});
  auto handle=pets.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);auto pet=pets.unit(handle);pet->pose_row=skin;
  PetGeometryTest::shot(pets,{0,outside?3.5f:3.3f,0});
  assert(pet->hp==(outside?3000:2970)); // Above the former generic 1.8m body, through the real projectile broad phase.
 }
 // A hovering bee's shadow is not its body: low shots pass beneath, body-height shots hit.
 auto hovering=companions;auto bee=hovering.pet_geometry.data()+(HOUND_SKINS-1)*7;bee[1]=.6f;bee[4]=2.1f;
 for(float height:{.5f,1.2f,2.2f}){
  Crowd pets;pets.configure(10,10);assert(pets.combat.configure(hovering));pets.set_navigation({});
  auto handle=pets.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);pets.unit(handle)->pose_row=HOUND_SKINS-1;
  PetGeometryTest::shot(pets,{0,height,0});assert(pets.unit(handle)->hp==(height==1.2f?2970:3000));
 }
 auto ordinary=data;ordinary.pet_geometry.clear();assert(c.combat.configure(ordinary));
 assert(PetGeometryTest::segment(c,*u,{-4,2.3f,0},{4,2.3f,0})<0); // Ordinary fitted soldier default remains 2.016.
 for(int hz:{20,30,60}){
  Crowd elites;elites.configure(16,16);elites.set_navigation({});assert(elites.combat.configure(data));
  auto elite=elites.spawn(100,0,SLIME_KIND,{0,0,0},9000,.65f);
  auto normal=elites.spawn(101,0,SLIME_KIND,{20,0,0},3000,.65f);
  elites.unit(elite)->pose_row=elites.unit(normal)->pose_row=1;
  assert(!elites.set_body_scale(0,2)&&!elites.set_body_scale(elite,0)&&!elites.set_body_scale(elite,std::numeric_limits<float>::quiet_NaN()));
  assert(elites.set_body_scale(elite,2)&&elites.set_body_scale(elite,2));
  auto e=elites.unit(elite);assert(e->radius==1.3f&&e->hp==9000&&elites.unit(normal)->radius==.65f);
  assert(PetGeometryTest::nearest(elites,*e,{0,10,0}).y==4.5f);
  assert(PetGeometryTest::segment(elites,*e,{-4,4.4f,0},{4,4.4f,0})>=0);
  assert(PetGeometryTest::segment(elites,*e,{-4,4.6f,0},{4,4.6f,0})<0);
  assert(elites.combat.configure(data,&elites)&&PetGeometryTest::nearest(elites,*e,{0,10,0}).y==4.5f);
  assert(elites.set_enemy_scaling(elite,3,3));
  ExternalTarget hero;hero.kind=0;hero.hp=10000;hero.foot={0,0,-2};elites.combat.set_targets({hero});e->external_kind=0;
  int contacts=0;
  for(int tick=0;tick<hz*2;++tick){elites.step(1.0/hz);for(const auto& event:elites.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.source_id==100){assert(event.amount==90);++contacts;}elites.combat.clear_events();}
  assert(contacts>0);
  InstanceRow row;row.kind=SLIME_KIND;row.pose_row=1;row.body_scale=2;row.position=e->position;
  auto packed=instance_buffers({row},{});assert(packed.valid&&packed.batches[0].buffer[5]==2&&packed.batches[0].body_scale==2);
  Hit lethal;lethal.amount=10000;assert(elites.combat.hit(elites,elite,lethal).dead);
  assert(elites.combat.events().back().kind==DEATH&&elites.combat.events().back().body_scale==2);
  auto reused=elites.spawn(102,0,SLIME_KIND,{0,0,0},3000,.65f);
  assert(!elites.valid(elite)&&elites.unit(reused)->body_scale==1&&elites.unit(reused)->radius==.65f);
 }
 std::cout<<"ELITE_GEOMETRY_PASS size, contacts, triple damage, native render, corpse and reuse at 20/30/60 Hz\n";
 std::cout<<"PET_GEOMETRY_PASS bounds, species, validation, wall occlusion and real 30-damage contact\n";
}
