#include "terrain.h"
#include <cassert>
#include <iostream>
#include <random>
namespace army {
struct AirSharingTest {
 static bool shared(const Terrain& a,const Terrain& b){return a.air_==b.air_;}
 static void reserved_field(const Terrain& t,size_t extra=0){
  const auto& a=*t.air_;
  assert(a.faces.size()==size_t(480)*480*6+extra);
  assert(a.faces.capacity()<=a.faces.size()+16&&a.owner.capacity()<=a.faces.size()/3+16);
  assert(a.minimum.capacity()<=a.minimum.size()+16&&a.maximum.capacity()<=a.maximum.size()+16);
  assert(a.order.capacity()<=a.order.size()+16&&a.nodes.capacity()<=a.nodes.size()+16);
 }
 static size_t bytes(const Terrain& t){
  const auto& a=*t.air_;size_t n=(a.faces.capacity()+a.minimum.capacity()+a.maximum.capacity())*sizeof(Vec3)+a.owner.capacity()*sizeof(int64_t)+a.order.capacity()*sizeof(int)+a.nodes.capacity()*sizeof(Terrain::AirNode);
  for(const auto* grid:{&a.grid,&a.dynamic_grid}){n+=grid->bucket_count()*sizeof(void*)+grid->size()*sizeof(typename std::decay_t<decltype(*grid)>::value_type);for(const auto& entry:*grid)n+=entry.second.capacity()*sizeof(int);}
  return n;
 }
};
}
using namespace army;
int main(){
 NavigationData data;data.origin={-60,0,-60};data.width=41;data.spacing=3;data.heights.resize(41*41);data.covered.assign(41*41,1);
 for(int z=0;z<41;++z)for(int x=0;x<41;++x)data.heights[z*41+x]=std::sin(x*.3f)*2;
 data.air_faces={{0,0,-12},{0,20,12},{0,0,12}};data.air_owner={17};
 Terrain enemy,ally,reference;enemy.configure(data);ally.configure(data,&enemy);reference.configure(data);
 assert(AirSharingTest::shared(enemy,ally));int checks=1;
 std::mt19937 rng(71030);std::uniform_real_distribution<float> p(-48,48);
 auto same=[&](Vec3 a,Vec3 b){assert(a.x==b.x&&a.y==b.y&&a.z==b.z);++checks;};
 auto compare=[&](Terrain& actual,Terrain& expected){
  for(int i=0;i<1000;++i){Vec3 from{p(rng),10,p(rng)},to{p(rng),p(rng)*.15f,p(rng)};
   assert(actual.ray_clear(from,to)==expected.ray_clear(from,to));++checks;
   assert(actual.projectile_fraction(from,to,.3f)==expected.projectile_fraction(from,to,.3f));++checks;
   auto a=actual.air_move(from,to-from,.4f,1.8f,.9f),b=expected.air_move(from,to-from,.4f,1.8f,.9f);same(a.position,b.position);same(a.normal,b.normal);assert(a.floor==b.floor);++checks;
  }
 };
 compare(ally,reference);
 // Navigation blockers can differ without duplicating identical physical faces.
 auto friendly=data;friendly.obstacle_min={{-30,-2,-30}};friendly.obstacle_max={{30,20,30}};
 ally.configure(friendly,&enemy);assert(AirSharingTest::shared(enemy,ally));++checks;
 compare(ally,reference);
 // Replacing a wall must not mutate a separate terrain copy or its old owner.
 Terrain saved=enemy;
 data.air_faces[0].x=6;data.air_faces[1].x=6;data.air_faces[2].x=6;
 enemy.configure(data);assert(!AirSharingTest::shared(enemy,ally));++checks;
 compare(ally,reference);compare(saved,reference);
 ally.configure(data,&enemy);reference.configure(data);assert(AirSharingTest::shared(enemy,ally));++checks;
 compare(ally,reference);
 auto different=data;different.heights[100]+=2;
 ally.configure(different,&enemy);assert(!AirSharingTest::shared(enemy,ally));++checks;
 reference.configure(different);compare(ally,reference);
 // Flat fallback faces are clipped to map bounds, so unequal bounds cannot share them.
 NavigationData flat;flat.bounds_min={-6,0,-6};flat.bounds_max={6,0,6};
 Terrain whole,cropped,cropped_reference;whole.configure(flat);flat.bounds_max.x=3;
 cropped.configure(flat,&whole);cropped_reference.configure(flat);
 assert(!AirSharingTest::shared(whole,cropped));++checks;
 auto cropped_hit=cropped.projectile_fraction({5,5,0},{5,-5,0},0);
 assert(cropped_hit==cropped_reference.projectile_fraction({5,5,0},{5,-5,0},0));++checks;
 assert(cropped_hit!=whole.projectile_fraction({5,5,0},{5,-5,0},0));++checks;
 data.width=481;data.origin={-720,0,-720};data.heights.assign(481*481,0);data.covered.assign(481*481,1);data.air_faces.clear();data.air_owner.clear();
 enemy.configure(data);ally.configure(data,&enemy);assert(AirSharingTest::shared(enemy,ally));++checks;
 AirSharingTest::reserved_field(enemy);++checks;
 auto field_bytes=AirSharingTest::bytes(enemy);
 data.air_faces={{0,0,-12},{0,20,12},{0,0,12}};data.air_owner={17};
 enemy.configure(data);ally.configure(data,&enemy);AirSharingTest::reserved_field(enemy,3);++checks;
 std::cout<<"AIR_SHARING_RESULT checks="<<checks<<" shared_field_bytes="<<field_bytes<<" shared_collision_bytes="<<AirSharingTest::bytes(enemy)<<" failures=0\n";
}
