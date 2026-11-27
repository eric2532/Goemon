#include "terrain.h"
#include "bank-cap-cases.h"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <iostream>
#include <string>
using namespace army;
#ifndef SOURCE_CAP_CANDIDATE
#define SOURCE_CAP_CANDIDATE 0
#endif
namespace {
int checks=0,failures=0;
void check(bool okay,const char* message){++checks;if(!okay){++failures;std::cerr<<"FAIL "<<message<<'\n';}}
NavigationData field(float scale){
 NavigationData d;d.width=25;d.spacing=d.route_spacing=3*scale;d.origin={-36*scale,0,-36*scale};d.bounds_min=d.origin;d.bounds_max={36*scale,0,36*scale};
 d.heights.assign(d.width*d.width,0);d.covered.assign(d.heights.size(),0);
 for(int z=0;z<d.width;++z)for(int x=0;x<d.width;++x)if(-36+x*3<=-3){d.heights[z*d.width+x]=6*scale;d.covered[z*d.width+x]=1;}
 return d;
}
void piece(NavigationData& d,std::array<float,4> r,float scale,float high=6){
 float length=(r[2]-r[0])*scale;float values[]{r[0]*scale,(r[1]+r[3])*.5f*scale,1,0,(r[3]-r[1])*.5f*scale,length,0,length,high*scale,high*scale};
 d.pieces.insert(d.pieces.end(),std::begin(values),std::end(values));
}
bool in(const std::array<float,4>& r,float x,float z,float scale){return x>=r[0]*scale-.001f&&x<=r[2]*scale+.001f&&z>=r[1]*scale-.001f&&z<=r[3]*scale+.001f;}
double expected_height(const Terrain& before,const BankCase& cap,float x,float z,float scale){
 double result=before.height(x,z);bool supported=in(cap.join,x,z,scale);
 for(const auto& r:cap.rects)supported=supported||in(r,x,z,scale);
 return supported?6*scale:result;
}
bool expected_clear(const Terrain& before,const BankCase& cap,Vec3 p,float radius,float scale){
 double center=expected_height(before,cap,p.x,p.z,scale);if(!std::isfinite(center))return false;
 for(Vec3 a:{Vec3{1,0,0},Vec3{-1,0,0},Vec3{0,0,1},Vec3{0,0,-1},Vec3{.707f,0,.707f},Vec3{-.707f,0,.707f},Vec3{.707f,0,-.707f},Vec3{-.707f,0,-.707f}}){
  double h=expected_height(before,cap,p.x+a.x*radius,p.z+a.z*radius,scale);
  if(!std::isfinite(h)||std::abs(h-center)>.15+radius*.35)return false;
 }
 return true;
}
bool expected_approach(const Terrain& before,const BankCase& cap,float radius,float scale){
 for(float x=-6;x<cap.sx;x+=.05f)if(!expected_clear(before,cap,{x*scale,6*scale,cap.sz*scale},radius,scale))return false;
 return expected_clear(before,cap,{cap.sx*scale,6*scale,cap.sz*scale},radius,scale);
}
double full_scan(const NavigationData& d,float x,float z){
 double result=0;
 for(size_t i=0;i<d.pieces.size();i+=10){
  const float* p=d.pieces.data()+i;float ox=x-p[0],oz=z-p[1];
  float along=ox*p[2]+oz*p[3],side=-ox*p[3]+oz*p[2];
  if(along<p[6]-.001||along>p[7]+.001||std::abs(side)>p[4]+.001||p[5]<=0)continue;
  result=std::max(result,double(p[8])+(double(p[9])-p[8])*std::clamp(double(along)/p[5],0.0,1.0));
 }
 return result;
}
Vec3 placed(Vec3 p,Vec3 origin,bool quarter_turn){
 return quarter_turn?Vec3{origin.x+p.z,p.y,origin.z-p.x}:Vec3{origin.x+p.x,p.y,origin.z+p.z};
}
void transform_pieces(NavigationData& d,Vec3 origin,bool quarter_turn){
 for(size_t i=0;i<d.pieces.size();i+=10){
  Vec3 p=placed({d.pieces[i],0,d.pieces[i+1]},origin,quarter_turn);
  d.pieces[i]=p.x;d.pieces[i+1]=p.z;
  if(quarter_turn){float dx=d.pieces[i+2];d.pieces[i+2]=d.pieces[i+3];d.pieces[i+3]=-dx;}
 }
 d.origin={origin.x-36*1.3f,0,origin.z-36*1.3f};d.bounds_min=d.origin;d.bounds_max={origin.x+36*1.3f,0,origin.z+36*1.3f};
}
}
int main(){
 int unavailable=0,does_not_fit=0;
 for(const auto& cap:bank_cases)for(float scale:{1.f,1.3f}){
  auto d=field(scale);auto original_heights=d.heights;auto original_covered=d.covered;
  Terrain before;before.configure(d);
  for(const auto& r:cap.rects)piece(d,r,scale);piece(d,cap.join,scale);
  Terrain actual;actual.configure(d);
  check(d.heights==original_heights&&d.covered==original_covered,"Source field heights/covered bytes stay unchanged");
  check(d.route_spacing==3*scale,"Original route spacing stays unchanged");
  Vec3 stand{cap.sx*scale,6*scale,cap.sz*scale},land{-6*scale,6*scale,cap.sz*scale};
  if(SOURCE_CAP_CANDIDATE)check(std::abs(actual.height(stand.x,stand.z)-stand.y)<.0001,"Explicit cap supplies only its prepared height over void");
  else{check(!std::isfinite(actual.height(stand.x,stand.z)),"Current early void return reproduces missing cap support");++unavailable;}
  for(float radius:{.25f,.35f,.60f}){
   bool fits=expected_approach(before,cap,radius,scale);if(!fits)++does_not_fit;
   bool clear=actual.clear(stand,radius,0),up=actual.reachable(land,stand,radius,0),down=actual.reachable(stand,land,radius,0);
   std::cout<<"BANK_CAP serial="<<cap.serial<<" source="<<cap.x<<','<<cap.z<<" scale="<<scale<<" radius="<<radius<<" geometry_fits="<<fits<<" clear="<<clear<<" up="<<up<<" down="<<down<<'\n';
   if(SOURCE_CAP_CANDIDATE){
    check(clear==expected_clear(before,cap,stand,radius,scale),"Real native nine-point clearance matches source cap interior");
    if(fits){check(up&&down,"Continuous original-land approach works both directions");
     for(float x=-6;x<cap.sx;x+=.1f)check(actual.clear({x*scale,6*scale,cap.sz*scale},radius,0),"No hidden unclimbable seam before the source lip");}
    else check(!actual.segment(land,stand,radius,0),"An oversized body cannot cross a narrower native lip");
   }else check(!clear&&!up&&!down,"Current source cap remains physically unavailable");
  }
  for(const auto& r:cap.rects)for(float radius:{.25f,.35f,.60f})for(float shift:{-.025f,.025f}){
   for(Vec3 p:{Vec3{(r[0]+shift)*scale,6*scale,(r[1]+r[3])*.5f*scale},Vec3{(r[2]+shift)*scale,6*scale,(r[1]+r[3])*.5f*scale},Vec3{(r[0]+r[2])*.5f*scale,6*scale,(r[1]+shift)*scale},Vec3{(r[0]+r[2])*.5f*scale,6*scale,(r[3]+shift)*scale}})
    if(SOURCE_CAP_CANDIDATE)check(actual.clear(p,radius,0)==expected_clear(before,cap,p,radius,scale),"Exact cap edge/radius samples cannot grant full-cell support");
  }
  for(Vec3 p:{Vec3{10*scale,0,0},Vec3{1.6f*scale,0,1.6f*scale},Vec3{37*scale,0,0}}){check(!std::isfinite(actual.height(p.x,p.z)),"Unrelated water/outside-domain stays void");check(!actual.clear(p,.25f,0),"Unrelated void stays blocked");}
  for(Vec3 p:{Vec3{-12*scale,6*scale,0},Vec3{-18*scale,6*scale,9*scale}})check(actual.height(p.x,p.z)==before.height(p.x,p.z)&&actual.clear(p,.35f,0)==before.clear(p,.35f,0),"Ordinary covered terrain keeps its original height and clearance");
 }
 // Existing authored pieces keep max-height priority on already covered land.
 auto old=field(1);piece(old,{-15,-3,-9,3},1,8);piece(old,{-13,-2,-10,2},1,9);Terrain layered;layered.configure(old);
 check(layered.height(-12,0)==9,"Existing covered-piece priority is unchanged");
 check(!std::isfinite(layered.height(12,0)),"A nearby unrelated piece cannot support ordinary void");
 if(SOURCE_CAP_CANDIDATE){
  auto gap=field(1);piece(gap,{0,0,.2f,1},1);piece(gap,{.4f,0,.6f,1},1);Terrain narrow;narrow.configure(gap);
  check(narrow.clear({.1f,6,.5f},.025f,0)&&narrow.clear({.5f,6,.5f},.025f,0),"Both tiny source islands independently support the small body");
  check(!narrow.segment({.1f,6,.5f},{.5f,6,.5f},.025f,0),"A short path cannot skip the water gap between exact source lips");
  check(!std::isfinite(narrow.height(.3f,.5f)),"The gap between source pieces remains void");
 }
 if(SOURCE_CAP_CANDIDATE){
  // Exact Il source chain: only four west neighbors are dry. The two end lips
  // meet the adjacent recovered cap; known wet12534/12521 receive no join.
  for(float scale:{1.f,1.3f}){
   auto d=field(scale);std::fill(d.covered.begin(),d.covered.end(),0);
   for(const auto& cap:bank_cases){
    float offset=(cap.z-69)*3;
    for(auto r:cap.rects){r[1]+=offset;r[3]+=offset;piece(d,r,scale);}
    if(cap.source_dry_west){auto r=cap.join;r[1]+=offset;r[3]+=offset;piece(d,r,scale);}
   }
   Terrain chain;chain.configure(d);
   for(const auto& cap:bank_cases){
    Vec3 stand{cap.source_sx*scale,6*scale,(cap.source_sz+(cap.z-69)*3)*scale};
    Vec3 land{-3*scale,6*scale,float((cap.source_land_z-69)*3)*scale};
    Vec3 bend{cap.source_sx*scale,6*scale,land.z};
    for(float radius:{.25f,.35f,.60f}){
     bool fits=chain.clear(stand,radius,0)&&chain.segment(land,bend,radius,0)&&chain.segment(bend,stand,radius,0);
     std::cout<<"BANK_CAP_SOURCE_CHAIN serial="<<cap.serial<<" scale="<<scale<<" radius="<<radius<<" dry_west="<<cap.source_dry_west<<" fits="<<fits<<'\n';
     if(scale==1.3f&&radius<=.35f)check(fits,"Exact Il source caps approach through four dry joins and intrinsic adjacent source lips");
     if(scale==1.3f&&radius==.60f&&cap.serial==12502)check(!fits,"A .60body cannot cross the actual .56875m south-end cap contact; source strips stay exact");
     if(scale==1.3f&&radius==.60f&&cap.serial!=12502)check(fits,"The remaining exact source cap approaches fit .60at actual gameplay scale");
     if(fits)check(chain.segment(stand,bend,radius,0)&&chain.segment(bend,land,radius,0),"The exact source cap chain also returns to land");
    }
   }
   check(!std::isfinite(chain.height(-3*scale,0)),"Known western wet bank12534 is not promoted to a full-cell join");
   check(!std::isfinite(chain.height(-3*scale,15*scale)),"Known western wet bank12521 is not promoted to a full-cell join");
  }
 }
 if(SOURCE_CAP_CANDIDATE){
  // Final source-walk contract: the sprite alpha is visual evidence, while
  // original-open native bank tiles authorize invisible support-only floors.
  for(float scale:{1.f,1.3f})for(Vec3 origin:{Vec3{0,0,0},Vec3{-717.6f,0,1154.4f},Vec3{-378.3f,0,-343.2f},Vec3{-12,0,-12}})for(bool turn:{false,true}){
   auto d=field(scale);std::fill(d.covered.begin(),d.covered.end(),0);
   for(const auto& cap:bank_cases){
    float offset=(cap.z-69)*3;piece(d,{-1.5f,offset-1.5f,1.5f,offset+1.5f},scale);
    if(cap.source_dry_west){auto r=cap.join;r[1]+=offset;r[3]+=offset;piece(d,r,scale);}
   }
   transform_pieces(d,origin,turn);
   // transform_pieces uses a1.3-sized enclosing domain; spacing still source scale.
   Terrain exact_source;exact_source.configure(d);
   for(const auto& cap:bank_cases){
    Vec3 land=placed({-3*scale,6*scale,float((cap.source_land_z-69)*3)*scale},origin,turn);
    Vec3 bend=placed({0,6*scale,float((cap.source_land_z-69)*3)*scale},origin,turn);
    Vec3 anchor=placed({0,6*scale,float((cap.z-69)*3)*scale},origin,turn);
    for(float radius:{.25f,.35f,.49679f,.60f}){
     check(exact_source.clear(anchor,radius,0),"Every original-open bank anchor keeps source walk support including the real pet radius");
     check(exact_source.segment(land,bend,radius,0)&&exact_source.segment(bend,anchor,radius,0),"Invisible source-walk supports retain the original approach chain");
     check(exact_source.segment(anchor,bend,radius,0)&&exact_source.segment(bend,land,radius,0),"The original source bank chain retains its original return approach");
    }
   }
   Vec3 outside=placed({1.6f*scale,0,7*scale},origin,turn);
   check(!std::isfinite(exact_source.height(outside.x,outside.z)),"The exact open-bank supports never extend into adjacent ordinary water");
  }
 }
 if(SOURCE_CAP_CANDIDATE){
  // The original piece contract accepts nonunit directions. Bucket enrollment
  // must equal the old scan on either side of positive/negative 12m borders.
  auto nonunit=field(1);std::fill(nonunit.covered.begin(),nonunit.covered.end(),1);std::fill(nonunit.heights.begin(),nonunit.heights.end(),0);
  for(float border:{-12.f,0.f,12.f})for(float axis:{.1f,.7f,2.f})for(float angle:{0.f,.53f,1.5707963f}){
   float values[]{border+.005f,.007f,axis*std::cos(angle),axis*std::sin(angle),.1f,.1f,0,.1f,8,8};
   nonunit.pieces.insert(nonunit.pieces.end(),std::begin(values),std::end(values));
  }
  Terrain indexed_old;indexed_old.configure(nonunit);
  for(float border:{-12.f,0.f,12.f})for(int x=-30;x<=30;++x)for(int z=-30;z<=30;++z){
   float xx=border+x*.001f,zz=z*.001f;
   check(indexed_old.height(xx,zz)==full_scan(nonunit,xx,zz),"Unit/nonunit rotated pieces preserve the old scan across signed bucket borders");
  }
  auto invalid=field(1);piece(invalid,{0,0,1,1},1);invalid.pieces[8]=NAN;piece(invalid,{0,0,1,1},1);
  Terrain finite_overlap;finite_overlap.configure(invalid);
  check(finite_overlap.height(.5f,.5f)==6,"A nonfinite first piece cannot poison a valid overvoid support");
 }
 if(SOURCE_CAP_CANDIDATE){
  // Exact current source anchors: Il(77,69) joined East Gate rotates90deg;
  // Alyut(8,3) joined North Coast translates(-165,-123). Gameplay scale1.3.
  for(Vec3 origin:{Vec3{-717.6f,0,1154.4f},Vec3{-378.3f,0,-343.2f},Vec3{-12.f,0,-12.f},Vec3{12.f,0,12.f}})for(bool turn:{false,true}){
   for(const auto& cap:bank_cases){
    auto d=field(1.3f);std::fill(d.covered.begin(),d.covered.end(),0);
    for(const auto& r:cap.rects)piece(d,r,1.3f);piece(d,cap.join,1.3f);piece(d,{-12,-3,-1.5f,3},1.3f);
    transform_pieces(d,origin,turn);Terrain translated;translated.configure(d);
    Vec3 land=placed({-6*1.3f,6*1.3f,cap.sz*1.3f},origin,turn),stand=placed({cap.sx*1.3f,6*1.3f,cap.sz*1.3f},origin,turn);
    for(float radius:{.25f,.35f,.60f}){
     check(translated.clear(stand,radius,0),"Actual translated/rotated source lip retains its nine-point clearance");
     check(translated.segment(land,stand,radius,0)&&translated.segment(stand,land,radius,0),"Actual joined source lip keeps continuous land approach both directions");
    }
   }
   auto gap=field(1.3f);std::fill(gap.covered.begin(),gap.covered.end(),0);
   piece(gap,{0,0,.2f,1},1.3f);piece(gap,{.4f,0,.6f,1},1.3f);transform_pieces(gap,origin,turn);Terrain translated_gap;translated_gap.configure(gap);
   Vec3 a=placed({.13f,7.8f,.65f},origin,turn),b=placed({.65f,7.8f,.65f},origin,turn),water=placed({.39f,0,.65f},origin,turn);
   check(translated_gap.clear(a,.025f,0)&&translated_gap.clear(b,.025f,0),"Translated tiny lips independently support their actual body");
   check(!translated_gap.segment(a,b,.025f,0),"Float32 joined coordinates cannot skip a sub-.7m water gap");
   check(!std::isfinite(translated_gap.height(water.x,water.z)),"Translated gap remains actual void");
  }
 }
 if(SOURCE_CAP_CANDIDATE){
  auto many=field(1);
  for(int i=0;i<5000;++i){float x=2+(i%60)*.5f,z=-30+(i/60)*.7f;piece(many,{x,z,x+.125f,z+.25f},1);}
  Terrain indexed;indexed.configure(many);indexed.navigation_profile.enabled=true;
  auto start=std::chrono::steady_clock::now();for(int i=0;i<1000;++i)check(indexed.clear({-20,6,-20},.35f,0),"Distant flat field remains clear with5000source strips");
  double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
  check(indexed.navigation_profile.heights<=1100,"Far-field certification retains one height sample per clear query");
  std::cout<<"BANK_CAP_FAR_FIELD pieces=5000 queries=1000 heights="<<indexed.navigation_profile.heights<<" elapsed_ms="<<ms<<'\n';
 }
 std::cout<<(SOURCE_CAP_CANDIDATE?"BANK_CAP_SUPPORT_CANDIDATE":"BANK_CAP_SUPPORT_CURRENT")<<" checks="<<checks<<" failures="<<failures<<" reproduced_missing_support="<<unavailable<<" oversized_approaches="<<does_not_fit<<'\n';
 return failures?1:0;
}
