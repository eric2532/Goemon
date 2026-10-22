#include "core.h"
#include <cassert>
#include <iostream>
using namespace army;
void populate(Crowd& c){
 c.configure(4000,2000);NavigationData nav;nav.width=0;c.set_navigation(nav);
 for(int i=0;i<4000;++i){
  auto h=c.spawn(i<2000?i+1:-i-1,i/2000,0,{float(i%80)*2-80,0,float(i/80)*2-50},192.125,i<2000?3.9:.4);
  assert(h);c.set_goal(h,{0,0,0},3);
 }
 c.timing.enabled=true;
}
int main(){
 Crowd source,worker;populate(source);populate(worker);source.parallel_movement_enabled=false;worker.parallel_movement_enabled=true;int checks=0;
 auto same=[&](){
  auto a=source.snapshot(),b=worker.snapshot();assert(a.size()==4000&&b.size()==4000);
  for(size_t i=0;i<a.size();++i){
   assert(a[i].handle==b[i].handle&&a[i].logical_id==b[i].logical_id&&a[i].hp==b[i].hp);
   assert(a[i].position.x==b[i].position.x&&a[i].position.y==b[i].position.y&&a[i].position.z==b[i].position.z);
   assert(a[i].velocity.x==b[i].velocity.x&&a[i].velocity.y==b[i].velocity.y&&a[i].velocity.z==b[i].velocity.z&&a[i].yaw==b[i].yaw);
  }
  assert(source.timing.steps==worker.timing.steps);++checks;
 };
 assert(worker.timing.movement_jobs==0);assert(!worker.begin_step(0));worker.finish_step();same();
 for(int i=0;i<120;++i){source.step(1.0/60);assert(worker.begin_step(1.0/60));worker.finish_step();same();}
 // A subsequent submission joins the previous job; no simulation delta is lost.
 source.step(.05);source.step(.1);assert(worker.begin_step(.05));assert(worker.begin_step(.1));worker.finish_step();same();
 assert(!worker.begin_step(NAN));worker.finish_step();same();
 // Destruction joins outstanding work before any simulation state is destroyed.
 for(int i=0;i<8;++i){Crowd retiring;populate(retiring);assert(retiring.begin_step(.05));}
 assert(worker.timing.movement_jobs>0&&source.timing.movement_jobs==0);++checks;
 worker.clear();assert(worker.snapshot().empty());worker.finish_step();
 std::cout<<"ARMY_MOVEMENT_WORKER_RESULT checks="<<checks<<" failures=0\n";
}
