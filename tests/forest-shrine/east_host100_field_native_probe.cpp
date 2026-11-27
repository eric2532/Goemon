#include "terrain.h"
#include <array>
#include <cmath>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
using namespace army;
namespace {
constexpr float scale=1.3f;
int checks=0,failures=0,shore_cells=0,shore_segments=0,open_centers=0,closed_centers=0,outside_samples=0,outside_disks=0,scoped_segments=0;
std::map<std::string,int> categories;
std::set<std::string> failed_cells;
std::set<int> unique_shore_cells;
std::set<std::pair<int,int>> unique_shore_edges;
void check(bool yes,const std::string& label,int x,int z,float radius=0){
 ++checks;if(yes)return;++failures;int count=++categories[label];failed_cells.insert(label+"|"+std::to_string(x)+"|"+std::to_string(z));
 if(count<=8)std::cerr<<"HOST100_FIELD_FAIL "<<label<<" source="<<x<<','<<z<<" radius="<<radius<<'\n';
}
template<class T>T read(std::ifstream& in){T result{};in.read(reinterpret_cast<char*>(&result),sizeof(result));return result;}
template<class T>std::vector<T> read_vector(std::ifstream& in,int count){std::vector<T> result(count);in.read(reinterpret_cast<char*>(result.data()),sizeof(T)*count);return result;}
struct Cell {int x,z,opened,scoped,role,bridge;};
struct Input {
 int width,old_width,count,water_count,closed_count,north;float x,z,step,old_step;
 std::vector<float> heights,old_heights;std::vector<unsigned char> covered,old_covered;
 std::vector<std::array<int,4>> water,closed;std::vector<Cell> cells;
 Vec3 point(float sx,float sz,float y=0)const{return north?Vec3{(sx*3-1902)*scale,y*scale,(sz*3-333)*scale}:Vec3{(591-sz*3)*scale,y*scale,(sx*3-1251)*scale};}
 NavigationData data(bool original)const{
  NavigationData d;d.width=original?old_width:width;d.spacing=(original?old_step:step)*scale;d.route_spacing=3*scale;d.origin=d.bounds_min={x*scale,0,z*scale};
  d.bounds_max=d.origin+Vec3{(d.width-1)*d.spacing,0,(d.width-1)*d.spacing};
  d.heights=original?old_heights:heights;for(auto& h:d.heights)h*=scale;d.covered=original?old_covered:covered;
  if(original)return d;
  for(const auto& r:water){
   auto a=point(r[0]-.5f,r[1]+r[3]*.5f-.5f,2);
   float length=r[2]*3*scale,half=r[3]*1.5f*scale;
   float p[]{a.x,a.z,float(north),float(!north),half,length,0,length,2*scale,2*scale};d.pieces.insert(d.pieces.end(),std::begin(p),std::end(p));
  }
  for(const auto& r:closed){auto a=point(r[0]-.5f,r[1]-.5f),b=point(r[0]+r[2]-.5f,r[1]+r[3]-.5f);d.obstacle_min.push_back({std::min(a.x,b.x),-13,std::min(a.z,b.z)});d.obstacle_max.push_back({std::max(a.x,b.x),39,std::max(a.z,b.z)});}
  return d;
 }
};
Input load(const char* path){
 std::ifstream in(path,std::ios::binary);char magic[8];in.read(magic,8);if(std::string(magic,8)!="CGHOST01")throw std::runtime_error("Invalid prepared field");Input d;
 d.width=read<unsigned>(in);d.old_width=read<unsigned>(in);d.count=read<unsigned>(in);d.water_count=read<unsigned>(in);d.closed_count=read<unsigned>(in);d.north=read<unsigned>(in);read<unsigned>(in);
 d.x=read<float>(in);d.z=read<float>(in);d.step=read<float>(in);d.old_step=read<float>(in);
 d.heights=read_vector<float>(in,d.width*d.width);d.covered=read_vector<unsigned char>(in,d.width*d.width);d.old_heights=read_vector<float>(in,d.old_width*d.old_width);d.old_covered=read_vector<unsigned char>(in,d.old_width*d.old_width);
 d.water=read_vector<std::array<int,4>>(in,d.water_count);d.closed=read_vector<std::array<int,4>>(in,d.closed_count);d.cells=read_vector<Cell>(in,d.count);if(!in)throw std::runtime_error("Truncated prepared field");return d;
}
bool same(double a,double b){return std::isfinite(a)==std::isfinite(b)&&(!std::isfinite(a)||std::abs(a-b)<.00005);}
void run(const Input& d){
 Terrain terrain,old;terrain.configure(d.data(false));old.configure(d.data(true));std::unordered_map<int,const Cell*> cells;for(const auto& c:d.cells)cells[c.z*840+c.x]=&c;
 auto height=[&](const Cell& c){auto p=d.point(c.x,c.z);p.y=float(terrain.height(p.x,p.z));return p;};
 int start=failures;double outside_max_delta=0.;int outside_finite_mismatch=0;
 for(const auto& c:d.cells){
  auto p=height(c);
  if(c.scoped&&!c.bridge){
   if(c.role>0&&c.role<3)unique_shore_cells.insert(c.z*840+c.x);
   if(c.opened)++open_centers;else ++closed_centers;
   for(float radius:{.25f,.35f,.4967896938f,.60f}){
    bool yes=terrain.clear(p,radius,0)==bool(c.opened);check(yes,"Source-scoped open/closed center",c.x,c.z,radius);
    if(!yes&&categories["Source-scoped open/closed center"]<=8)std::cerr<<" center y="<<p.y<<" original_open="<<c.opened<<" terrain_only="<<terrain.clear(p,radius,0,false)<<'\n';
   }
   if(c.role==1){++shore_cells;check(std::abs(p.y-2.1f*scale)<.00005,"Original bank height2.10",c.x,c.z);}
   if((c.role==2||c.role==3)&&c.opened)check(std::abs(p.y-2.f*scale)<.00005,"Original water control height2",c.x,c.z);
  }
  if(!c.scoped){
   // Exact support/height plus nine-sample clearance outside the source owner.
   for(float dx:{-.25f,0.f,.25f})for(float dz:{-.25f,0.f,.25f}){
    auto q=d.point(c.x+dx,c.z+dz);double a=terrain.height(q.x,q.z),b=old.height(q.x,q.z);
    outside_finite_mismatch+=std::isfinite(a)!=std::isfinite(b);if(std::isfinite(a)&&std::isfinite(b))outside_max_delta=std::max(outside_max_delta,std::abs(a-b));
    check(same(a,b),"Outside canonical height/support",c.x,c.z);++outside_samples;
   }
   for(float radius:{.25f,.35f,.4967896938f,.60f}){check(terrain.clear(p,radius,0,false)==old.clear(p,radius,0,false),"Outside canonical disk",c.x,c.z,radius);++outside_disks;}
  }
  if(!c.scoped||!c.opened||c.bridge)continue;
  for(auto axis:std::vector<std::array<int,2>>{{1,0},{0,1}}){
   auto found=cells.find((c.z+axis[1])*840+c.x+axis[0]);if(found==cells.end())continue;const auto& b=*found->second;if(!b.opened||b.bridge)continue;
   // All source-scoped open adjacencies, including the inferred inland grade.
   auto q=height(b);
   for(float radius:{.25f,.35f,.4967896938f,.60f}){
    bool shore=(c.role>0&&c.role<3)||(b.role>0&&b.role<3);
    bool forward=terrain.segment(p,q,radius,0),backward=terrain.segment(q,p,radius,0);
    check(forward,shore?"Original shore adjacency outward":"Source-scoped adjacency outward",c.x,c.z,radius);
    check(backward,shore?"Original shore adjacency return":"Source-scoped adjacency return",c.x,c.z,radius);
    if(shore&&!forward&&categories["Original shore adjacency outward"]<=8){
     std::cerr<<" shore_to="<<b.x<<','<<b.z<<" terrain_only_segment="<<terrain.segment(p,q,radius,0,false)<<" heights="<<p.y<<','<<q.y<<'\n';
     if(categories["Original shore adjacency outward"]==1)for(auto axis:std::vector<Vec3>{{1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{.707f,0,.707f},{-.707f,0,.707f},{.707f,0,-.707f},{-.707f,0,-.707f}})std::cerr<<" foot "<<axis.x<<','<<axis.z<<" h="<<terrain.height(p.x+axis.x*radius,p.z+axis.z*radius)<<'\n';
    }
    scoped_segments+=2;if(shore)shore_segments+=2;
    if(shore&&forward&&backward)unique_shore_edges.insert({c.z*840+c.x,b.z*840+b.x});
   }
  }
 }
 std::cout<<"HOST100_AREA "<<(d.north?"north_coast":"east_gate")<<" failures="<<failures-start<<" outside_max_delta="<<outside_max_delta<<" outside_finite_mismatch="<<outside_finite_mismatch<<'\n';
}
}
int main(int argc,char**argv){
 try{for(int i=1;i<argc;++i)run(load(argv[i]));}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 2;}
 check(unique_shore_cells.size()==2989,"All2989shore cells have a legal whole-disk scene",-1,-1);
 std::cout<<"HOST100_COMPOSITE_NATIVE checks="<<checks<<" failures="<<failures<<" shore_cells="<<shore_cells<<" shore_segments="<<shore_segments<<" open_centers="<<open_centers<<" closed_centers="<<closed_centers<<" outside_samples="<<outside_samples<<" outside_disks="<<outside_disks<<" scoped_segments="<<scoped_segments<<" shore_unique_cells="<<unique_shore_cells.size()<<" shore_unique_edges="<<unique_shore_edges.size()<<'\n';
 for(const auto& c:categories)std::cerr<<"FAILURE_CATEGORY "<<c.first<<" count="<<c.second<<'\n';
 if(argc>1){std::ofstream out(std::string(argv[1])+".failures.csv");for(const auto& row:failed_cells)out<<row<<'\n';}return failures?1:0;
}
