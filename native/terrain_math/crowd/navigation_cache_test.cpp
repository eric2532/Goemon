#include "terrain.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstring>
#include <iostream>
#include <queue>
#include <random>
namespace army {
struct NavigationCacheTest {
 static void same_grid(Terrain& a,Terrain& b,float radius,int layer){
    auto& x=a.topology(radius,layer);auto& y=b.topology(radius,layer);
    assert(x.nx==y.nx&&x.nz==y.nz&&x.open==y.open&&x.edges==y.edges);
    assert(x.heights.size()==y.heights.size()&&!std::memcmp(x.heights.data(),y.heights.data(),x.heights.size()*sizeof(float)));
 }
 static Vec3 actual(Terrain& t,Vec3 from,Vec3 goal,float radius,int layer){return t.waypoint(from,goal,radius,layer);}
 // Original uncached selector, with the new certified goal connection.
 static Vec3 reference(Terrain& t,Vec3 from,Vec3 goal,float radius,int layer){
    constexpr float STEP=6;
    constexpr int dx[]={1,-1,0,0},dz[]={0,0,1,-1};
    std::vector<Terrain::Flow> flows;uint64_t clock=0;

    auto& grid=t.topology(radius,layer);
    int gx=std::clamp(int(std::round((goal.x-t.minimum_.x)/STEP)),0,grid.nx-1);
    int gz=std::clamp(int(std::round((goal.z-t.minimum_.z)/STEP)),0,grid.nz-1);
    int target=-1;float nearest=STEP*STEP*2;
    for(int z=std::max(0,gz-2);z<=std::min(grid.nz-1,gz+2);++z)for(int x=std::max(0,gx-2);x<=std::min(grid.nx-1,gx+2);++x){
        int i=z*grid.nx+x;if(!grid.open[i])continue;
        Vec3 p{t.minimum_.x+x*STEP,grid.heights[i],t.minimum_.z+z*STEP};float distance=length(p-goal);
        if(distance*distance<nearest&&t.segment(p,goal,radius,layer)&&t.reachable(from,p,radius,layer)){nearest=distance*distance;target=i;}
    }
    if(target<0)return {NAN,0,0};
    uint32_t bits;std::memcpy(&bits,&radius,sizeof(bits));int64_t topology_id=int64_t((uint64_t(layer)<<32)|bits);
    auto found=std::find_if(flows.begin(),flows.end(),[&](const Terrain::Flow& f){return f.topology==topology_id&&f.goal==target;});
    if(found==flows.end()){
        if(flows.size()>=64){auto oldest=std::min_element(flows.begin(),flows.end(),[](const Terrain::Flow& a,const Terrain::Flow& b){return a.used<b.used;});flows.erase(oldest);}
        Terrain::Flow flow;flow.topology=topology_id;flow.goal=target;flow.cost.assign(grid.open.size(),INFINITY);flow.cost[target]=0;
        std::queue<int> queue;queue.push(target);
        while(!queue.empty()){
            int i=queue.front();queue.pop();
            for(int direction=0;direction<4;++direction){
                if(!(grid.edges[i]&(1<<direction)))continue;
                int next=i+dx[direction]+dz[direction]*grid.nx;
                if(flow.cost[next]<=flow.cost[i]+STEP)continue;
                flow.cost[next]=flow.cost[i]+STEP;queue.push(next);
            }
        }
        flows.push_back(std::move(flow));found=flows.end()-1;
    }
    found->used=++clock;
    int fx=std::clamp(int(std::round((from.x-t.minimum_.x)/STEP)),0,grid.nx-1);
    int fz=std::clamp(int(std::round((from.z-t.minimum_.z)/STEP)),0,grid.nz-1);
    Vec3 best{NAN,0,0};float score=INFINITY;
    for(int z=std::max(0,fz-1);z<=std::min(grid.nz-1,fz+1);++z)for(int x=std::max(0,fx-1);x<=std::min(grid.nx-1,fx+1);++x){
        int i=z*grid.nx+x;if(!std::isfinite(found->cost[i]))continue;
        Vec3 point{t.minimum_.x+x*STEP,grid.heights[i],t.minimum_.z+z*STEP};float distance=length(point-from);
        if(distance<.1f||found->cost[i]+distance>=score||!t.segment(from,point,radius,layer))continue;
        score=found->cost[i]+distance;best=point;
    }
    return best;
}
};
}
using namespace army;
int main(){
 NavigationData d;d.origin={-60,0,-60};d.width=41;d.spacing=3;d.heights.resize(41*41);d.covered.assign(41*41,1);
 for(int z=0;z<41;++z)for(int x=0;x<41;++x)d.heights[z*41+x]=x*.15f;
 d.obstacle_min={{-3,-2,-42},{18,-2,6}};d.obstacle_max={{3,20,18},{30,20,42}};
 d.layer_min={{-42,12,-42}};d.layer_max={{42,12,42}};
 // A raised ramp over the slope must retain its exact support samples.
 d.pieces={-36,30,1,0,6,24,0,24,2,7};
 Terrain t;t.configure(d);t.navigation_profile.enabled=true;
 int checks=0;auto equal=[&](Vec3 a,Vec3 b){assert((!finite(a)&&!finite(b))||(a.x==b.x&&a.y==b.y&&a.z==b.z));++checks;};
 auto query=[&](Vec3 from,Vec3 goal,float radius,int layer){auto expected=NavigationCacheTest::reference(t,from,goal,radius,layer);equal(NavigationCacheTest::actual(t,from,goal,radius,layer),expected);equal(NavigationCacheTest::actual(t,from,goal,radius,layer),expected);};
 std::mt19937 rng(71022);std::uniform_real_distribution<float> pos(-54,54);
 for(int i=0;i<1600;++i){int layer=i%7==0?1:0;float radius=i%2?.4f:3.9f;Vec3 from{pos(rng),0,pos(rng)},goal{pos(rng),0,pos(rng)};from.y=float(t.height(from.x,from.z,layer));goal.y=float(t.height(goal.x,goal.z,layer));if(!finite(from)||!finite(goal))continue;query(from,goal,radius,layer);}
 // Adjacent representable roots, radii, support layers and goal cells are distinct.
 for(int layer:{0,1})for(float radius:{.4f,3.9f})for(float x:{-24.0f,std::nextafter(-24.0f,0.0f),-23.99f})for(float gx:{24.0f,24.01f,30.0f})query({x,float(t.height(x,-12,layer)),-12},{gx,float(t.height(gx,12,layer)),12},radius,layer);
 for(int i=0;i<1100;++i)query({-48,0,-48},{-42,0,-48},.4f,0);
 auto hits=t.navigation_profile.route_hits;
 assert(hits>1000 && "Repeated exact route queries must reuse certificates");
 // Local obstacle updates must match a complete rebuild, including boundary edges.
 for(int update=0;update<6;++update){
  for(float radius:{.4f,3.9f,12.0f,12.096f})for(int layer:{0,1})NavigationCacheTest::actual(t,{-24,0,-12},{24,0,12},radius,layer);
  if(update==0){d.obstacle_min.erase(d.obstacle_min.begin());d.obstacle_max.erase(d.obstacle_max.begin());}
  if(update==1){d.obstacle_min.push_back({-9,-2,-9});d.obstacle_max.push_back({9,20,9});}
  if(update==2)d.obstacle_max[0].x+=12;
  if(update==3){d.obstacle_min[0].y=30;d.obstacle_max[0].y=40;}
  if(update==4){std::reverse(d.obstacle_min.begin(),d.obstacle_min.end());std::reverse(d.obstacle_max.begin(),d.obstacle_max.end());}
  if(update==5){d.covered[18*41+18]=0;d.heights[19*41+19]+=3;}
  t.configure(d);Terrain rebuilt;rebuilt.configure(d);
  for(float radius:{.4f,3.9f,12.0f,12.096f})for(int layer:{0,1}){NavigationCacheTest::same_grid(t,rebuilt,radius,layer);++checks;}
  for(int i=0;i<30;++i){Vec3 from{pos(rng),0,pos(rng)},goal{pos(rng),0,pos(rng)};from.y=float(t.height(from.x,from.z));goal.y=float(t.height(goal.x,goal.z));if(finite(from)&&finite(goal))equal(NavigationCacheTest::actual(t,from,goal,3.9f,0),NavigationCacheTest::reference(rebuilt,from,goal,3.9f,0));}
 }
 // Reconfiguration covers wall collapse, replacement and terrain revisions.
 d.obstacle_min.clear();d.obstacle_max.clear();d.heights.assign(41*41,4);d.pieces.clear();t.configure(d);
 for(int i=0;i<100;++i)query({-24,4,-12},{24,4,12},3.9f,0);
 NavigationData flat;flat.origin={-60,0,-60};flat.width=41;flat.spacing=3;flat.heights.assign(41*41,0);flat.covered.assign(41*41,1);
 flat.obstacle_min={{-3,-2,-42}};flat.obstacle_max={{3,20,18}};t.configure(flat);
 Vec3 from{-6,0,0},goal{24,0,0};auto before=NavigationCacheTest::actual(t,from,goal,.4f,0);
 flat.obstacle_min.clear();flat.obstacle_max.clear();t.configure(flat);
 auto after=NavigationCacheTest::actual(t,from,goal,.4f,0);
 assert(before.x!=after.x||before.z!=after.z);
 equal(after,NavigationCacheTest::reference(t,from,goal,.4f,0));
 // Capacity/collision churn may evict results, but never return another key's point.
 for(int i=0;i<10000;++i){Vec3 root{-48+float(i%100)*.8f,0,-48+float(i/100)*.8f};NavigationCacheTest::actual(t,root,goal,.4f,0);}
 query(from,goal,.4f,0);
 // The best unblocked flow candidate needs one exact clearance certificate,
 // not several improving candidates in incidental grid traversal order.
 Vec3 route_from{1,0,1},route_goal{48,0,48};
 auto expected=NavigationCacheTest::reference(t,route_from,route_goal,.4f,0);
 auto segments=t.navigation_profile.segments;
 equal(NavigationCacheTest::actual(t,route_from,route_goal,.4f,0),expected);
 assert(t.navigation_profile.segments-segments<64 && "Goal and entry certificates must stay bounded to nearby grid cells");
 std::cout<<"NAVIGATION_CACHE_RESULT checks="<<checks<<" hits="<<hits<<"\n";
}
