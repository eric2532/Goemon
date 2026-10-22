#include "core.h"
#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <thread>
#include <functional>

namespace army {
// Only plain simulation state is touched here. Godot objects, variants, physics
// queries, callbacks and presentation remain on the scene thread after finish.
class CrowdWorker {
    Crowd& crowd_;
    std::mutex mutex_;
    std::condition_variable ready_,done_;
    bool stopping_=false,pending_=false,working_=false;
    double delta_=0;
    std::thread thread_;
    void run(){
        std::unique_lock<std::mutex> lock(mutex_);
        for(;;){
            ready_.wait(lock,[&]{return stopping_||pending_;});
            if(stopping_)return;
            double delta=delta_;pending_=false;working_=true;
            lock.unlock();crowd_.step(delta);lock.lock();
            working_=false;done_.notify_all();
        }
    }
public:
    explicit CrowdWorker(Crowd& crowd):crowd_(crowd),thread_([this]{run();}){}
    void finish(){std::unique_lock<std::mutex> lock(mutex_);done_.wait(lock,[&]{return !pending_&&!working_;});}
    void begin(double delta){
        finish();{std::lock_guard<std::mutex> lock(mutex_);delta_=delta;pending_=true;}ready_.notify_one();
    }
    ~CrowdWorker(){
        finish();{std::lock_guard<std::mutex> lock(mutex_);stopping_=true;}ready_.notify_one();thread_.join();
    }
};
class MovementWorker {
    std::mutex mutex_;
    std::condition_variable ready_,done_;
    bool stopping_=false,pending_=false,working_=false;
    std::function<void()> job_;
    std::thread thread_;
    void run(){
        std::unique_lock<std::mutex> lock(mutex_);
        for(;;){
            ready_.wait(lock,[&]{return stopping_||pending_;});
            if(stopping_)return;
            auto job=std::move(job_);pending_=false;working_=true;
            lock.unlock();job();lock.lock();
            working_=false;done_.notify_all();
        }
    }
public:
    MovementWorker():thread_([this]{run();}){}
    void finish(){std::unique_lock<std::mutex> lock(mutex_);done_.wait(lock,[&]{return !pending_&&!working_;});}
    void begin(std::function<void()> job){
        finish();{std::lock_guard<std::mutex> lock(mutex_);job_=std::move(job);pending_=true;}ready_.notify_one();
    }
    ~MovementWorker(){
        finish();{std::lock_guard<std::mutex> lock(mutex_);stopping_=true;}ready_.notify_one();thread_.join();
    }
};
Crowd::Crowd()=default;
Crowd::~Crowd(){finish_step();worker_.reset();}
bool Crowd::begin_step(double delta){
    finish_step();if(!std::isfinite(delta)||delta<=0)return false;
    if(!worker_)worker_=std::make_unique<CrowdWorker>(*this);
    worker_->begin(delta);return true;
}
void Crowd::finish_step(){if(worker_)worker_->finish();}
namespace {
constexpr float CELL=8;
bool bounded(Vec3 p){return finite(p)&&std::abs(p.x)<1e8&&std::abs(p.y)<1e8&&std::abs(p.z)<1e8;}
uint64_t key(int x,int z){return (uint64_t(uint32_t(x))<<32)|uint32_t(z);}
int cell(float v){return int(std::floor(v/CELL));}
bool overlaps(const Unit& u,Vec3 a,Vec3 b){
    return u.position.x+u.radius>=a.x&&u.position.x-u.radius<=b.x&&
           u.position.y+u.radius>=a.y&&u.position.y-u.radius<=b.y&&
           u.position.z+u.radius>=a.z&&u.position.z-u.radius<=b.z;
}
}
void Crowd::configure(int capacity,int limit){
    clear();units_.assign(std::clamp(capacity,0,4000),{});
    visited_.assign(units_.size(),0);visit_=0;free_.clear();
    for(auto& marks:movement_visited_)marks.assign(units_.size(),0);movement_visit_={};
    for(size_t i=units_.size();i>0;--i)free_.push_back(uint32_t(i-1));
    team_limit_=std::clamp(limit,0,2000);
}
Handle Crowd::spawn(int64_t id,int team,int kind,Vec3 p,double hp,double radius){
    if(team<0||team>1||counts_[team]>=team_limit_||free_.empty()||ids_.count(id)||
       !bounded(p)||!std::isfinite(hp)||hp<=0||!std::isfinite(radius)||radius<0||radius>=1e7)return 0;
    uint32_t generation=generation_.take();if(!generation)return 0;
    uint32_t slot=free_.back();free_.pop_back();auto& u=units_[slot];u={};
    u.handle=Handle((uint64_t(generation)<<32)|slot);u.logical_id=id;u.team=team;u.kind=kind;
    u.position=p;u.hp=u.max_hp=hp;u.radius=float(radius);u.alive=true;
    combat.spawned(u);
    ids_[id]=slot;++counts_[team];dirty_=true;++pose_revision_;return u.handle;
}
bool Crowd::valid(Handle h) const{
    if(h<=0)return false;
    uint32_t slot=uint32_t(h);
    return slot<units_.size()&&units_[slot].alive&&units_[slot].handle==h;
}
Unit* Crowd::unit(Handle h){return valid(h)?&units_[uint32_t(h)]:nullptr;}
const Unit* Crowd::unit(Handle h) const{return valid(h)?&units_[uint32_t(h)]:nullptr;}
void Crowd::despawn(Handle h){
    // Grid candidates revalidate liveness. Removing a victim need not rebuild
    // the whole grid for every subsequent projectile in the same battle step.
    if(auto u=unit(h)){u->alive=false;--counts_[u->team];ids_.erase(u->logical_id);free_.push_back(uint32_t(h));}
}
void Crowd::set_pose(Handle h,Vec3 position,float yaw){if(auto u=unit(h);u&&bounded(position)&&std::isfinite(yaw)){u->position=position;u->yaw=yaw;u->support_layer=-1;dirty_=true;++pose_revision_;}}
void Crowd::clear(){
    combat.clear();
    for(auto& u:units_)u.alive=false;
    free_.clear();for(size_t i=units_.size();i>0;--i)free_.push_back(uint32_t(i-1));
    counts_={};ids_.clear();grid_.clear();overflow_.clear();dirty_=true;++pose_revision_;
}
std::vector<Unit> Crowd::snapshot() const{
    std::vector<Unit> result;result.reserve(ids_.size());
    for(const auto& u:units_)if(u.alive)result.push_back(u);
    return result;
}
void Crowd::rebuild_grid(){
    if(!dirty_)return;grid_.clear();overflow_.clear();
    for(uint32_t i=0;i<units_.size();++i){
        const auto& u=units_[i];if(!u.alive)continue;
        int x0=cell(u.position.x-u.radius),x1=cell(u.position.x+u.radius);
        int z0=cell(u.position.z-u.radius),z1=cell(u.position.z+u.radius);
        if(int64_t(x1-x0+1)*(z1-z0+1)>256){overflow_.push_back(i);continue;}
        for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z)grid_[key(x,z)].push_back(i);
    }
    dirty_=false;
}
std::vector<Handle> Crowd::query(Vec3 a,Vec3 b,int team,bool ordered){
    std::vector<Handle> result;
    if(!finite(a)||!finite(b)||a.x>b.x||a.y>b.y||a.z>b.z||team<0||team>1)return result;
    ++query_calls[team];
    auto add=[&](uint32_t i){
        const auto& u=units_[i];
        if(u.alive&&u.team==team){++query_candidates[team];if(overlaps(u,a,b))result.push_back(u.handle);}
    };
    // Only X/Z are converted into grid coordinates. A tall query must not
    // disable the spatial index merely because its finite Y interval is large.
    if(std::abs(a.x)>=1e8||std::abs(a.z)>=1e8||std::abs(b.x)>=1e8||std::abs(b.z)>=1e8||double(b.x-a.x+CELL)*double(b.z-a.z+CELL)>4096*CELL*CELL){
        for(uint32_t i=0;i<units_.size();++i)add(i);
    }else{
        rebuild_grid();if(++visit_==0){std::fill(visited_.begin(),visited_.end(),0);visit_=1;}
        auto once=[&](uint32_t i){if(visited_[i]!=visit_){visited_[i]=visit_;add(i);}};
        for(auto i:overflow_)once(i);
        for(int x=cell(a.x);x<=cell(b.x);++x)for(int z=cell(a.z);z<=cell(b.z);++z){
            auto it=grid_.find(key(x,z));if(it!=grid_.end())for(auto i:it->second)once(i);
        }
    }
    if(ordered){query_sorted_items[team]+=result.size();
        std::sort(result.begin(),result.end(),[&](Handle x,Handle y){return units_[uint32_t(x)].logical_id<units_[uint32_t(y)].logical_id;});
    }
    return result;
}
void Crowd::set_navigation(NavigationData data){
    NavigationData friendly=data;
    if(data.friendly_navigation){friendly.obstacle_min=std::move(friendly.friendly_obstacle_min);friendly.obstacle_max=std::move(friendly.friendly_obstacle_max);}
    allied_terrain.configure(std::move(friendly));
    terrain.configure(std::move(data));
    for(auto& u:units_){u.support_layer=-1;u.routing=false;}
}
void Crowd::rest_allies(){
    combat.clear();
    for(auto& u:units_)if(u.alive){
        if(u.team==0){despawn(u.handle);continue;}
        Unit old=std::move(u);u={};u.handle=old.handle;u.logical_id=old.logical_id;u.team=old.team;u.kind=old.kind;u.hp=old.hp;u.max_hp=old.max_hp;u.radius=old.radius;u.position=old.position;u.yaw=old.yaw;u.guard_post=old.guard_post;u.guard_radius=old.guard_radius;u.alive=true;if(old.shelter_mode==2){u.shelter_mode=2;u.shelter_id=old.shelter_id;u.shelter_exit=old.shelter_exit;}combat.spawned(u);
    }
    dirty_=true;++pose_revision_;
}
void Crowd::set_guard(Handle h,Vec3 point,float radius){if(auto u=unit(h);u&&bounded(point)&&std::isfinite(radius)&&radius>=0){u->guard_post=point;u->guard_radius=radius;u->think_left=0;}}
void Crowd::set_goal(Handle handle,Vec3 goal,float speed){
    auto u=unit(handle);if(!u||!bounded(goal)||!std::isfinite(speed)||speed<0)return;
    if(length(goal-u->goal)>3)u->routing=false;
    u->goal=goal;u->move_speed=speed;u->has_goal=true;
}
void Crowd::step(double delta){
    if(!std::isfinite(delta)||delta<=0)return;
    int steps=int(std::ceil(delta*60));double tick=delta/steps;float dt=float(tick);
    using Clock=std::chrono::steady_clock;
    auto started=timing.enabled?Clock::now():Clock::time_point{};auto previous=started;
    auto mark=[&](double& phase){if(timing.enabled){auto now=Clock::now();phase+=std::chrono::duration<double,std::milli>(now-previous).count();previous=now;}};
    std::vector<Vec3> next(units_.size());
    for(int step=0;step<steps;++step){
        rebuild_grid();mark(timing.grid);
        for(auto& u:units_)u.live_delta=tick;
        combat.before_move(*this,tick);mark(timing.decisions);
        auto move_team=[&](int team){
        auto& visited=movement_visited_[team<0?0:team];auto& visit=movement_visit_[team<0?0:team];
        const auto& spatial=grid_;
        for(uint32_t i=0;i<units_.size();++i){
            auto& u=units_[i];if(team>=0&&u.team!=team)continue;next[i]=u.position;
            if(!u.alive||u.live_delta<=0)continue;
            float live=float(u.live_delta);Terrain& ground=u.team==1?allied_terrain:terrain;
            if(combat.move_special(*this,u,live,next[i]))continue;
            if(length(u.knockback)>.1f){
                next[i]=ground.move(u.position,u.position+u.knockback*live,length(u.knockback),live,u.radius,u.support_layer,u.routing);
                u.knockback=u.knockback*std::exp(-8*live);continue;
            }
            Vec3 impulse=u.team==1?u.motion_impulse:Vec3{};
            if(u.team==1)u.motion_impulse=u.motion_impulse*std::exp(-12*live);
            if(u.stun>0||!u.has_goal||u.move_speed<=0){
                if(length(impulse)>.001f)next[i]=ground.move(u.position,u.position+impulse*live,length(impulse),live,u.radius,u.support_layer,u.routing);
                continue;
            }
            Vec3 avoidance{};int considered=0;
            if(++visit==0){std::fill(visited.begin(),visited.end(),0);visit=1;}
            for(int x=cell(u.position.x)-1;x<=cell(u.position.x)+1&&considered<12;++x)
                for(int z=cell(u.position.z)-1;z<=cell(u.position.z)+1&&considered<12;++z){
                    auto found=spatial.find(key(x,z));if(found==spatial.end())continue;
                    for(auto index:found->second){
                        if(index==i||visited[index]==visit)continue;visited[index]=visit;
                        const auto& other=units_[index];if(other.team!=u.team||std::abs(other.position.y-u.position.y)>2)continue;
                        Vec3 offset=u.position-other.position;offset.y=0;float distance=length(offset),reach=u.radius+other.radius;
                        if(distance>=reach||reach<=0)continue;
                        if(distance<.001f){
                            float angle=float((std::min(u.logical_id,other.logical_id)*2654435761ull)&1023)*.006135923f;
                            float sign=u.logical_id<other.logical_id?1.0f:-1.0f;
                            distance=.001f;offset={std::sin(angle)*distance*sign,0,std::cos(angle)*distance*sign};
                        }
                        avoidance=avoidance+offset*((reach-std::min(distance,reach))/std::max(.01f,reach*distance));
                        if(++considered>=12)break;
                    }
                }
            float strength=length(avoidance);if(strength>0)avoidance=avoidance*(std::min(strength,u.move_speed*.25f)/strength);
            if(length(impulse)>.001f){
                Vec3 toward=u.goal-u.position;toward.y=0;float gap=length(toward);Vec3 normal=normalized(toward)*std::min(u.move_speed*u.slow_factor,gap/std::max(.000001f,live));Vec3 combined=normal+impulse;
                next[i]=ground.move(u.position,u.position+combined*live,length(combined),live,u.radius,u.support_layer,u.routing,avoidance);
            }else next[i]=ground.move(u.position,u.goal,u.move_speed*u.slow_factor,live,u.radius,u.support_layer,u.routing,avoidance);
        }
        };
        // Movement reads pre-commit positions. Teams own separate mutable terrain
        // caches and deduplication scratch; all pose commits and attacks wait.
        if(parallel_movement_enabled&&counts_[0]>0&&counts_[1]>0&&ids_.size()>=256){
            if(!movement_worker_)movement_worker_=std::make_unique<MovementWorker>();
            movement_worker_->begin([&]{move_team(0);});move_team(1);movement_worker_->finish();
            if(timing.enabled)++timing.movement_jobs;
        }else move_team(-1);
        for(uint32_t i=0;i<units_.size();++i){auto& u=units_[i];if(!u.alive)continue;u.velocity=(next[i]-u.position)*(1/dt);u.position=next[i];}
        dirty_=true;++pose_revision_;mark(timing.movement);
        combat.after_move(*this,tick);mark(timing.combat);
        combat.animation_step(*this,tick);mark(timing.animation);
        if(timing.enabled)++timing.steps;
    }
    if(timing.enabled)timing.total+=std::chrono::duration<double,std::milli>(Clock::now()-started).count();
}
}
