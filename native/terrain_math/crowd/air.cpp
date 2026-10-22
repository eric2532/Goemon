#include "terrain.h"
#include <algorithm>
#include <limits>
namespace army {
namespace {
uint64_t air_key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
Vec3 closest(Vec3 p,Vec3 a,Vec3 b,Vec3 c){
    Vec3 ab=b-a,ac=c-a,ap=p-a;float d1=dot(ab,ap),d2=dot(ac,ap);
    if(d1<=0&&d2<=0)return a;
    Vec3 bp=p-b;float d3=dot(ab,bp),d4=dot(ac,bp);if(d3>=0&&d4<=d3)return b;
    float vc=d1*d4-d3*d2;if(vc<=0&&d1>=0&&d3<=0)return a+ab*(d1/(d1-d3));
    Vec3 cp=p-c;float d5=dot(ab,cp),d6=dot(ac,cp);if(d6>=0&&d5<=d6)return c;
    float vb=d5*d2-d1*d6;if(vb<=0&&d2>=0&&d6<=0)return a+ac*(d2/(d2-d6));
    float va=d3*d6-d5*d4;if(va<=0&&(d4-d3)>=0&&(d5-d6)>=0)return b+(c-b)*((d4-d3)/(d4-d3+d5-d6));
    float inv=1/(va+vb+vc);return a+ab*(vb*inv)+ac*(vc*inv);
}
bool triangle_ray(Vec3 from,Vec3 motion,Vec3 a,Vec3 b,Vec3 c,float& t){
    Vec3 ab=b-a,ac=c-a,h=cross(motion,ac);float det=dot(ab,h);if(std::abs(det)<1e-8f)return false;
    float inv=1/det;Vec3 s=from-a;float u=dot(s,h)*inv;if(u<-.00001f||u>1.00001f)return false;
    Vec3 q=cross(s,ab);float v=dot(motion,q)*inv;if(v<-.00001f||u+v>1.00001f)return false;
    t=dot(ac,q)*inv;return t>=0&&t<=1;
}
void segment_pair(Vec3 a,Vec3 b,Vec3 c,Vec3 d,Vec3& p,Vec3& q){
    Vec3 u=b-a,v=d-c,w=a-c;float aa=dot(u,u),bb=dot(u,v),cc=dot(v,v),dd=dot(u,w),ee=dot(v,w),denom=aa*cc-bb*bb;
    float s=denom>1e-8f?std::clamp((bb*ee-cc*dd)/denom,0.0f,1.0f):0;
    float t=cc>1e-8f?std::clamp((bb*s+ee)/cc,0.0f,1.0f):0;
    if(aa>1e-8f)s=std::clamp((bb*t-dd)/aa,0.0f,1.0f);
    if(cc>1e-8f)t=std::clamp((bb*s+ee)/cc,0.0f,1.0f);
    p=a+u*s;q=c+v*t;
}
float capsule_triangle(Vec3 lower,Vec3 upper,Vec3 a,Vec3 b,Vec3 c,Vec3& normal){
    float t;if(triangle_ray(lower,upper-lower,a,b,c,t)){normal=normalized(cross(b-a,c-a));if(normal.y<0)normal=normal*-1;return 0;}
    Vec3 p=lower,q=closest(lower,a,b,c);float best=length(p-q);
    auto consider=[&](Vec3 x,Vec3 y){float gap=length(x-y);if(gap<best){best=gap;p=x;q=y;}};
    consider(upper,closest(upper,a,b,c));Vec3 x,y;
    segment_pair(lower,upper,a,b,x,y);consider(x,y);segment_pair(lower,upper,b,c,x,y);consider(x,y);segment_pair(lower,upper,c,a,x,y);consider(x,y);
    normal=best>1e-7f?(p-q)*(1/best):normalized(cross(b-a,c-a));return best;
}
}
int Terrain::build_air_node(int first,int end){
    AirNode node;node.first=first;node.count=end-first;
    node.low={INFINITY,INFINITY,INFINITY};node.high={-INFINITY,-INFINITY,-INFINITY};
    for(int j=first;j<end;++j){auto a=air_minimum_[air_order_[j]],b=air_maximum_[air_order_[j]];
        node.low={std::min(node.low.x,a.x),std::min(node.low.y,a.y),std::min(node.low.z,a.z)};
        node.high={std::max(node.high.x,b.x),std::max(node.high.y,b.y),std::max(node.high.z,b.z)};
    }
    int index=int(air_nodes_.size());air_nodes_.push_back(node);
    if(end-first>8){
        auto span=node.high-node.low;int axis=span.x>=span.z?0:2;if(span.y>std::max(span.x,span.z))axis=1;
        auto center=[&](int row){auto a=air_minimum_[row],b=air_maximum_[row];return axis==0?a.x+b.x:(axis==1?a.y+b.y:a.z+b.z);};
        int middle=(first+end)/2;
        std::nth_element(air_order_.begin()+first,air_order_.begin()+middle,air_order_.begin()+end,[&](int a,int b){return center(a)<center(b);});
        int left=build_air_node(first,middle),right=build_air_node(middle,end);air_nodes_[index].left=left;air_nodes_[index].right=right;
    }
    return index;
}
void Terrain::build_air(){
    air_order_.clear();air_nodes_.clear();air_faces_.clear();air_grid_.clear();air_owner_.clear();air_minimum_.clear();air_maximum_.clear();int64_t owner=-1;
    auto tri=[&](Vec3 a,Vec3 b,Vec3 c){if(finite(a)&&finite(b)&&finite(c)&&length(cross(b-a,c-a))>1e-6f){air_faces_.push_back(a);air_faces_.push_back(b);air_faces_.push_back(c);air_owner_.push_back(owner);}};
    auto quad=[&](Vec3 a,Vec3 b,Vec3 c,Vec3 d){tri(a,b,c);tri(a,c,d);};
    if(data_.width==0)quad({minimum_.x,0,minimum_.z},{minimum_.x,0,maximum_.z},{maximum_.x,0,maximum_.z},{maximum_.x,0,minimum_.z});
    else for(int z=0;z<data_.width-1;++z)for(int x=0;x<data_.width-1;++x){
        int i=z*data_.width+x;if(!data_.covered[i]||!data_.covered[i+1]||!data_.covered[i+data_.width]||!data_.covered[i+data_.width+1])continue;
        Vec3 a{data_.origin.x+x*data_.spacing,data_.heights[i],data_.origin.z+z*data_.spacing},b{a.x+data_.spacing,data_.heights[i+1],a.z},c{a.x,data_.heights[i+data_.width],a.z+data_.spacing},d{b.x,data_.heights[i+data_.width+1],c.z};tri(a,c,b);tri(b,c,d);
    }
    for(size_t i=0;i<data_.layer_min.size();++i){auto a=data_.layer_min[i],b=data_.layer_max[i];quad(a,{a.x,a.y,b.z},{b.x,a.y,b.z},{b.x,a.y,a.z});}
    // Saved ramparts use these same eight physical prism vertices in Godot.
    for(size_t i=0;i<data_.pieces.size();i+=10){
        const float* p=data_.pieces.data()+i;if(p[5]<=0)continue;Vec3 v[8];
        for(int k=0;k<4;++k){float along=k<2?p[6]:p[7],side=(k==0||k==3)?-p[4]:p[4];v[k]={p[0]+p[2]*along-p[3]*side,-.2f,p[1]+p[3]*along+p[2]*side};v[k+4]=v[k];v[k+4].y=p[8]+(p[9]-p[8])*std::clamp(along/p[5],0.0f,1.0f);}
        const int faces[][4]={{4,5,6,7},{0,3,2,1},{0,1,5,4},{1,2,6,5},{2,3,7,6},{3,0,4,7}};for(auto& f:faces)quad(v[f[0]],v[f[1]],v[f[2]],v[f[3]]);
    }
    for(size_t i=0;i+2<data_.air_faces.size();i+=3){owner=i/3<data_.air_owner.size()?data_.air_owner[i/3]:-1;tri(data_.air_faces[i],data_.air_faces[i+1],data_.air_faces[i+2]);}
    for(size_t i=0;i<air_faces_.size();i+=3){auto a=air_faces_[i],b=air_faces_[i+1],c=air_faces_[i+2];
        // Retain the ray's original barycentric tolerance and conservative
        // floating-point roundoff margin, including long fixture triangles.
        auto margin=[](float a,float b,float c){return (std::abs(b-a)+std::abs(c-a))*.00002f+std::max({std::abs(a),std::abs(b),std::abs(c)})*std::numeric_limits<float>::epsilon()*8+.00001f;};
        Vec3 pad{margin(a.x,b.x,c.x),margin(a.y,b.y,c.y),margin(a.z,b.z,c.z)};
        air_minimum_.push_back(Vec3{std::min({a.x,b.x,c.x}),std::min({a.y,b.y,c.y}),std::min({a.z,b.z,c.z})}-pad);
        air_maximum_.push_back(Vec3{std::max({a.x,b.x,c.x}),std::max({a.y,b.y,c.y}),std::max({a.z,b.z,c.z})}+pad);
        for(int x=int(std::floor(std::min({a.x,b.x,c.x})/12));x<=int(std::floor(std::max({a.x,b.x,c.x})/12));++x)
            for(int z=int(std::floor(std::min({a.z,b.z,c.z})/12));z<=int(std::floor(std::max({a.z,b.z,c.z})/12));++z)air_grid_[air_key(x,z)].push_back(int(i));
    }
    air_order_.resize(air_minimum_.size());
    for(int i=0;i<int(air_order_.size());++i)air_order_[i]=i;
    if(!air_order_.empty())build_air_node(0,int(air_order_.size()));
}
std::vector<int> Terrain::air_candidates(Vec3 low,Vec3 high,bool bounded) const{
    std::vector<int> result;
    if(bounded&&!air_nodes_.empty()){
        int x0=int(std::floor(low.x/12)),x1=int(std::floor(high.x/12)),z0=int(std::floor(low.z/12)),z1=int(std::floor(high.z/12));
        auto outside=[&](Vec3 a,Vec3 b){return a.x>high.x||b.x<low.x||a.y>high.y||b.y<low.y||a.z>high.z||b.z<low.z;};
        auto visit=[&](auto&& self,int index)->void{
            const auto& node=air_nodes_[index];if(outside(node.low,node.high))return;
            if(node.left>=0){self(self,node.left);self(self,node.right);return;}
            if(air_profile.enabled)air_profile.considered+=node.count;
            for(int j=node.first;j<node.first+node.count;++j){int row=air_order_[j];
                if(outside(air_minimum_[row],air_maximum_[row]))continue;
                int i=row*3;auto a=air_faces_[i],b=air_faces_[i+1],c=air_faces_[i+2];
                // Keep the original coarse-grid eligibility, including epsilon
                // spill at bucket boundaries, and restore source face order below.
                if(int(std::floor(std::min({a.x,b.x,c.x})/12))>x1||int(std::floor(std::max({a.x,b.x,c.x})/12))<x0||int(std::floor(std::min({a.z,b.z,c.z})/12))>z1||int(std::floor(std::max({a.z,b.z,c.z})/12))<z0)continue;
                result.push_back(i);
            }
        };
        visit(visit,0);
    }else{
    for(int x=int(std::floor(low.x/12));x<=int(std::floor(high.x/12));++x)for(int z=int(std::floor(low.z/12));z<=int(std::floor(high.z/12));++z){
        auto it=air_grid_.find(air_key(x,z));if(it==air_grid_.end())continue;
        if(air_profile.enabled)air_profile.considered+=it->second.size();
        if(!bounded){result.insert(result.end(),it->second.begin(),it->second.end());continue;}
        for(int i:it->second){const auto& a=air_minimum_[i/3];const auto& b=air_maximum_[i/3];
            if(a.x>high.x||b.x<low.x||a.y>high.y||b.y<low.y||a.z>high.z||b.z<low.z)continue;
            result.push_back(i);
        }
    }
    }
    std::sort(result.begin(),result.end());result.erase(std::unique(result.begin(),result.end()),result.end());
    if(air_profile.enabled)air_profile.kept+=result.size();return result;
}
bool Terrain::air_ray_clear(Vec3 from,Vec3 to,int64_t ignore) const{
    Vec3 low{std::min(from.x,to.x),std::min(from.y,to.y),std::min(from.z,to.z)},high{std::max(from.x,to.x),std::max(from.y,to.y),std::max(from.z,to.z)};
    for(int i:air_candidates(low,high,true)){if(ignore>=0&&air_owner_[i/3]==ignore)continue;float t;if(triangle_ray(from,to-from,air_faces_[i],air_faces_[i+1],air_faces_[i+2],t)&&t>.00001f&&t<.99999f)return false;}
    return true;
}
Vec3 Terrain::landing(Vec3 aim,float top,bool& valid) const{
    valid=false;if(!ready_)return aim;
    aim.x=std::clamp(aim.x,minimum_.x,maximum_.x);aim.z=std::clamp(aim.z,minimum_.z,maximum_.z);
    float first=2;Vec3 start{aim.x,top,aim.z},motion{0,-256,0};
    for(int i:air_candidates(start+motion,start,true)){float t;if(triangle_ray(start,motion,air_faces_[i],air_faces_[i+1],air_faces_[i+2],t)&&t<first){first=t;valid=true;}}
    return valid?start+motion*first:aim;
}
AirMove Terrain::air_move(Vec3 from,Vec3 motion,float radius,float body_height,float center) const{
    AirMove result;result.position=from;if(!ready_)return result;
    const float skin=.001f,reach=radius+skin,stem=body_height*.5f-radius;
    Vec3 end=from+motion,pad{reach,reach,reach};Vec3 low{std::min(from.x,end.x),std::min(from.y,end.y),std::min(from.z,end.z)},high{std::max(from.x,end.x),std::max(from.y,end.y)+body_height,std::max(from.z,end.z)};
    auto candidates=air_candidates(low-pad,high+pad);
    auto separated=[&](int i,Vec3 start,Vec3 travel){
        const float margin=reach+.00001f;auto end=start+travel;
        auto lower=start+Vec3{0,center-stem,0},upper=start+Vec3{0,center+stem,0};
        auto last_lower=end+Vec3{0,center-stem,0},last_upper=end+Vec3{0,center+stem,0};
        Vec3 a{std::min(start.x,end.x)-margin,std::min({lower.y,upper.y,last_lower.y,last_upper.y})-margin,std::min(start.z,end.z)-margin};
        Vec3 b{std::max(start.x,end.x)+margin,std::max({lower.y,upper.y,last_lower.y,last_upper.y})+margin,std::max(start.z,end.z)+margin};
        auto low=air_minimum_[i/3],high=air_maximum_[i/3];
        return low.x>b.x||high.x<a.x||low.y>b.y||high.y<a.y||low.z>b.z||high.z<a.z;
    };
    // CharacterBody recovers a shallow initial overlap before its body sweep.
    for(int pass=0;pass<4;++pass){bool recovered=false;
        for(int i:candidates){if(separated(i,result.position,{}))continue;Vec3 normal,at=result.position;if(air_profile.enabled)++air_profile.capsule_tests;float distance=capsule_triangle(at+Vec3{0,center-stem,0},at+Vec3{0,center+stem,0},air_faces_[i],air_faces_[i+1],air_faces_[i+2],normal);
            if(distance<reach-.000005f){result.position=result.position+normal*(reach-distance);recovered=true;}}
        if(!recovered)break;
    }
    for(int slide=0;slide<5&&length(motion)>1e-7f;++slide){
        float earliest=1;Vec3 contact{};bool found=false;
        for(int i:candidates){
            if(separated(i,result.position,motion))continue;
            Vec3 a=air_faces_[i],b=air_faces_[i+1],c=air_faces_[i+2];float t=0;
            for(int iteration=0;iteration<48;++iteration){
                Vec3 at=result.position+motion*t,normal;if(air_profile.enabled)++air_profile.capsule_tests;float distance=capsule_triangle(at+Vec3{0,center-stem,0},at+Vec3{0,center+stem,0},a,b,c,normal);
                if(distance<=reach+.000005f){
                    if(dot(motion,normal)<-1e-7f&&t<=earliest){earliest=t;contact=normal;found=true;}break;
                }
                // Convex distance's supporting tangent bounds the next contact.
                // Using total speed converges too slowly for a shallow descent
                // and can exhaust the iteration budget before meeting a floor.
                float closing=-dot(motion,normal);if(closing<=1e-8f)break;
                float advance=(distance-reach)/closing;t+=std::max(advance,1e-7f);if(t>earliest||t>1)break;
            }
        }
        result.position=result.position+motion*earliest;
        if(!found)break;
        result.normal=contact;if(contact.y>=std::cos(48.0*M_PI/180)&&motion.y<0)result.floor=true;
        motion=motion*(1-earliest);motion=motion-contact*std::min(0.0f,dot(motion,contact));
    }
    return result;
}
Vec3 Terrain::direct_move(Vec3 from,Vec3 motion,float radius,int& layer) const{
    if(layer<0)layer=choose_layer(from);if(layer<0)return from;
    Vec3 end=from+motion;end.y=float(height(end.x,end.z,layer));
    if(segment(from,end,radius,layer))return end;
    float lo=0,hi=1;for(int i=0;i<18;++i){float t=(lo+hi)*.5f;Vec3 p=from+motion*t;p.y=float(height(p.x,p.z,layer));if(segment(from,p,radius,layer))lo=t;else hi=t;}
    end=from+motion*lo;end.y=float(height(end.x,end.z,layer));return finite(end)?end:from;
}
float Terrain::projectile_fraction(Vec3 from,Vec3 to,float width,int64_t ignore) const{
    if(!ready_||!finite(from)||!finite(to)||!std::isfinite(width)||width<0)return 0;
    Vec3 motion=to-from;if(length(motion)<.001f)return -1;
    Vec3 forward=normalized(motion),side=normalized(cross(forward,{0,1,0}));if(length(side)<.1f)side={1,0,0};Vec3 up=normalized(cross(side,forward));
    Vec3 half{width,std::min(width,.22f),.04f};float radius=length(half),first=2;
    Vec3 pad{radius,radius,radius},low{std::min(from.x,to.x),std::min(from.y,to.y),std::min(from.z,to.z)},high{std::max(from.x,to.x),std::max(from.y,to.y),std::max(from.z,to.z)};
    const Vec3 basis[]={side,up,forward};
    auto triangle=[&](Vec3 a,Vec3 b,Vec3 c){
        if(std::min({a.x,b.x,c.x})>high.x+radius||std::max({a.x,b.x,c.x})<low.x-radius||std::min({a.y,b.y,c.y})>high.y+radius||std::max({a.y,b.y,c.y})<low.y-radius||std::min({a.z,b.z,c.z})>high.z+radius||std::max({a.z,b.z,c.z})<low.z-radius)return;
        float enter=0,leave=std::min(1.0f,first);
        auto axis=[&](Vec3 n){
            if(dot(n,n)<1e-12f)return true;
            float size=std::abs(dot(n,side))*half.x+std::abs(dot(n,up))*half.y+std::abs(dot(n,forward))*half.z;
            float mn=std::min({dot(n,a),dot(n,b),dot(n,c)})-size,mx=std::max({dot(n,a),dot(n,b),dot(n,c)})+size,start=dot(n,from),speed=dot(n,motion);
            if(std::abs(speed)<1e-8f)return start>=mn-.000001f&&start<=mx+.000001f;
            float u=(mn-start)/speed,v=(mx-start)/speed;enter=std::max(enter,std::min(u,v));leave=std::min(leave,std::max(u,v));return enter<=leave+.000001f;
        };
        for(auto n:basis)if(!axis(n))return;
        Vec3 edges[]={b-a,c-b,a-c};if(!axis(cross(edges[0],edges[1])))return;
        for(auto edge:edges)for(auto n:basis)if(!axis(cross(edge,n)))return;
        first=std::min(first,std::max(0.0f,enter));
    };
    for(int i:air_candidates(low-pad,high+pad,true)){if(ignore>=0&&air_owner_[i/3]==ignore)continue;triangle(air_faces_[i],air_faces_[i+1],air_faces_[i+2]);}
    // Legacy fixture boxes are a fallback only. Actual scene faces are the
    // physical authority once exported; navigation footprints are not solids.
    if(data_.air_faces.empty()){
        const auto& mins=data_.ray_min.empty()?data_.obstacle_min:data_.ray_min;const auto& maxs=data_.ray_min.empty()?data_.obstacle_max:data_.ray_max;
        for(size_t i=0;i<mins.size()&&i<maxs.size();++i){
            if(ignore>=0&&i<data_.ray_owner.size()&&data_.ray_owner[i]==ignore)continue;
            Vec3 a=mins[i],b=maxs[i];if(a.x>high.x+radius||b.x<low.x-radius||a.y>high.y+radius||b.y<low.y-radius||a.z>high.z+radius||b.z<low.z-radius)continue;
            Vec3 v[]={{a.x,a.y,a.z},{a.x,a.y,b.z},{a.x,b.y,a.z},{a.x,b.y,b.z},{b.x,a.y,a.z},{b.x,a.y,b.z},{b.x,b.y,a.z},{b.x,b.y,b.z}};
            const int faces[][4]={{0,1,3,2},{4,6,7,5},{0,4,5,1},{2,3,7,6},{0,2,6,4},{1,5,7,3}};for(auto& f:faces){triangle(v[f[0]],v[f[1]],v[f[2]]);triangle(v[f[0]],v[f[2]],v[f[3]]);}
        }
    }
    return first<=1?first:-1;
}
}
