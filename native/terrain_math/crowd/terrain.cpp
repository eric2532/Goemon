#include "terrain.h"
#include <algorithm>
#include <limits>
#include <queue>
#include <cstring>
#include <chrono>
#include <iterator>

namespace army {
namespace {
struct ProfileScope {
    double* total;
    std::chrono::steady_clock::time_point start;
    explicit ProfileScope(double* value):total(value){if(total)start=std::chrono::steady_clock::now();}
    ~ProfileScope(){if(total)*total+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();}
};
uint64_t key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
constexpr float OBSTACLE_CELL=12;
const Vec3 axes[]={{1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{.707f,0,.707f},{-.707f,0,.707f},{.707f,0,-.707f},{-.707f,0,-.707f}};
constexpr int dx[]={1,-1,0,0},dz[]={0,0,1,-1};
float segment_rectangle_distance(Vec3 from,Vec3 to,Vec3 a,Vec3 b){
    float low=0,high=1;Vec3 delta=to-from;
    for(int axis=0;axis<2;++axis){
        float start=axis?from.z:from.x,d=axis?delta.z:delta.x;
        float first=axis?a.z:a.x,last=axis?b.z:b.x;
        if(std::abs(d)<1e-7f){if(start<first||start>last){low=2;break;}continue;}
        float u=(first-start)/d,v=(last-start)/d;if(u>v)std::swap(u,v);
        low=std::max(low,u);high=std::min(high,v);
    }
    if(low<=high)return 0;
    auto point_gap=[&](Vec3 p){float x=p.x-std::clamp(p.x,a.x,b.x),z=p.z-std::clamp(p.z,a.z,b.z);return x*x+z*z;};
    float best=std::min(point_gap(from),point_gap(to)),length2=delta.x*delta.x+delta.z*delta.z;
    for(float x:{a.x,b.x})for(float z:{a.z,b.z}){
        float t=length2>1e-8f?std::clamp(((x-from.x)*delta.x+(z-from.z)*delta.z)/length2,0.0f,1.0f):0;
        float xx=x-from.x-delta.x*t,zz=z-from.z-delta.z*t;best=std::min(best,xx*xx+zz*zz);
    }
    return best;
}
}
void Terrain::configure(NavigationData data,const Terrain* shared_air){
    auto same=[](const auto& a,const auto& b){return a.size()==b.size()&&(a.empty()||!std::memcmp(a.data(),b.data(),a.size()*sizeof(a[0])));};
    bool same_surface=ready_&&data.width==data_.width&&data.spacing==data_.spacing&&data.route_spacing==data_.route_spacing&&
        !std::memcmp(&data.origin,&data_.origin,sizeof(Vec3))&&!std::memcmp(&data.bounds_min,&data_.bounds_min,sizeof(Vec3))&&!std::memcmp(&data.bounds_max,&data_.bounds_max,sizeof(Vec3))&&
        same(data.heights,data_.heights)&&same(data.covered,data_.covered)&&same(data.diagonal_flips,data_.diagonal_flips)&&same(data.pieces,data_.pieces)&&same(data.layer_min,data_.layer_min)&&same(data.layer_max,data_.layer_max);
    auto air_prefix=[](const NavigationData& d){size_t n=0;while(n+2<d.air_faces.size()&&(n/3>=d.air_owner.size()||d.air_owner[n/3]<0))n+=3;return n;};
    size_t prefix=air_prefix(data);
    bool same_air_base=same_surface&&air_->base_faces&&prefix==air_prefix(data_)&&(!prefix||!std::memcmp(data.air_faces.data(),data_.air_faces.data(),prefix*sizeof(Vec3)));
    if(same_air_base)for(size_t i=0;i<prefix/3;++i)if((i<data.air_owner.size()?data.air_owner[i]:-1)!=(i<data_.air_owner.size()?data_.air_owner[i]:-1)){same_air_base=false;break;}
    auto old_min=std::move(data_.obstacle_min),old_max=std::move(data_.obstacle_max);
    data_=std::move(data);route_certificates_.clear();flows_.clear();obstacle_grid_.clear();
    if(!same_surface){field_spans_.clear();topologies_.clear();}
    obstacle_visited_.assign(data_.obstacle_min.size(),0);obstacle_visit_=0;
    ready_=std::isfinite(data_.spacing)&&data_.spacing>0&&std::isfinite(data_.route_spacing)&&data_.route_spacing>=1&&data_.route_spacing<=64&&finite(data_.origin);
    if(data_.width>0&&(data_.width<2||int64_t(data_.width)*data_.width>int64_t(data_.heights.size())||data_.covered.size()!=data_.heights.size()))ready_=false;
    if(!data_.diagonal_flips.empty()){
        if(data_.width<2||data_.diagonal_flips.size()!=size_t(data_.width)*data_.width)ready_=false;
        else for(size_t i=0;i<data_.diagonal_flips.size();++i)
            if(data_.diagonal_flips[i]>1||(data_.diagonal_flips[i]&&(i%data_.width==size_t(data_.width-1)||i/data_.width==size_t(data_.width-1)))){ready_=false;break;}
    }
    minimum_=data_.origin;
    float extent=data_.width>0?(data_.width-1)*data_.spacing:480;
    maximum_=minimum_+Vec3{extent,0,extent};
    minimum_.x=std::max(minimum_.x,data_.bounds_min.x);minimum_.z=std::max(minimum_.z,data_.bounds_min.z);
    maximum_.x=std::min(maximum_.x,data_.bounds_max.x);maximum_.z=std::min(maximum_.z,data_.bounds_max.z);
    if(data_.obstacle_min.size()!=data_.obstacle_max.size()||data_.layer_min.size()!=data_.layer_max.size()||data_.pieces.size()%10)ready_=false;
    if(!ready_)return;
    if(!same_surface){
        piece_grid_.clear();piece_bounds_.clear();piece_visited_.assign(data_.pieces.size()/10,0);piece_visit_=0;
        for(size_t i=0;i<data_.pieces.size();i+=10){
            const float* p=data_.pieces.data()+i;
            bool valid=true;for(int n=0;n<10;++n)valid=valid&&std::isfinite(p[n]);
            if(!valid)continue;
            if(p[4]<0||p[5]<=0||p[6]>p[7])continue;
            float length2=p[2]*p[2]+p[3]*p[3];
            float lo_x=minimum_.x,lo_z=minimum_.z,hi_x=maximum_.x,hi_z=maximum_.z;
            if(length2>0&&std::isfinite(length2)){
                float ax=p[0]+p[2]*p[6]/length2,az=p[1]+p[3]*p[6]/length2;
                float bx=p[0]+p[2]*p[7]/length2,bz=p[1]+p[3]*p[7]/length2;
                float tolerance=.002f/std::sqrt(length2);
                float pad_x=std::abs(p[3])*p[4]/length2+tolerance,pad_z=std::abs(p[2])*p[4]/length2+tolerance;
                lo_x=std::max(minimum_.x,std::min(ax,bx)-pad_x);hi_x=std::min(maximum_.x,std::max(ax,bx)+pad_x);
                lo_z=std::max(minimum_.z,std::min(az,bz)-pad_z);hi_z=std::min(maximum_.z,std::max(az,bz)+pad_z);
            }else if(!std::isfinite(length2)||p[6]>0||p[7]<0)continue;
            if(!std::isfinite(lo_x)||!std::isfinite(lo_z)||!std::isfinite(hi_x)||!std::isfinite(hi_z)||lo_x>hi_x||lo_z>hi_z)continue;
            piece_bounds_.push_back({lo_x,lo_z,hi_x,hi_z});
            for(int x=int(std::floor(lo_x/OBSTACLE_CELL));x<=int(std::floor(hi_x/OBSTACLE_CELL));++x)
                for(int z=int(std::floor(lo_z/OBSTACLE_CELL));z<=int(std::floor(hi_z/OBSTACLE_CELL));++z)piece_grid_[key(x,z)].push_back(i);
        }
    }
    // A triangle stays inside its vertex range. Certify covered neighbourhoods
    // once; slopes, holes, rampart pieces and other layers keep exact sampling.
    if(!same_surface&&data_.width>0){
        int w=data_.width;field_spans_.assign(size_t(w)*w,INFINITY);
        for(int z=2;z<w-3;++z)for(int x=2;x<w-3;++x){
            double low=INFINITY,high=-INFINITY;bool covered=true;
            for(int dz=-2;dz<=3;++dz)for(int dx=-2;dx<=3;++dx){
                size_t i=size_t(z+dz)*w+x+dx;double h=data_.heights[i];
                if(!data_.covered[i]||!std::isfinite(h))covered=false;
                low=std::min(low,h);high=std::max(high,h);
            }
            if(covered)field_spans_[size_t(z)*w+x]=high-low+1e-6*(1+std::max(std::abs(low),std::abs(high)));
        }
        // Exact piece sampling is required only near explicit support; retain
        // the existing flat-field certificate everywhere else.
        for(const auto& box:piece_bounds_){
            int x0=std::max(0,int(std::floor((box[0]-data_.origin.x)/data_.spacing))-4);
            int z0=std::max(0,int(std::floor((box[1]-data_.origin.z)/data_.spacing))-4);
            int x1=std::min(w-1,int(std::ceil((box[2]-data_.origin.x)/data_.spacing))+3);
            int z1=std::min(w-1,int(std::ceil((box[3]-data_.origin.z)/data_.spacing))+3);
            for(int z=z0;z<=z1;++z)for(int x=x0;x<=x1;++x)field_spans_[size_t(z)*w+x]=INFINITY;
        }
    }
    for(size_t i=0;i<data_.obstacle_min.size();++i){
        auto a=data_.obstacle_min[i],b=data_.obstacle_max[i];
        if(!finite(a)||!finite(b)||a.x>b.x||a.y>b.y||a.z>b.z){ready_=false;return;}
        for(int x=int(std::floor(a.x/OBSTACLE_CELL));x<=int(std::floor(b.x/OBSTACLE_CELL));++x)
            for(int z=int(std::floor(a.z/OBSTACLE_CELL));z<=int(std::floor(b.z/OBSTACLE_CELL));++z)obstacle_grid_[key(x,z)].push_back(int(i));
    }
    bool shared=shared_air&&shared_air!=this&&shared_air->ready_&&data_.width==shared_air->data_.width&&data_.spacing==shared_air->data_.spacing&&
        !std::memcmp(&data_.origin,&shared_air->data_.origin,sizeof(Vec3))&&
        !std::memcmp(&data_.bounds_min,&shared_air->data_.bounds_min,sizeof(Vec3))&&!std::memcmp(&data_.bounds_max,&shared_air->data_.bounds_max,sizeof(Vec3))&&
        same(data_.heights,shared_air->data_.heights)&&same(data_.covered,shared_air->data_.covered)&&same(data_.diagonal_flips,shared_air->data_.diagonal_flips)&&
        same(data_.pieces,shared_air->data_.pieces)&&same(data_.layer_min,shared_air->data_.layer_min)&&same(data_.layer_max,shared_air->data_.layer_max)&&
        same(data_.air_faces,shared_air->data_.air_faces)&&same(data_.air_owner,shared_air->data_.air_owner);
    if(shared)air_=shared_air->air_;
    else{
        // A standalone terrain copy must retain its old collision geometry.
        if(air_.use_count()!=1)air_=std::make_shared<AirGeometry>(*air_);
        build_air(same_air_base,prefix);
    }
    if(same_surface&&!topologies_.empty()){
        using Box=std::array<float,6>;std::vector<Box> before,after,changed;
        auto boxes=[](const auto& low,const auto& high,auto& out){for(size_t i=0;i<low.size();++i)out.push_back({low[i].x,low[i].y,low[i].z,high[i].x,high[i].y,high[i].z});std::sort(out.begin(),out.end());};
        boxes(old_min,old_max,before);boxes(data_.obstacle_min,data_.obstacle_max,after);
        std::set_symmetric_difference(before.begin(),before.end(),after.begin(),after.end(),std::back_inserter(changed));
        // Re-certify only edges that can touch a changed obstacle. Heights,
        // holes, bridges or domain edits still take the complete rebuild above.
        for(auto& entry:topologies_)for(const auto& box:changed){
            auto& grid=entry.second;float pad=grid.radius+.05f+data_.route_spacing+.001f;
            int x0=std::max(0,int(std::floor((box[0]-pad-minimum_.x)/data_.route_spacing))),z0=std::max(0,int(std::floor((box[2]-pad-minimum_.z)/data_.route_spacing)));
            int x1=std::min(grid.nx-1,int(std::ceil((box[3]+pad-minimum_.x)/data_.route_spacing))),z1=std::min(grid.nz-1,int(std::ceil((box[5]+pad-minimum_.z)/data_.route_spacing)));
            if(x0<=x1&&z0<=z1)refresh_topology(grid,x0,z0,x1,z1);
        }
    }
}
double Terrain::height(float x,float z,int layer) const{
    if(navigation_profile.enabled)++navigation_profile.heights;
    if(!ready_||x<minimum_.x||z<minimum_.z||x>maximum_.x||z>maximum_.z)return NAN;
    if(layer>0){
        size_t i=size_t(layer-1);if(i>=data_.layer_min.size())return NAN;
        auto a=data_.layer_min[i],b=data_.layer_max[i];
        return x>=a.x-.001&&x<=b.x+.001&&z>=a.z-.001&&z<=b.z+.001?double(a.y):NAN;
    }
    double result=0;bool uncovered=false;
    if(data_.width>0){
        float px=(x-data_.origin.x)/data_.spacing,pz=(z-data_.origin.z)/data_.spacing;
        int ix=int(std::floor(px)),iz=int(std::floor(pz));
        if(ix<0||iz<0||ix>=data_.width-1||iz>=data_.width-1)return NAN;
        int at=iz*data_.width+ix;
        uncovered=!data_.covered[at]||!data_.covered[at+1]||!data_.covered[at+data_.width]||!data_.covered[at+data_.width+1];
        if(uncovered)result=NAN;
        else{
            double u=std::clamp(double(px)-ix,0.0,1.0),v=std::clamp(double(pz)-iz,0.0,1.0);
            double h00=data_.heights[at],h10=data_.heights[at+1],h01=data_.heights[at+data_.width],h11=data_.heights[at+data_.width+1];
            if(!data_.diagonal_flips.empty()&&data_.diagonal_flips[at])
                result=u>=v?h00+(h10-h00)*u+(h11-h10)*v:h00+(h11-h01)*u+(h01-h00)*v;
            else result=u+v<=1?h00+(h10-h00)*u+(h01-h00)*v:h11+(h01-h11)*(1-u)+(h10-h11)*(1-v);
        }
    }
    auto found=piece_grid_.find(key(int(std::floor(x/OBSTACLE_CELL)),int(std::floor(z/OBSTACLE_CELL))));
    if(found==piece_grid_.end())return result;
    for(size_t i:found->second){
        const float* p=data_.pieces.data()+i;float ox=x-p[0],oz=z-p[1];
        float along=ox*p[2]+oz*p[3],side=-ox*p[3]+oz*p[2];
        if(along<p[6]-.001||along>p[7]+.001||std::abs(side)>p[4]+.001||p[5]<=0)continue;
        double top=double(p[8])+(double(p[9])-p[8])*std::clamp(double(along)/p[5],0.0,1.0);
        if(!std::isfinite(top))continue;
        result=uncovered?top:std::max(result,top);uncovered=false;
    }
    return result;
}
int Terrain::choose_layer(Vec3 p) const{
    int best=-1;double gap=.3;
    for(size_t i=0;i<=data_.layer_min.size();++i){double h=height(p.x,p.z,int(i));if(std::isfinite(h)&&std::abs(h-p.y)<gap){gap=std::abs(h-p.y);best=int(i);}}
    return best;
}
bool Terrain::obstacles_clear(Vec3 p,float radius) const{
    int x0=int(std::floor((p.x-radius)/OBSTACLE_CELL)),x1=int(std::floor((p.x+radius)/OBSTACLE_CELL));
    int z0=int(std::floor((p.z-radius)/OBSTACLE_CELL)),z1=int(std::floor((p.z+radius)/OBSTACLE_CELL));
    float body_height=std::max(1.8f,radius*1.55f);
    for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z){
        auto it=obstacle_grid_.find(key(x,z));if(it==obstacle_grid_.end())continue;
        for(auto i:it->second){
            const auto& a=data_.obstacle_min[i];const auto& b=data_.obstacle_max[i];
            if(p.y+.05f>=b.y||p.y+body_height<=a.y)continue;
            float dx=p.x-std::clamp(p.x,a.x,b.x),dz=p.z-std::clamp(p.z,a.z,b.z);
            if(dx*dx+dz*dz<(radius+.05f)*(radius+.05f))return false;
        }
    }
    return true;
}
bool Terrain::clear(Vec3 p,float radius,int layer,bool check_objects) const{
    double center=height(p.x,p.z,layer);if(!std::isfinite(center))return false;
    if(layer==0&&!field_spans_.empty()&&radius>=0&&radius<=data_.spacing*2&&
       p.x-radius>=minimum_.x&&p.z-radius>=minimum_.z&&p.x+radius<=maximum_.x&&p.z+radius<=maximum_.z){
        int x=int(std::floor((p.x-data_.origin.x)/data_.spacing)),z=int(std::floor((p.z-data_.origin.z)/data_.spacing));
        // Check actual float32 endpoints, including rounding at cell borders.
        if(field_spans_[size_t(z)*data_.width+x]<=.15+radius*.35&&
           std::floor((p.x-radius-data_.origin.x)/data_.spacing)>=x-2&&std::floor((p.x+radius-data_.origin.x)/data_.spacing)+1<=x+3&&
           std::floor((p.z-radius-data_.origin.z)/data_.spacing)>=z-2&&std::floor((p.z+radius-data_.origin.z)/data_.spacing)+1<=z+3){p.y=float(center);return !check_objects||obstacles_clear(p,radius);}
    }
    for(auto axis:axes){double h=height(p.x+axis.x*radius,p.z+axis.z*radius,layer);if(!std::isfinite(h)||std::abs(h-center)>.15+radius*.35)return false;}
    p.y=float(center);return !check_objects||obstacles_clear(p,radius);
}
bool Terrain::swept_obstacles_clear(Vec3 from,Vec3 to,float radius) const{
    if(++obstacle_visit_==0){std::fill(obstacle_visited_.begin(),obstacle_visited_.end(),0);obstacle_visit_=1;}
    float body_height=std::max(1.8f,radius*1.55f),padding=radius+.05f;
    int x0=int(std::floor((std::min(from.x,to.x)-padding)/OBSTACLE_CELL)),x1=int(std::floor((std::max(from.x,to.x)+padding)/OBSTACLE_CELL));
    int z0=int(std::floor((std::min(from.z,to.z)-padding)/OBSTACLE_CELL)),z1=int(std::floor((std::max(from.z,to.z)+padding)/OBSTACLE_CELL));
    for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z){
        auto found=obstacle_grid_.find(key(x,z));if(found==obstacle_grid_.end())continue;
        for(int i:found->second){
            if(obstacle_visited_[i]==obstacle_visit_)continue;obstacle_visited_[i]=obstacle_visit_;
            const auto& a=data_.obstacle_min[i];const auto& b=data_.obstacle_max[i];
            if(std::max(from.y,to.y)+body_height<=a.y||std::min(from.y,to.y)+.05f>=b.y)continue;
            if(segment_rectangle_distance(from,to,a,b)<padding*padding)return false;
        }
    }
    return true;
}
bool Terrain::segment(Vec3 from,Vec3 to,float radius,int layer,bool check_objects) const{
    if(navigation_profile.enabled)++navigation_profile.segments;
    if(check_objects&&!swept_obstacles_clear(from,to,radius))return false;
    float distance=std::hypot(to.x-from.x,to.z-from.z);int count=std::max(1,int(std::ceil(distance/.7f)));
    double previous=height(from.x,from.z,layer);if(!std::isfinite(previous))return false;
    bool inspect_edges=layer<=0&&data_.width>0&&distance>.7f;
    bool certified=inspect_edges&&!field_spans_.empty()&&radius+.701f<=data_.spacing*2&&data_.spacing>=.7;
    auto certify=[&](Vec3 p){
        if(!certified)return;
        int x=int(std::floor((p.x-data_.origin.x)/data_.spacing)),z=int(std::floor((p.z-data_.origin.z)/data_.spacing));
        certified=x>=0&&z>=0&&x<data_.width&&z<data_.width&&field_spans_[size_t(z)*data_.width+x]<=.15+radius*.35;
    };
    certify(from);
    Vec3 old=from;
    for(int i=1;i<=count;++i){
        Vec3 p=from+(to-from)*(float(i)/count);double h=height(p.x,p.z,layer);
        float travel=std::hypot(p.x-old.x,p.z-old.z);
        if(!std::isfinite(h)||std::abs(h-previous)>.15+travel*.35||!clear(p,radius,layer,check_objects))return false;
        certify(p);
        old=p;previous=h;
    }
    // Each cached neighbourhood covers the body plus the entire next .7-metre interval.
    if(inspect_edges&&!certified){
        // Body clearance is piecewise linear; its extrema occur at terrain triangle edges.
        Vec3 offsets[9]{};for(int i=0;i<8;++i)offsets[i+1]=axes[i]*radius;
        for(int sample=0;sample<9;++sample)for(int axis=0;axis<(data_.diagonal_flips.empty()?3:4);++axis){
            Vec3 offset=offsets[sample];
            auto coordinate=[&](Vec3 p){
                double x=(double(p.x)+offset.x-data_.origin.x)/data_.spacing;
                double z=(double(p.z)+offset.z-data_.origin.z)/data_.spacing;
                return axis==0?x:axis==1?z:axis==2?x+z:x-z;
            };
            double a=coordinate(from),b=coordinate(to);
            for(double edge=std::floor(std::min(a,b))+1;edge<std::max(a,b);++edge){
                float t=float((edge-a)/(b-a));
                Vec3 p=from+(to-from)*t;
                if(axis>=2&&!data_.diagonal_flips.empty()){
                    float px=(p.x+offset.x-data_.origin.x)/data_.spacing,pz=(p.z+offset.z-data_.origin.z)/data_.spacing;
                    int ix=int(std::floor(px)),iz=int(std::floor(pz));
                    if(ix<0||iz<0||ix>=data_.width-1||iz>=data_.width-1)continue;
                    bool flipped=data_.diagonal_flips[size_t(iz)*data_.width+ix]!=0;
                    if(flipped!=(axis==3))continue;
                }
                if(sample==0){if(!clear(p,radius,layer,check_objects))return false;}
                else{
                    double center=height(p.x,p.z,layer),foot=height(p.x+offset.x,p.z+offset.z,layer);
                    if(!std::isfinite(foot)||!std::isfinite(center)||std::abs(foot-center)>.15+radius*.35)return false;
                }
            }
        }
    }
    if(layer<=0&&!piece_grid_.empty()&&!certified){
        // Fine source lips may be narrower than the ordinary .7m interval.
        // Test their exact boundaries using local buckets, without allocating
        // candidate lists or scanning every prepared support piece.
        if(++piece_visit_==0){std::fill(piece_visited_.begin(),piece_visited_.end(),0);piece_visit_=1;}
        Vec3 offsets[9]{};for(int i=0;i<8;++i)offsets[i+1]=axes[i]*radius;
        int x0=int(std::floor(std::max(minimum_.x,std::min(from.x,to.x)-radius-.002f)/OBSTACLE_CELL));
        int z0=int(std::floor(std::max(minimum_.z,std::min(from.z,to.z)-radius-.002f)/OBSTACLE_CELL));
        int x1=int(std::floor(std::min(maximum_.x,std::max(from.x,to.x)+radius+.002f)/OBSTACLE_CELL));
        int z1=int(std::floor(std::min(maximum_.z,std::max(from.z,to.z)+radius+.002f)/OBSTACLE_CELL));
        for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z){
            auto bucket=piece_grid_.find(key(x,z));if(bucket==piece_grid_.end())continue;
            for(size_t index:bucket->second){
                if(piece_visited_[index/10]==piece_visit_)continue;piece_visited_[index/10]=piece_visit_;
                const float* piece=data_.pieces.data()+index;
                for(int sample=0;sample<9;++sample)for(int axis=0;axis<2;++axis){
                    Vec3 offset=offsets[sample];
                    auto coordinate=[&](Vec3 p){float ox=p.x+offset.x-piece[0],oz=p.z+offset.z-piece[1];return axis?double(-ox*piece[3]+oz*piece[2]):double(ox*piece[2]+oz*piece[3]);};
                    double a=coordinate(from),b=coordinate(to);if(std::abs(b-a)<1e-12)continue;
                    double edges[]{axis?-piece[4]-.001:piece[6]-.001,axis?piece[4]+.001:piece[7]+.001};
                    for(double edge:edges){
                        double t=(edge-a)/(b-a);if(t<=0||t>=1)continue;
                        double epsilon=.00005/std::abs(b-a);double old_height=NAN;Vec3 old_point{};
                        for(double at:{std::max(0.0,t-epsilon),std::min(1.0,t+epsilon)}){
                            Vec3 p=from+(to-from)*float(at);double center=height(p.x,p.z,layer);
                            if(!std::isfinite(center))return false;
                            if(sample==0){
                                if(!clear(p,radius,layer,check_objects))return false;
                                if(std::isfinite(old_height)&&std::abs(center-old_height)>.15+std::hypot(p.x-old_point.x,p.z-old_point.z)*.35)return false;
                                old_height=center;old_point=p;
                            }else{
                                double foot=height(p.x+offset.x,p.z+offset.z,layer);
                                if(!std::isfinite(foot)||std::abs(foot-center)>.15+radius*.35)return false;
                            }
                        }
                    }
                }
            }
        }
    }
    return true;
}
bool Terrain::prepare_routes(const std::vector<float>& radii){
    if(!ready_)return false;
    for(float radius:radii)if(!std::isfinite(radius)||radius<=0||radius>=1e7f)return false;
    for(float radius:radii)topology(radius,0);
    return true;
}
Terrain::Topology& Terrain::topology(float radius,int layer){
    uint32_t bits;std::memcpy(&bits,&radius,sizeof(bits));int64_t id=int64_t((uint64_t(layer)<<32)|bits);
    auto found=topologies_.find(id);if(found!=topologies_.end())return found->second;
    ProfileScope scope(navigation_profile.enabled?&navigation_profile.topology_ms:nullptr);
    if(navigation_profile.enabled)++navigation_profile.topology_builds;
    auto& result=topologies_[id];result.layer=layer;result.radius=radius;
    result.nx=int(std::floor((maximum_.x-minimum_.x)/data_.route_spacing))+1;
    result.nz=int(std::floor((maximum_.z-minimum_.z)/data_.route_spacing))+1;
    int count=result.nx*result.nz;result.heights.resize(count);result.open.resize(count);result.edges.resize(count);
    refresh_topology(result,0,0,result.nx-1,result.nz-1);
    return result;
}
void Terrain::refresh_topology(Topology& result,int x0,int z0,int x1,int z1){
    result.components.clear();
    for(int z=z0;z<=z1;++z)for(int x=x0;x<=x1;++x){
        int i=z*result.nx+x;Vec3 p{minimum_.x+x*data_.route_spacing,0,minimum_.z+z*data_.route_spacing};
        p.y=float(height(p.x,p.z,result.layer));result.heights[i]=p.y;
        result.open[i]=std::isfinite(p.y)&&clear(p,result.radius,result.layer);result.edges[i]=0;
        for(int direction=0;direction<4;++direction){int xx=x+dx[direction],zz=z+dz[direction];if(xx>=0&&zz>=0&&xx<result.nx&&zz<result.nz)result.edges[zz*result.nx+xx]&=~(1<<(direction^1));}
    }
    for(int z=z0;z<=z1;++z)for(int x=x0;x<=x1;++x){
        int i=z*result.nx+x;if(!result.open[i])continue;
        for(int direction=0;direction<4;++direction){
            int xx=x+dx[direction],zz=z+dz[direction];if(xx<0||zz<0||xx>=result.nx||zz>=result.nz)continue;
            if((direction&1)&&xx>=x0&&xx<=x1&&zz>=z0&&zz<=z1)continue;
            int next=zz*result.nx+xx;if(!result.open[next])continue;
            Vec3 a{minimum_.x+x*data_.route_spacing,result.heights[i],minimum_.z+z*data_.route_spacing};
            Vec3 b{minimum_.x+xx*data_.route_spacing,result.heights[next],minimum_.z+zz*data_.route_spacing};
            if((direction&1)?segment(b,a,result.radius,result.layer):segment(a,b,result.radius,result.layer)){result.edges[i]|=1<<direction;result.edges[next]|=1<<(direction^1);}
        }
    }
}
Vec3 Terrain::waypoint(Vec3 from,Vec3 goal,float radius,int layer){
    ProfileScope scope(navigation_profile.enabled?&navigation_profile.route_ms:nullptr);
    if(navigation_profile.enabled)++navigation_profile.waypoints;
    uint32_t bits;std::memcpy(&bits,&radius,sizeof(bits));
    // Exact inputs only; nearby roots/goals can straddle cliffs or bridge edges.
    std::array<uint32_t,8> route_key{};
    std::memcpy(&route_key[0],&from.x,sizeof(float));std::memcpy(&route_key[1],&from.y,sizeof(float));std::memcpy(&route_key[2],&from.z,sizeof(float));
    std::memcpy(&route_key[3],&goal.x,sizeof(float));std::memcpy(&route_key[4],&goal.y,sizeof(float));std::memcpy(&route_key[5],&goal.z,sizeof(float));
    route_key[6]=bits;route_key[7]=uint32_t(layer);
    uint64_t hash=14695981039346656037ull;
    for(auto value:route_key){hash^=value;hash*=1099511628211ull;hash^=hash>>32;}
    if(route_certificates_.empty())route_certificates_.resize(8192);
    auto& certificate=route_certificates_[hash%route_certificates_.size()];
    if(certificate.valid&&certificate.key==route_key){if(navigation_profile.enabled)++navigation_profile.route_hits;return certificate.point;}
    auto& grid=topology(radius,layer);
    int gx=std::clamp(int(std::round((goal.x-minimum_.x)/data_.route_spacing)),0,grid.nx-1);
    int gz=std::clamp(int(std::round((goal.z-minimum_.z)/data_.route_spacing)),0,grid.nz-1);
    // Test the nearest goal connector first, preserving the original row-order ties.
    struct GoalCandidate {Vec3 point;float distance;int index;};
    std::array<GoalCandidate,25> goals;int goal_count=0;
    for(int z=std::max(0,gz-2);z<=std::min(grid.nz-1,gz+2);++z)for(int x=std::max(0,gx-2);x<=std::min(grid.nx-1,gx+2);++x){
        int i=z*grid.nx+x;if(!grid.open[i])continue;
        Vec3 p{minimum_.x+x*data_.route_spacing,grid.heights[i],minimum_.z+z*data_.route_spacing};float distance=length(p-goal);
        if(distance*distance<data_.route_spacing*data_.route_spacing*2)goals[goal_count++]={p,distance*distance,i};
    }
    std::sort(goals.begin(),goals.begin()+goal_count,[](const GoalCandidate& a,const GoalCandidate& b){return a.distance<b.distance||(a.distance==b.distance&&a.index<b.index);});
    int target=-1;
    for(int i=0;i<goal_count;++i)if(segment(goals[i].point,goal,radius,layer)&&reachable(from,goals[i].point,radius,layer,true)){target=goals[i].index;break;}
    if(target<0){certificate={route_key,{NAN,0,0},true};return certificate.point;}
    int64_t topology_id=int64_t((uint64_t(layer)<<32)|bits);
    auto found=std::find_if(flows_.begin(),flows_.end(),[&](const Flow& f){return f.topology==topology_id&&f.goal==target;});
    if(found==flows_.end()){
        ProfileScope scope(navigation_profile.enabled?&navigation_profile.flow_ms:nullptr);
        if(navigation_profile.enabled)++navigation_profile.flow_builds;
        if(flows_.size()>=64){auto oldest=std::min_element(flows_.begin(),flows_.end(),[](const Flow& a,const Flow& b){return a.used<b.used;});flows_.erase(oldest);}
        Flow flow;flow.topology=topology_id;flow.goal=target;flow.cost.assign(grid.open.size(),INFINITY);flow.cost[target]=0;
        std::queue<int> queue;queue.push(target);
        while(!queue.empty()){
            int i=queue.front();queue.pop();
            for(int direction=0;direction<4;++direction){
                if(!(grid.edges[i]&(1<<direction)))continue;
                int next=i+dx[direction]+dz[direction]*grid.nx;
                if(flow.cost[next]<=flow.cost[i]+data_.route_spacing)continue;
                flow.cost[next]=flow.cost[i]+data_.route_spacing;queue.push(next);
            }
        }
        flows_.push_back(std::move(flow));found=flows_.end()-1;
    }
    found->used=++clock_;
    int fx=std::clamp(int(std::round((from.x-minimum_.x)/data_.route_spacing)),0,grid.nx-1);
    int fz=std::clamp(int(std::round((from.z-minimum_.z)/data_.route_spacing)),0,grid.nz-1);
    // The old traversal repeatedly certified improving candidates. Order the
    // same nine scores first, then certify only until the first clear route.
    // Equal scores retain row order, exactly matching the original strict <.
    struct Candidate {Vec3 point;float score;int order;};
    std::array<Candidate,9> candidates;int count=0;
    for(int z=std::max(0,fz-1);z<=std::min(grid.nz-1,fz+1);++z)for(int x=std::max(0,fx-1);x<=std::min(grid.nx-1,fx+1);++x){
        int i=z*grid.nx+x;if(!std::isfinite(found->cost[i]))continue;
        // Flow costs count horizontal steps; mixing in height makes uphill troops turn back.
        Vec3 point{minimum_.x+x*data_.route_spacing,grid.heights[i],minimum_.z+z*data_.route_spacing};float distance=std::hypot(point.x-from.x,point.z-from.z),score=found->cost[i]+distance;
        if(distance<.1f||!std::isfinite(score))continue;
        candidates[count]={point,score,count};++count;
    }
    std::sort(candidates.begin(),candidates.begin()+count,[](const Candidate& a,const Candidate& b){return a.score<b.score||(a.score==b.score&&a.order<b.order);});
    Vec3 best{NAN,0,0};
    for(int i=0;i<count;++i)if(segment(from,candidates[i].point,radius,layer)){best=candidates[i].point;break;}
    certificate={route_key,best,true};
    return best;
}
bool Terrain::reachable(Vec3 from,Vec3 goal,float radius,int layer){
    // Target selection shares the waypoint connectivity proof before resampling long corridors.
    return reachable(from,goal,radius,layer,true);
}
bool Terrain::reachable(Vec3 from,Vec3 goal,float radius,int layer,bool components_first){
    if(!ready_||!finite(from)||!finite(goal)||!std::isfinite(radius)||radius<0)return false;
    if(layer<0)layer=choose_layer(from);
    if(layer<0||!clear(goal,radius,layer))return false;
    // A waypoint can use short, exact connections to its existing route grid.
    components_first=components_first&&(std::abs(from.x-goal.x)>data_.route_spacing*3||std::abs(from.z-goal.z)>data_.route_spacing*3);
    if(!components_first&&segment(from,goal,radius,layer))return true;
    auto& grid=topology(radius,layer);
    // Reachability shares geometry components; it never builds a flow per candidate.
    if(grid.components.empty()){
        grid.components.assign(grid.open.size(),-1);std::vector<int> queue;
        for(size_t root=0;root<grid.open.size();++root){
            if(!grid.open[root]||grid.components[root]>=0)continue;
            grid.components[root]=int(root);queue.clear();queue.push_back(int(root));
            for(size_t at=0;at<queue.size();++at){int i=queue[at];
                for(int direction=0;direction<4;++direction)if(grid.edges[i]&(1<<direction)){
                    int next=i+dx[direction]+dz[direction]*grid.nx;
                    if(grid.components[next]>=0)continue;
                    grid.components[next]=int(root);queue.push_back(next);
                }
            }
        }
    }
    int fx=int(std::round((from.x-minimum_.x)/data_.route_spacing)),fz=int(std::round((from.z-minimum_.z)/data_.route_spacing));
    int gx=int(std::round((goal.x-minimum_.x)/data_.route_spacing)),gz=int(std::round((goal.z-minimum_.z)/data_.route_spacing));
    if(components_first&&fx>=0&&fx<grid.nx&&fz>=0&&fz<grid.nz&&gx>=0&&gx<grid.nx&&gz>=0&&gz<grid.nz){
        int root=fz*grid.nx+fx,target=gz*grid.nx+gx;
        Vec3 entry{minimum_.x+fx*data_.route_spacing,grid.heights[root],minimum_.z+fz*data_.route_spacing};
        Vec3 exit{minimum_.x+gx*data_.route_spacing,grid.heights[target],minimum_.z+gz*data_.route_spacing};
        if(grid.open[root]&&grid.open[target]&&grid.components[root]==grid.components[target]&&
           length(exit-goal)<data_.route_spacing*1.414214f&&segment(from,entry,radius,layer)&&segment(exit,goal,radius,layer))return true;
    }
    std::array<int,9> components{};int count=0;
    for(int z=std::max(0,fz-1);z<=std::min(grid.nz-1,fz+1);++z)for(int x=std::max(0,fx-1);x<=std::min(grid.nx-1,fx+1);++x){
        int i=z*grid.nx+x;if(!grid.open[i])continue;
        Vec3 point{minimum_.x+x*data_.route_spacing,grid.heights[i],minimum_.z+z*data_.route_spacing};
        if(segment(from,point,radius,layer))components[count++]=grid.components[i];
    }
    for(int z=std::max(0,gz-2);z<=std::min(grid.nz-1,gz+2);++z)for(int x=std::max(0,gx-2);x<=std::min(grid.nx-1,gx+2);++x){
        int i=z*grid.nx+x;if(!grid.open[i]||std::find(components.begin(),components.begin()+count,grid.components[i])==components.begin()+count)continue;
        Vec3 point{minimum_.x+x*data_.route_spacing,grid.heights[i],minimum_.z+z*data_.route_spacing};
        if(length(point-goal)<data_.route_spacing*1.414214f&&segment(point,goal,radius,layer))return true;
    }
    return components_first&&segment(from,goal,radius,layer);
}
Vec3 Terrain::move(Vec3 from,Vec3 goal,float speed,float delta,float radius,int& layer,bool& routing,Vec3 avoidance,float lane,Vec3 sidestep){
    if(!ready_||!finite(from)||!finite(goal)||speed<=0||delta<=0)return from;
    if(layer<0)layer=choose_layer(from);if(layer<0)return from;
    Vec3 aim=goal;
    if(routing){
        if(length(goal-from)<data_.route_spacing*1.5f&&segment(from,goal,radius,layer))routing=false;
        else{aim=waypoint(from,goal,radius,layer);if(!finite(aim))return from;}
    }
    auto candidate=[&](Vec3 target){
        Vec3 direction=target-from;float distance=length(direction);
        if(distance<.001f)return from;
        Vec3 motion=direction*(std::min(speed*delta,distance)/distance)+avoidance*delta;
        float magnitude=length(motion);if(magnitude>speed*delta)motion=motion*(speed*delta/magnitude);
        Vec3 p=from+motion;
        // Keep the ordinary step when a wall or ledge blocks the sidestep.
        if(dot(sidestep,sidestep)>0){
            Vec3 shifted=p+sidestep*delta;
            if(segment(from,shifted,radius,layer)){shifted.y=float(height(shifted.x,shifted.z,layer));return shifted;}
        }
        if(!segment(from,p,radius,layer))return Vec3{NAN,0,0};
        p.y=float(height(p.x,p.z,layer));return p;
    };
    auto spread=[&](Vec3 target){
        if(lane!=0){
            Vec3 forward=target-from;forward.y=0;float distance=length(forward);
            if(distance>.001f){
                float width=lane*std::min(1.0f,distance/6);
                Vec3 p=candidate(target+Vec3{-forward.z,0,forward.x}*(width/distance));
                if(finite(p))return p;
            }
        }
        return candidate(target);
    };
    Vec3 p=spread(aim);if(finite(p))return p;
    routing=true;aim=waypoint(from,goal,radius,layer);
    if(!finite(aim))return from;
    p=spread(aim);return finite(p)?p:from;
}
bool Terrain::ray_clear(Vec3 from,Vec3 to,int64_t ignore) const{
    if(!ready_||!finite(from)||!finite(to))return false;
    if(!data_.air_faces.empty()&&!air_ray_clear(from,to,ignore))return false;
    Vec3 direction=to-from;
    const auto& lows=data_.ray_min.empty()&&data_.air_faces.empty()?data_.obstacle_min:data_.ray_min;
    const auto& highs=data_.ray_min.empty()&&data_.air_faces.empty()?data_.obstacle_max:data_.ray_max;
    for(size_t i=0;i<lows.size()&&i<highs.size();++i){
        if(ignore>=0&&i<data_.ray_owner.size()&&data_.ray_owner[i]==ignore)continue;
        float first=0,last=1;const auto& a=lows[i];const auto& b=highs[i];
        const float start[]={from.x,from.y,from.z},delta[]={direction.x,direction.y,direction.z},lo[]={a.x,a.y,a.z},hi[]={b.x,b.y,b.z};
        bool hit=true;
        for(int axis=0;axis<3;++axis){
            if(std::abs(delta[axis])<1e-7f){if(start[axis]<lo[axis]||start[axis]>hi[axis]){hit=false;break;}continue;}
            float t0=(lo[axis]-start[axis])/delta[axis],t1=(hi[axis]-start[axis])/delta[axis];if(t0>t1)std::swap(t0,t1);
            first=std::max(first,t0);last=std::min(last,t1);if(first>last){hit=false;break;}
        }
        if(hit&&last>.00001f&&first<.99999f)return false;
    }
    int count=std::max(1,int(std::ceil(length(direction)/.5f)));
    for(int i=1;i<count;++i){Vec3 p=from+direction*(float(i)/count);double floor=height(p.x,p.z);if(std::isfinite(floor)&&p.y<floor-.05)return false;}
    return true;
}
}
