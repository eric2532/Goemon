#include "combat.h"
#include "core.h"
#include <algorithm>

namespace army {
namespace {
float segment_distance(Vec3 a,Vec3 b,Vec3 c,Vec3 d){
    Vec3 u=b-a,v=d-c,w=a-c;float aa=dot(u,u),bb=dot(u,v),cc=dot(v,v),dd=dot(u,w),ee=dot(v,w),denom=aa*cc-bb*bb;
    float s=denom>1e-8f?std::clamp((bb*ee-cc*dd)/denom,0.0f,1.0f):0;
    float t=cc>1e-8f?std::clamp((bb*s+ee)/cc,0.0f,1.0f):0;
    if(aa>1e-8f)s=std::clamp((bb*t-dd)/aa,0.0f,1.0f);
    if(cc>1e-8f)t=std::clamp((bb*s+ee)/cc,0.0f,1.0f);
    return length(w+u*s-v*t);
}
bool body_contact(Vec3 from,Vec3 to,Vec3 foot,float radius){return segment_distance(from,to,foot+Vec3{0,.4f,0},foot+Vec3{0,1.8f,0})<radius;}
float horizontal(Vec3 a,Vec3 b){return std::hypot(a.x-b.x,a.z-b.z);}
}
bool Combat::configure(KitData data){
    enabled_=false;soldiers_={};allies_={};
    if(!valid_kit_data(data))return false;
    data_=std::move(data);
    for(size_t i=0;i<data_.soldier_kinds.size();++i){const float* row=data_.soldier_profiles.data()+i*6;soldiers_[data_.soldier_kinds[i]]={true,row[0],row[1],row[2],row[3],row[4],row[5]};}
    if(!data_.soldier_pose_meta.empty())for(size_t i=0;i<data_.soldier_kinds.size();++i)std::copy_n(data_.soldier_pose_meta.data()+i*16,16,soldiers_[data_.soldier_kinds[i]].poses.begin());
    for(size_t i=0;i<data_.ally_kinds.size();++i){auto& p=allies_[data_.ally_kinds[i]];const double* r=data_.ally_profiles.data()+i*5;p.active=true;p.hp=r[0];p.speed=r[1];p.damage=r[2];p.rate=r[3];p.critical=r[4];
        if(!data_.walk_cadence.empty())std::copy_n(data_.walk_cadence.data()+i*161,161,p.cadence.begin());
        for(int a=0;a<6;++a){const double* v=data_.ally_primaries.data()+i*42+a*7;p.primary[a]={v[0],v[1],v[2],v[3],v[4],v[5],v[6]};}}
    enabled_=true;return true;
}
void Combat::clear(){nearest_entries_.clear();nearest_nodes_.clear();nearest_revision_=UINT64_MAX;nearest_contact_tests_=0;nearest_position_reads_=0;projectiles_.clear();pulses_.clear();counters_.clear();threats_.clear();first_taunt_=latest_taunt_=0;events_.clear();targets_.clear();shelters_.clear();}
void Combat::spawned(Unit& u){if(enabled_&&u.team==1&&u.kind==8&&!data_.dragoon.empty())u.leap_left=data_.dragoon[D_LEAP_CD];if(enabled_&&u.shelter_mode==2)u.status|=data_.status_bits[6];pose_frame(u);}
void Combat::emit(Event event){event.serial=++serial_;events_.push_back(event);}
HitResult Combat::hit(Crowd& crowd,int64_t handle,const Hit& incoming){
    auto u=crowd.unit(handle);if(!u)return {};
    HitResult result{false,false,u->hp};
    if(u->shelter_mode==2)return result;
    if(!std::isfinite(incoming.amount)||incoming.amount<0||!std::isfinite(incoming.status_seconds)||incoming.status_seconds<0)return result;
    bool knight=u->team==1&&u->kind==7&&allies_[7].active;
    if(knight&&incoming.amount>0){
        if(u->invuln>0)return result;
        if(u->action_active&&u->action==data_.actions[8]){const auto& a=allies_[7].primary[u->combo_serial%6];if(u->action_time>=a.contact-std::min(.04,a.contact*.6)&&u->action_time<a.contact+std::min(.035,a.contact*.5))return result;}
        if(u->blocking&&(dot(incoming.direction,incoming.direction)<=.001f||dot(Vec3{std::sin(u->yaw),0,std::cos(u->yaw)},normalized(incoming.direction))<=0)){
            if(u->buff_left>0)u->riposte=true;
            knight_counter(*u);return result;
        }
    }
    if(finite(incoming.impulse)&&std::isfinite(incoming.flinch)&&incoming.flinch>=0&&(length(incoming.impulse)>0||incoming.flinch>0)){
        u->knockback=incoming.add_impulse?u->knockback+incoming.impulse:incoming.impulse;u->stun=std::max(u->stun,incoming.flinch);u->action_active=false;u->action=data_.actions.empty()?0:data_.actions[0];u->action_time=0;u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};result.accepted=true;
        if(u->air_phase){u->air_phase=4;u->landing_attack=false;u->invuln=0;}
    }
    if(incoming.status_seconds>0){
        if(incoming.effect==1){u->frozen=std::max(u->frozen,incoming.status_seconds);result.accepted=true;}
        if(incoming.effect==2&&std::isfinite(incoming.slow_factor)&&incoming.slow_factor>=0&&incoming.slow_factor<=1){u->slow_left=std::max(u->slow_left,incoming.status_seconds);u->slow_factor=std::min(u->slow_factor,incoming.slow_factor);result.accepted=true;}
    }
    refresh_status(*u);
    if(incoming.amount<=0||u->invuln>0||(u->kind==8&&u->team==1&&u->landing_attack&&u->action_active))return result;
    double amount=knight&&u->buff_left>0?std::round(incoming.amount*.5):incoming.amount;
    double damage=amount*(u->team==1?data_.damage_taken_multiplier:1);
    if(damage<=0)return result;
    result.accepted=true;u->flash_left=.115;u->hp-=damage;if(u->team==1)u->hp=std::max(0.0,u->hp);
    result.hp=u->hp;result.dead=u->hp<=0;
    Event event;event.kind=DAMAGE;event.source_id=incoming.source_id;event.target_id=u->logical_id;event.ticket_id=incoming.ticket_id;event.position=u->position+Vec3{0,1,0};event.amount=damage;event.hp=u->hp;event.projectile=incoming.projectile;event.heavy=incoming.heavy;event.unit_kind=u->kind;event.team=u->team;emit(event);
    if(result.dead){event.kind=DEATH;event.position=u->position;event.direction={std::sin(u->yaw),0,std::cos(u->yaw)};emit(event);crowd.despawn(handle);return result;}
    if(u->team==1){u->invuln=.35;if(knight)u->hit_pause=std::max(u->hit_pause,.045);}
    else{
        u->stun=16.0/30;u->action_active=false;u->action_time=0;u->has_goal=false;
        if(incoming.provoke){u->retaliation=4;u->retaliation_source=incoming.source_id;u->think_left=0;}
        u->knockback=normalized(Vec3{incoming.direction.x,0,incoming.direction.z})*(incoming.heavy?3.0f:1.2f);
    }
    refresh_status(*u);
    return result;
}
bool Combat::target(Crowd& crowd,const Unit& unit,Vec3& foot) const{
    if(unit.target_handle){auto other=crowd.unit(unit.target_handle);if(!other||other->hp<=0||other->shelter_mode==2)return false;foot=other->position;return true;}
    if(unit.external_kind<0)return false;
    for(const auto& other:targets_)if(other.id==unit.external_target&&other.kind==unit.external_kind&&other.hp>0&&other.targetable){foot=other.kind==2?Vec3{std::clamp(unit.position.x,other.minimum.x,other.maximum.x),other.minimum.y,std::clamp(unit.position.z,other.minimum.z,other.maximum.z)}:other.foot;return true;}
    return false;
}
bool Combat::melee_contact(Crowd& crowd,const Unit& unit) const{
    Vec3 foot;if(!target(crowd,unit,foot))return false;
    Vec3 from=unit.position+rotated_y(data_.melee_from,unit.yaw),to=unit.position+rotated_y(data_.melee_to,unit.yaw);
    if(!crowd.terrain.ray_clear(from,to,unit.external_kind==2?unit.external_target:-1))return false;
    if(unit.external_kind==2){
        for(const auto& other:targets_)if(other.id==unit.external_target&&other.kind==2){
            Vec3 p{std::clamp(to.x,other.minimum.x,other.maximum.x),std::clamp(to.y,other.minimum.y,other.maximum.y),std::clamp(to.z,other.minimum.z,other.maximum.z)};
            return segment_distance(from,to,p,p)<.18f;
        }
    }
    return body_contact(from,to,foot,.576f);
}
bool Combat::gun_contact(Crowd& crowd,const Unit& unit) const{
    Vec3 foot;if(!target(crowd,unit,foot))return false;
    Vec3 aim=foot+Vec3{0,1.3f,0};
    if(length(aim-unit.position)>soldiers_[unit.kind].range)return false;
    return crowd.terrain.ray_clear(unit.position+rotated_y(data_.muzzle,unit.yaw),aim,unit.external_kind==2?unit.external_target:-1);
}
// Bounds enclose every yaw of the original fitted soldier box. Enemy yaw can
// change during before_move, so the hierarchy indexes roots, never stale poses.
int Combat::build_nearest_node(Crowd& crowd,int first,int end){
    NearestNode node;node.first=first;node.count=end-first;
    node.low={INFINITY,INFINITY,INFINITY};node.high={-INFINITY,-INFINITY,-INFINITY};
    for(int i=first;i<end;++i){auto p=nearest_entries_[i].position;
        node.low={std::min(node.low.x,p.x),std::min(node.low.y,p.y),std::min(node.low.z,p.z)};
        node.high={std::max(node.high.x,p.x),std::max(node.high.y,p.y),std::max(node.high.z,p.z)};
    }
    node.magnitude=std::max({std::abs(double(node.low.x)),std::abs(double(node.low.y)),std::abs(double(node.low.z)),std::abs(double(node.high.x)),std::abs(double(node.high.y)),std::abs(double(node.high.z)),10.0});
    int index=int(nearest_nodes_.size());nearest_nodes_.push_back(node);
    if(end-first>8){
        auto span=node.high-node.low;int axis=span.x>=span.z?0:2;if(span.y>std::max(span.x,span.z))axis=1;
        auto coordinate=[&](const NearestEntry& entry){const auto& p=entry.position;return axis==0?p.x:(axis==1?p.y:p.z);};
        int middle=(first+end)/2;
        std::nth_element(nearest_entries_.begin()+first,nearest_entries_.begin()+middle,nearest_entries_.begin()+end,[&](const NearestEntry& a,const NearestEntry& b){return coordinate(a)<coordinate(b);});
        int left=build_nearest_node(crowd,first,middle),right=build_nearest_node(crowd,middle,end);
        nearest_nodes_[index].left=left;nearest_nodes_[index].right=right;
    }
    return index;
}
void Combat::rebuild_nearest(Crowd& crowd){
    nearest_entries_.clear();nearest_nodes_.clear();nearest_fallback_=false;
    for(const auto& u:crowd.units_)if(u.alive&&u.team==0){
        nearest_entries_.push_back({u.handle,u.position});++nearest_position_reads_;
        // Custom test/mod bodies smaller than their fitted box must retain the
        // old expanding query's eligibility instead of widening its semantics.
        if(u.radius<3.865f)nearest_fallback_=true;
    }
    if(!nearest_entries_.empty()&&!nearest_fallback_)build_nearest_node(crowd,0,int(nearest_entries_.size()));
    nearest_revision_=crowd.pose_revision_;
}
int64_t Combat::nearest_enemy(Crowd& crowd,Vec3 origin){
    if(crowd.counts_[0]==0)return 0;
    int64_t chosen=0;float best=INFINITY;
    if(nearest_revision_!=crowd.pose_revision_)rebuild_nearest(crowd);
    if(!nearest_fallback_){
        const double origin_magnitude=std::max({std::abs(double(origin.x)),std::abs(double(origin.y)),std::abs(double(origin.z))});
        auto lower=[&](const NearestNode& node){
            double dx=std::max({double(node.low.x)-origin.x,0.0,double(origin.x)-node.high.x});
            double dz=std::max({double(node.low.z)-origin.z,0.0,double(origin.z)-node.high.z});
            double dy=std::max({double(node.low.y)-origin.y,0.0,double(origin.y)-node.high.y-6.048});
            double magnitude=std::max(origin_magnitude,node.magnitude);
            // Conservative for float rotation, world addition and score rounding.
            double error=magnitude*64*1.1920928955078125e-7;
            double horizontal=std::max(0.0,std::hypot(dx,dz)-3.865-error);
            return std::max(0.0,std::hypot(horizontal,std::max(0.0,dy-error))-error);
        };
        auto visit=[&](auto&& self,int index,double bound)->void{
            const auto& node=nearest_nodes_[index];if(bound>best)return;
            if(node.left<0){
                for(int i=node.first;i<node.first+node.count;++i){auto other=crowd.unit(nearest_entries_[i].handle);if(!other)continue;
                    ++nearest_contact_tests_;float distance=length(enemy_contact(*other,origin+Vec3{0,1,0})-origin);
                    if(distance<best||(distance==best&&chosen&&other->logical_id<crowd.unit(chosen)->logical_id)){best=distance;chosen=other->handle;}
                }
            }else{
                int first=node.left,second=node.right;
                double first_bound=lower(nearest_nodes_[first]),second_bound=lower(nearest_nodes_[second]);
                if(second_bound<first_bound){std::swap(first,second);std::swap(first_bound,second_bound);}
                self(self,first,first_bound);self(self,second,second_bound);
            }
        };
        if(!nearest_nodes_.empty())visit(visit,0,lower(nearest_nodes_[0]));
        return chosen;
    }
    // Exponentially expand a conservative box; stop only when every unseen
    // fitted body is provably farther than the best exact contact.
    for(float radius=8;radius<=1e9f;radius*=2){
        Vec3 pad{radius,radius+7,radius};
        for(auto handle:crowd.query(origin-pad,origin+pad,0,false)){
            auto other=crowd.unit(handle);if(!other)continue;
            ++nearest_contact_tests_;float distance=length(enemy_contact(*other,origin+Vec3{0,1,0})-origin);
            if(distance<best||(distance==best&&chosen&&other->logical_id<crowd.unit(chosen)->logical_id)){best=distance;chosen=handle;}
        }
        if(best<=radius)return chosen;
    }
    return chosen;
}
void Combat::choose_target(Crowd& crowd,Unit& unit){
    unit.target_handle=0;unit.external_kind=-1;
    // Gate leaders are inserted before hired allies in the source defender map.
    for(const auto& other:targets_)if(other.hp>0&&other.targetable&&other.taunting){unit.external_target=other.id;unit.external_kind=other.kind;return;}
    if(auto taunt=crowd.unit(first_taunt_);taunt&&taunt->buff_left>0){unit.target_handle=taunt->handle;return;}
    const ExternalTarget* hero=nullptr;
    for(const auto& other:targets_)if(other.kind==0&&other.hp>0&&other.targetable){hero=&other;break;}
    if(unit.retaliation>0){
        auto found=crowd.ids_.find(unit.retaliation_source);
        if(found!=crowd.ids_.end()){
            auto& other=crowd.units_[found->second];
            if(other.alive&&other.team==1&&other.shelter_mode!=2&&horizontal(other.position,unit.position)<28){unit.target_handle=other.handle;return;}
        }
        for(const auto& other:targets_)if(other.kind==3&&other.id==unit.retaliation_source&&other.hp>0&&other.targetable&&horizontal(other.foot,unit.position)<28){unit.external_target=other.id;unit.external_kind=other.kind;return;}
        if(hero&&horizontal(hero->foot,unit.position)<=28){unit.external_target=hero->id;unit.external_kind=0;return;}
    }
    float score=INFINITY;
    // Original order: building edge, worker, gate defender, paid ally, hero fallback.
    for(int kind:{2,1,3})for(const auto& other:targets_){
        if(other.kind!=kind||other.hp<=0||!other.targetable)continue;
        Vec3 point=kind==2?Vec3{std::clamp(unit.position.x,other.minimum.x,other.maximum.x),other.minimum.y,std::clamp(unit.position.z,other.minimum.z,other.maximum.z)}:other.foot;
        float distance=horizontal(unit.position,point);
        if(distance<score){score=distance;unit.external_target=other.id;unit.external_kind=kind;}
    }
    if(crowd.counts_[1]>0){
        float extent=std::isfinite(score)?score:3e8f;
        // Prove the nearest root locally before considering farther cells. The
        // source score is horizontal: tall tower/deck positions remain eligible.
        for(float radius=std::min(8.0f,extent);;radius=std::min(radius*2,extent)){
            Vec3 pad{radius,3e8f,radius};
            for(auto handle:crowd.query(unit.position-pad,unit.position+pad,1,false)){
                auto other=crowd.unit(handle);if(!other||other->shelter_mode==2)continue;
                float distance=horizontal(unit.position,other->position);
                if(distance<score||(distance==score&&unit.target_handle&&other->logical_id<crowd.unit(unit.target_handle)->logical_id)){
                    score=distance;unit.target_handle=handle;unit.external_kind=-1;
                }
            }
            if(score<=radius||radius>=extent)break;
        }
    }
    if(!unit.target_handle&&unit.external_kind<0&&hero){unit.external_target=hero->id;unit.external_kind=0;}
}
void Combat::begin(Unit& unit){
    unit.action_active=true;unit.just_started=true;unit.phase_tick=0;unit.attack_tick=0;unit.action_time=0;unit.soldier_shots=0;
    unit.soldier_phase=unit.kind==1?FIRE:MELEE_A;unit.action=data_.actions[unit.soldier_phase+1];unit.has_goal=false;
}
void Combat::before_move(Crowd& crowd,double delta){
    if(!enabled_)return;
    threats_.clear();first_taunt_=0;latest_taunt_=0;
    for(const auto& u:crowd.units_)if(u.alive){
        if(u.team==0&&u.action_active&&u.target_handle)threats_.insert(u.target_handle);
        if(u.team==1&&u.kind==7&&u.buff_left>0&&u.shelter_mode==0&&(!first_taunt_||u.handle<first_taunt_))first_taunt_=u.handle;
    }
    for(auto& u:crowd.units_){
        if(!u.alive)continue;
        double frozen=u.frozen;u.frozen=std::max(0.0,u.frozen-delta);u.live_delta=std::max(0.0,delta-frozen);
        double dt=u.live_delta;u.retaliation=std::max(0.0,u.retaliation-dt);u.invuln=std::max(0.0,u.invuln-dt);u.stun=std::max(0.0,u.stun-dt);u.slow_left=std::max(0.0,u.slow_left-dt);
        if(u.slow_left<=0)u.slow_factor=1;
        u.status=(u.frozen>0?data_.status_bits[0]:0)|(u.slow_left>0?data_.status_bits[1]:0)|(u.stun>0?data_.status_bits[2]:0)|(u.invuln>0?data_.status_bits[3]:0);
        if(u.team==1&&u.kind>=0&&u.kind<19&&allies_[u.kind].active){if(!shelter(crowd,u,dt))ally_decide(crowd,u,dt);continue;}
        if(u.team!=0||u.kind<0||u.kind>=19||!soldiers_[u.kind].active||dt<=0)continue;
        if(u.stun>0){u.action=data_.actions[6];continue;}
        if(u.action_active){u.has_goal=false;continue;}
        u.action=data_.actions[0];u.think_left-=dt;
        Vec3 foot;
        if(u.think_left<=0||!target(crowd,u,foot)){choose_target(crowd,u);u.think_left=.1;}
        if(!target(crowd,u,foot)){u.has_goal=false;continue;}
        const auto& profile=soldiers_[u.kind];Vec3 direction=foot-u.position;
        float desired=std::atan2(-direction.x,-direction.z),turn=std::remainder(desired-u.yaw,float(2*M_PI));
        float amount=profile.turn_speed*float(dt);u.yaw+=std::clamp(turn,-amount,amount);
        bool facing=std::abs(std::remainder(desired-u.yaw,float(2*M_PI)))<.35f;
        bool reach=u.kind==1?gun_contact(crowd,u):horizontal(u.position,foot)<=profile.range&&std::abs(foot.y-u.position.y)<=3.5f&&melee_contact(crowd,u);
        if(facing&&reach){begin(u);continue;}
        crowd.set_goal(u.handle,foot,profile.speed);
    }
    // Multiple Codes in one frame coalesce to one retarget pass. A later Code
    // wins immediately; ordinary reacquisition still picks the oldest taunter.
    if(latest_taunt_)for(auto& u:crowd.units_)if(u.alive&&u.team==0&&u.kind>=0&&u.kind<19&&soldiers_[u.kind].active){u.target_handle=latest_taunt_;u.external_kind=-1;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.has_goal=false;u.routing=false;u.think_left=.1;}
}
void Combat::deliver(Crowd& crowd,const Unit& unit,double amount,bool projectile,Vec3 origin){
    if(unit.target_handle){Vec3 foot;target(crowd,unit,foot);Hit hit;hit.source_id=unit.logical_id;hit.amount=amount;hit.projectile=projectile;hit.direction=normalized(foot-origin);this->hit(crowd,unit.target_handle,hit);}
    else{
        Event event;event.kind=EXTERNAL_DAMAGE;event.source_id=unit.logical_id;event.target_id=unit.external_target;event.external_kind=unit.external_kind;event.position=origin;event.amount=amount;event.projectile=projectile;emit(event);
    }
}
void Combat::advance(Crowd& crowd,Unit& u,double delta){
    if(u.just_started){u.just_started=false;return;}
    double remaining=delta*30;
    while(u.action_active&&remaining>1e-9){
        int phase=u.soldier_phase;double duration=data_.phase_ticks[phase],before=u.phase_tick;
        double step=std::min(remaining,std::max(0.0,duration-before)),after=before+step,start=u.attack_tick-before;
        auto marker=[&](double tick,EventKind kind){
            if(!(before+1e-8<tick&&after+1e-8>=tick))return;
            Event event;event.kind=kind;event.source_id=u.logical_id;event.source_tick=start+tick;event.target_id=u.target_handle?crowd.unit(u.target_handle)?crowd.unit(u.target_handle)->logical_id:0:u.external_target;event.position=u.position;event.unit_kind=u.kind;
            if(kind==MELEE){emit(event);if(melee_contact(crowd,u))deliver(crowd,u,soldiers_[u.kind].damage,false,u.position);}
            else{
                event.position=u.position+rotated_y(data_.muzzle,u.yaw);
                if(kind==MUZZLE){emit(event);return;}
                if(!gun_contact(crowd,u))return;
                Vec3 foot;target(crowd,u,foot);Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=u.kind;shot.position=event.position;shot.direction=normalized(foot+Vec3{0,1.3f,0}-shot.position);shot.life=data_.bullet_life;shot.speed=data_.bullet_speed;shot.tail=data_.bullet_tail;shot.radius=data_.bullet_radius;shot.damage=soldiers_[u.kind].damage;shot.source_team=0;shot.target_kind=u.external_kind;shot.target_id=u.external_target;
                for(const auto& ext:targets_)if(ext.id==u.external_target&&ext.kind==u.external_kind){shot.ignore_building=ext.ignore_building;break;}
                projectiles_.push_back(shot);event.projectile_id=shot.id;event.direction=shot.direction;event.amount=shot.damage;emit(event);
            }
        };
        if(phase==MELEE_A)marker(data_.contact_ticks[0],MELEE);
        else if(phase==MELEE_B)marker(data_.contact_ticks[1],MELEE);
        else if(phase==FIRE){marker(data_.contact_ticks[2],MUZZLE);marker(data_.contact_ticks[3],BULLET);}
        u.phase_tick=after;u.attack_tick+=step;u.action_time=u.phase_tick/30;remaining-=step;
        if(after+1e-8<duration)break;
        if(phase==MELEE_A&&u.kind==0&&melee_contact(crowd,u))u.soldier_phase=PREPARE;
        else if(phase==PREPARE)u.soldier_phase=MELEE_B;
        else if(phase==FIRE)u.soldier_phase=++u.soldier_shots<3?FIRE:RELOAD;
        else{
            u.action_active=false;u.action=data_.actions[0];u.action_time=0;
            Event event;event.kind=DONE;event.source_id=u.logical_id;event.source_tick=u.attack_tick;event.position=u.position;emit(event);break;
        }
        u.phase_tick=0;u.action=data_.actions[u.soldier_phase+1];
    }
}
void Combat::projectiles(Crowd& crowd,double delta,size_t start){
    size_t count=start;
    for(size_t index=start;index<projectiles_.size();++index){auto shot=projectiles_[index];
        if(shot.life<=0){Event event;event.kind=PROJECTILE_IMPACT;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=shot.source_team;event.unit_kind=shot.owner_kind;emit(event);continue;}
        float elapsed=float(std::min(delta,std::max(0.0,shot.life-shot.age)));
        Vec3 before=shot.position;shot.age+=elapsed;
        if(shot.ranger){shot.distance=std::min(shot.range,shot.distance+shot.speed*elapsed);shot.position=shot.origin+shot.direction*shot.distance;if(shot.curved&&shot.range>.001f)shot.position=shot.position+shot.curve*std::sin(float(M_PI)*shot.distance/shot.range);}
        else shot.position=shot.position+shot.direction*(shot.speed*elapsed);
        shot.flight_direction=normalized(shot.position-before);
        if(shot.source_team==1){
            float world=crowd.terrain.projectile_fraction(before,shot.position,shot.radius);bool impacted=world>=0;
            if(impacted)shot.position=before+(shot.position-before)*world;
            {
                Vec3 pad{shot.radius+4,shot.radius+7,shot.radius+4},low{std::min(before.x,shot.position.x),std::min(before.y,shot.position.y),std::min(before.z,shot.position.z)},high{std::max(before.x,shot.position.x),std::max(before.y,shot.position.y),std::max(before.z,shot.position.z)};
                Handle chosen=0;float nearest=2;
                for(auto h:crowd.query(low-pad,high+pad,0)){auto e=crowd.unit(h);if(!e)continue;float t=enemy_segment(*e,before,shot.position,shot.radius);if(t>=0&&t<nearest){nearest=t;chosen=h;}}
                if(chosen){
                    Hit hit;hit.source_id=shot.source_id;hit.amount=shot.damage;hit.projectile=true;hit.direction=shot.direction;hit.heavy=shot.heavy;
                    if(shot.cast){auto& c=*shot.cast;c.rng^=c.rng>>12;c.rng^=c.rng<<25;c.rng^=c.rng>>27;if(double((c.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<c.critical)hit.amount*=2;}
                    if(this->hit(crowd,chosen,hit).accepted&&shot.cast){if(auto owner=crowd.unit(shot.cast->owner)){owner->chain_left=1.75;if(!shot.cast->confirmed){shot.cast->confirmed=true;++owner->chain_count;}}}
                    shot.position=before+(shot.position-before)*nearest;impacted=true;
                }
            }
            if(impacted||shot.age>=shot.life){Event event;event.kind=PROJECTILE_IMPACT;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=1;event.unit_kind=shot.owner_kind;emit(event);}else projectiles_[count++]=shot;
            continue;
        }
        bool impacted=!crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.ignore_building);
        auto external_hit=[&](const ExternalTarget& victim){Event event;event.kind=EXTERNAL_DAMAGE;event.source_id=shot.source_id;event.target_id=victim.id;event.external_kind=victim.kind;event.position=before;event.amount=shot.damage;event.projectile=true;event.direction=shot.direction;emit(event);};
        if(impacted&&shot.target_kind==2&&crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.target_id))
            for(const auto& victim:targets_)if(victim.kind==2&&victim.id==shot.target_id&&victim.hp>0){external_hit(victim);break;}
        Vec3 tail=shot.position-shot.direction*shot.tail;
        if(!impacted)for(const auto& victim:targets_)if(victim.kind==0&&victim.hp>0&&victim.targetable&&body_contact(tail,shot.position,victim.foot,shot.radius)){external_hit(victim);impacted=true;break;}
        if(!impacted){
            Vec3 pad{shot.radius,shot.radius,shot.radius};Vec3 low{std::min(tail.x,shot.position.x),std::min(tail.y,shot.position.y)-1.8f,std::min(tail.z,shot.position.z)},high{std::max(tail.x,shot.position.x),std::max(tail.y,shot.position.y),std::max(tail.z,shot.position.z)};
            for(auto handle:crowd.query(low-pad,high+pad,1)){
                auto victim=crowd.unit(handle);if(!victim||!body_contact(tail,shot.position,victim->position,shot.radius))continue;
                Hit damage;damage.amount=shot.damage;damage.source_id=shot.source_id;damage.projectile=true;damage.direction=shot.direction;hit(crowd,handle,damage);impacted=true;break;
            }
        }
        if(!impacted)for(const auto& victim:targets_){
            if(victim.hp<=0||!victim.targetable||victim.kind==0)continue;
            bool contact=victim.kind==2?shot.target_kind==2&&shot.target_id==victim.id&&length(shot.position-Vec3{std::clamp(shot.position.x,victim.minimum.x,victim.maximum.x),std::clamp(shot.position.y,victim.minimum.y,victim.maximum.y),std::clamp(shot.position.z,victim.minimum.z,victim.maximum.z)})<.35f:body_contact(tail,shot.position,victim.foot,shot.radius);
            if(contact){external_hit(victim);impacted=true;break;}
        }
        if(impacted||shot.age>=shot.life){Event event;event.kind=PROJECTILE_IMPACT;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;emit(event);}
        else projectiles_[count++]=shot;
    }
    projectiles_.resize(count);
}
void Combat::after_move(Crowd& crowd,double delta){
    if(!enabled_)return;
    pulses(crowd,delta);
    for(auto& u:crowd.units_)if(u.alive&&u.team==0&&u.live_delta>0&&u.stun<=0&&u.action_active)advance(crowd,u,u.live_delta);
    projectiles(crowd,delta);
    counters(crowd,delta);
    size_t newborn_start=projectiles_.size();
    for(auto& u:crowd.units_)if(u.alive&&u.team==1&&u.kind>=0&&u.kind<19&&allies_[u.kind].active&&u.live_delta>0&&u.stun<=0&&(u.shelter_mode==0||u.shelter_mode==4)){
        if(u.shelter_mode==4){if(u.just_landed){u.just_landed=false;if(u.landing_attack)dragoon_land(crowd,u);}continue;}
        if(u.kind==8&&u.just_landed){u.just_landed=false;if(u.landing_attack)dragoon_land(crowd,u);}
        else if(u.kind==8&&u.air_phase)continue;
        else if(u.kind==8&&u.action_active&&u.action==data_.actions[16])dragoon_advance(crowd,u,u.live_delta);
        else if(u.action_active&&u.action==data_.actions[9])ninja_resolve(crowd,u);
        else if(u.action_active&&u.action==data_.actions[8])ally_advance(crowd,u,u.live_delta);
        if(!u.action_active)ally_start(crowd,u);
    }
    // Source bow releases advance in the same tick as their contact marker.
    // Existing shots have already advanced; only visit the appended suffix.
    if(projectiles_.size()>newborn_start)projectiles(crowd,delta,newborn_start);
}
}

namespace army {
Vec3 Combat::enemy_contact(const Unit& victim,Vec3 from) const{
    Vec3 local=rotated_y(from-victim.position,-victim.yaw);
    local.x=std::clamp(local.x,-1.728f,1.728f);local.y=std::clamp(local.y,0.0f,6.048f);local.z=std::clamp(local.z,-3.456f,3.456f);
    return victim.position+rotated_y(local,victim.yaw);
}
void Combat::ally_decide(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    if(u.hit_pause>0){u.hit_pause=std::max(0.0,u.hit_pause-dt);u.live_delta=0;return;}
    if(!u.action_active||!u.cast_confirmed)u.chain_left=std::max(0.0,u.chain_left-dt);
    if(u.chain_left<=0)u.chain_count=0;
    if(u.guard_radius>0&&!u.appearance_started){
        u.think_left-=dt;u.has_goal=false;u.action=data_.actions[0];
        if(u.think_left>0)return;
        u.think_left=.2;
        if(auto handle=nearest_enemy(crowd,u.position)){u.target_handle=handle;u.appearance_started=true;u.appearance_left=.08;u.age=0;u.think_left=0;if(u.kind==8)u.position.y+=12;}
        if(!u.appearance_started)return;
    }
    if(u.appearance_left>0){u.appearance_left=std::max(0.0,u.appearance_left-dt);if(u.appearance_left>0)return;}
    u.frame_chain=u.chain_count;u.frame_tempo=ally_tempo(u);
    u.combo_left=std::max(0.0,u.combo_left-dt);
    u.age+=dt;u.skill_left=std::max(0.0,u.skill_left-dt*(u.kind==10?ally_tempo(u):1));u.utility_left=std::max(0.0,u.utility_left-dt);u.utility_wait=std::max(0.0,u.utility_wait-dt);u.roll_left=std::max(0.0,u.roll_left-dt);u.buff_left=std::max(0.0,u.buff_left-dt);
    u.shot_left=std::max(0.0,u.shot_left-dt);u.recovery_left=std::max(0.0,u.recovery_left-dt);u.landing_left=std::max(0.0,u.landing_left-dt);
    if(u.kind==7&&!u.knight_opened){u.knight_opened=true;u.opening=false;knight_code(u,dt);}
    if(u.kind==10){u.opening=false;if(!u.action_active){u.action=data_.actions[u.utility_wait>0?12:0];u.action_time=u.utility_wait>0?.2-u.utility_wait:0;}}
    u.leap_left=std::max(0.0,u.leap_left-dt);
    if(u.kind==8&&u.air_phase){
        u.has_goal=false;
        if(!u.opening){u.think_left-=dt;if(u.think_left<=0)u.think_left=.2;}
        if(u.air_phase==3&&u.special_time>0){if(u.velocity.y>0){auto e=crowd.unit(u.target_handle);dragoon_begin(crowd,u,e?enemy_contact(*e,u.position+Vec3{0,1,0}):u.landing_goal);}else u.air_phase=4;}
        return;
    }
    if(u.kind==8&&u.dragoon_opened&&u.opening&&u.age>.85&&!std::any_of(pulses_.begin(),pulses_.end(),[&](const LandingPulse& p){return p.cast->owner==u.handle;})){u.opening=false;u.think_left=0;}
    if(u.kind==5&&u.action_active&&u.action==data_.actions[9]){u.has_goal=false;return;}
    if(u.kind==5&&u.ninja_opened&&u.age>.15&&u.opening){u.opening=false;u.think_left=0;}
    if(u.stun>0){u.action_active=false;u.blocking=false;u.has_goal=false;u.action=data_.actions[6];return;}
    const auto& profile=allies_[u.kind];
    const auto& motion_attack=profile.primary[u.combo_serial%6];double motion_tempo=ally_tempo(u);
    bool planted=u.kind!=10&&u.action_active&&u.action==data_.actions[8]&&u.action_time+dt*motion_tempo>=std::max(0.0,motion_attack.contact-.010)&&u.action_time<std::min(motion_attack.duration*.8,motion_attack.contact+.060);
    if(planted)u.motion_impulse={};
    else if(u.pending_drift>0){u.motion_impulse=u.motion_impulse+Vec3{std::sin(u.yaw),0,std::cos(u.yaw)}*float(u.pending_drift);u.pending_drift=0;}
    auto other=crowd.unit(u.target_handle);u.think_left-=dt;
    bool decision=!other||other->hp<=0||u.think_left<=0;
    if(decision){
        u.think_left=.2;u.target_handle=0;
        if(u.guard_radius>0)u.target_handle=nearest_enemy(crowd,u.position);
        else{
            float best=48*48;Vec3 pad{52,60,52};
            for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
                auto enemy=crowd.unit(h);if(!enemy)continue;Vec3 point=enemy_contact(*enemy,u.position+Vec3{0,1,0});float gap=dot(point-u.position,point-u.position);
                if(gap<best){best=gap;u.target_handle=h;}
            }
        }
        other=crowd.unit(u.target_handle);
    }
    if(!other){u.has_goal=false;if(u.guard_radius>0&&horizontal(u.position,u.guard_post)>.65f)crowd.set_goal(u.handle,u.guard_post,float(profile.speed));u.blocking=false;if(!u.action_active)u.action=data_.actions[0];return;}
    if(u.kind==8&&!u.dragoon_opened){
        u.dragoon_opened=true;
        bool valid=false;Vec3 floor=crowd.allied_terrain.landing(u.position,u.position.y+2,valid);
        if(!valid||u.position.y-floor.y>.3f){dragoon_begin(crowd,u,enemy_contact(*other,u.position+Vec3{0,1,0}));u.has_goal=false;return;}
        u.opening=false;
    }
    if(u.kind==5&&!u.ninja_opened&&!data_.ninja.empty()){
        ninja_begin(u,enemy_contact(*other,u.position+Vec3{0,1,0}));u.ninja_opened=true;u.has_goal=false;return;
    }
    Vec3 point=enemy_contact(*other,u.position+Vec3{0,1,0}),offset=point-u.position;offset.y=0;float gap=length(offset);
    const auto& next=profile.primary[u.combo_serial%6];double reach=next.reach*.72;
    if(!u.action_active||u.kind==10)u.yaw=std::atan2(offset.x,offset.z);
    if(u.kind==7){
        if(decision){
            bool guard=gap<8&&threats_.count(u.handle);u.suppress_primary=guard;
            if(guard){u.action_active=false;u.action_time=0;u.motion_impulse={};u.hit_pause=0;u.action=data_.actions[13];u.blocking=true;u.yaw=std::atan2(offset.x,offset.z);}
            else {u.blocking=false;if(!u.action_active){u.action=data_.actions[0];if(u.utility_left<=0&&u.buff_left<=0&&gap<22)knight_code(u,dt);}else if(u.utility_left<=0&&u.buff_left<=0&&gap<22)u.suppress_primary=true;}
        }
        if(u.blocking){Vec3 goal=u.position+normalized(offset)*float(std::max(0.0,double(gap)-reach*.7));crowd.set_goal(u.handle,goal,float(profile.speed*.58));if(horizontal(u.position,goal)<.65f)u.has_goal=false;return;}
    }
    if(u.kind==5&&!u.opening&&decision){
        bool utility=u.utility_left<=0&&u.buff_left<=0&&gap<22,secondary=u.skill_left<=0&&gap>4&&gap<12;
        u.suppress_primary=utility||secondary;
        if(!u.action_active){
            if(utility){u.buff_left=data_.ninja[9];u.utility_left=data_.ninja[8];}
            if(secondary){ninja_begin(u,point);u.has_goal=false;return;}
            if(u.roll_left<=0&&gap>5&&gap<25)ninja_stars(crowd,u,point);
        }
    }
    if(u.kind==8&&!u.opening&&decision){
        bool utility=u.utility_left<=0&&u.buff_left<=0&&gap<22,secondary=u.skill_left<=0&&gap<7,jump=u.skill_left<=0&&u.leap_left<=0&&gap>7&&gap<24;
        u.suppress_primary=utility||secondary||jump;
        if(!u.action_active){
            if(jump){u.air_phase=3;u.special_time=0;u.velocity.y=float(data_.dragoon[D_JUMP]);u.landing_goal=point;u.leap_left=data_.dragoon[D_LEAP_CD];u.has_goal=false;return;}
            if(utility){u.buff_left=data_.dragoon[D_BUFF_TIME];u.utility_left=data_.dragoon[D_BUFF_CD];u.skill_left=0;u.roll_left=0;}
            if(gap<7&&u.skill_left<=0){dragoon_sweep(u);u.has_goal=false;return;}
        }
    }
    if(u.kind==10){
        const auto& d=data_.ranger;
        if(decision){
            bool utility=u.utility_left<=0&&u.buff_left<=0&&gap<22,secondary=u.skill_left<=0&&gap<25;u.suppress_primary=utility||secondary;
            if(!u.action_active){
                if(utility){u.buff_left=std::max(0.0,d[R_BUFF_TIME]-dt);u.utility_left=std::max(0.0,d[R_BUFF_CD]-dt);u.skill_left=0;}
                if(u.skill_left<=0&&gap<25)ranger_fire(crowd,u,point,true);
            }
        }
        Vec3 goal=u.position;if(gap>d[R_FAR])goal=goal+normalized(offset)*float(gap-d[R_STANDOFF]);else if(gap<d[R_NEAR])goal=goal-normalized(offset)*float(d[R_RETREAT]);
        crowd.set_goal(u.handle,goal,float(profile.speed));if(horizontal(u.position,goal)<.65f)u.has_goal=false;return;
    }
    Vec3 goal=u.position+normalized(offset)*float(std::max(0.0,double(gap)-reach*.7));
    crowd.set_goal(u.handle,goal,float(profile.speed));
    if(horizontal(u.position,goal)<.65f)u.has_goal=false;
    if(u.action_active){
        const auto& attack=profile.primary[u.combo_serial%6];double tempo=ally_tempo(u);
        bool planted=u.action_time+dt*tempo>=std::max(0.0,attack.contact-.010)&&u.action_time<std::min(attack.duration*.8,attack.contact+.060);
        if(planted){u.motion_impulse={};u.has_goal=false;}
    }
}
void Combat::ally_start(Crowd& crowd,Unit& u){
    auto other=crowd.unit(u.target_handle);if(!other||u.action_active||u.stun>0||u.air_phase||((u.kind==5||u.kind==7||u.kind==8||u.kind==10)&&(u.opening||u.suppress_primary)))return;
    const auto& profile=allies_[u.kind];const auto& next=profile.primary[u.combo_serial%6];Vec3 point=enemy_contact(*other,u.position+Vec3{0,1,0});
    double reach=u.kind==10?data_.ranger[R_PRIMARY_REACH]:next.reach*.72,height=u.kind==10?data_.ranger[R_HEIGHT]:3.5;
    if(horizontal(u.position,point)>reach+.8||std::abs(point.y-u.position.y-1.3f)>=height)return;
        if(u.combo_left<=0)u.combo_serial=0;
        const auto& attack=profile.primary[u.combo_serial%6];
        u.action=data_.actions[8];u.action_active=true;u.action_time=0;u.primary_hit=false;u.cast_confirmed=false;u.combo_left=1.05;
        u.attack_damage=attack.damage*profile.damage*std::min(1.5,1.0+.05*(u.kind==10?u.frame_chain:u.chain_count));
        u.riposte_attack=u.kind==7&&u.riposte;if(u.riposte_attack){u.attack_damage=std::round(attack.damage*data_.knight[K_RIPOSTE])*profile.damage*std::min(1.5,1.0+.05*u.chain_count);u.riposte=false;}
        if(u.kind==10)u.ranger_power=u.ranger_shots%3==2;
        Vec3 forward{std::sin(u.yaw),0,std::cos(u.yaw)},side{std::cos(u.yaw),0,-std::sin(u.yaw)};
        if(u.kind==11){u.motion_impulse=u.motion_impulse+side*float(3.8*attack.side)+forward*.8f;u.invuln=std::max(u.invuln,.14);}
}
bool Combat::ally_primary(Crowd& crowd,Unit& u){
    const auto& profile=allies_[u.kind];const auto& attack=profile.primary[u.combo_serial%6];
    Event event;event.kind=MELEE;event.source_id=u.logical_id;event.unit_kind=u.kind;event.team=1;event.action_index=u.combo_serial%3;event.source_tick=attack.contact*30;event.amount=u.riposte_attack?std::round(attack.damage*data_.knight[K_RIPOSTE]):attack.damage;event.position=u.position;emit(event);
    float reach=float(attack.reach);Vec3 pad{reach+4,12,reach+4};bool connected=false;
    for(auto handle:crowd.query(u.position-pad,u.position+pad,0)){
        auto enemy=crowd.unit(handle);if(!enemy)continue;Vec3 point=enemy_contact(*enemy,u.position+Vec3{0,1,0}),offset=point-u.position;
        if(std::abs(offset.y)>3.5f||std::hypot(offset.x,offset.z)>reach||std::abs(std::remainder(std::atan2(offset.x,offset.z)-u.yaw,float(2*M_PI)))>attack.arc)continue;
        if(!crowd.terrain.ray_clear(u.position+Vec3{0,1,0},point))continue;
        Hit hit;hit.source_id=u.logical_id;hit.amount=u.attack_damage;hit.heavy=u.combo_serial%3==2;hit.direction={std::sin(u.yaw),0,std::cos(u.yaw)};
        if(u.kind==5&&u.buff_left>0&&random(u)<data_.ninja[11]){
            double raw=enemy->kind==4?attack.damage+45:std::max(attack.damage,enemy->hp);
            hit.amount=raw*(u.attack_damage/attack.damage);
        }
        if(random(u)*100<profile.critical)hit.amount*=2;
        if(this->hit(crowd,handle,hit).accepted){connected=true;if(!u.cast_confirmed){u.cast_confirmed=true;++u.chain_count;}u.chain_left=1.75;}
    }
    if(connected&&u.kind==5)u.pending_drift=u.combo_serial%3==2?2.5:1.25;
    return connected;
}
void Combat::ally_advance(Crowd& crowd,Unit& u,double dt){
    const auto& profile=allies_[u.kind];const auto& attack=profile.primary[u.combo_serial%6];
    double tempo=u.kind==10?u.frame_tempo:ally_tempo(u);double before=u.action_time;u.action_time+=dt*tempo;
    if(!u.primary_hit&&u.action_time+1e-8>=attack.contact){u.primary_hit=true;if(u.kind==10){if(auto enemy=crowd.unit(u.target_handle))ranger_fire(crowd,u,enemy_contact(*enemy,u.position+Vec3{0,1,0}),false);}else if(ally_primary(crowd,u))u.hit_pause=attack.stop;}
    if(u.action_time+1e-8>=attack.duration){u.action_active=false;u.action=data_.actions[0];u.action_time=0;++u.combo_serial;}
}
}

namespace army {
double Combat::random(Unit& u){if(!u.rng)u.rng=uint64_t(u.logical_id)*0x9e3779b97f4a7c15ull;u.rng^=u.rng>>12;u.rng^=u.rng<<25;u.rng^=u.rng>>27;return double((u.rng*2685821657736338717ull)>>11)/9007199254740992.0;}
float Combat::enemy_segment(const Unit& victim,Vec3 from,Vec3 to,float radius) const{
    Vec3 a=rotated_y(from-victim.position,-victim.yaw),b=rotated_y(to-victim.position,-victim.yaw),direction=b-a;
    float enter=0,leave=1;float start[]={a.x,a.y,a.z},delta[]={direction.x,direction.y,direction.z},low[]={-1.728f-radius,-radius,-3.456f-radius},high[]={1.728f+radius,6.048f+radius,3.456f+radius};
    for(int axis=0;axis<3;++axis){
        if(std::abs(delta[axis])<1e-8f){if(start[axis]<low[axis]||start[axis]>high[axis])return -1;continue;}
        float t0=(low[axis]-start[axis])/delta[axis],t1=(high[axis]-start[axis])/delta[axis];enter=std::max(enter,std::min(t0,t1));leave=std::min(leave,std::max(t0,t1));if(enter>leave)return -1;
    }
    return enter;
}
void Combat::ninja_begin(Unit& u,Vec3 aim){
    u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);u.dash_direction={std::sin(u.yaw),0,std::cos(u.yaw)};u.dash_previous=u.position;
    u.special_time=0;u.action_time=0;u.action=data_.actions[9];u.action_active=true;u.primary_hit=false;u.cast_confirmed=false;u.motion_impulse={};u.action_hits.clear();
    u.skill_left=data_.ninja[6];u.invuln=std::max(u.invuln,data_.ninja[0]);u.attack_damage=data_.ninja[2]*allies_[5].damage*std::min(1.5,1.0+.05*u.chain_count);
}
bool Combat::move_special(Crowd& crowd,Unit& u,double dt,Vec3& next){
    if(!enabled_||u.team!=1)return false;
    if(u.shelter_mode==4&&u.bunker_stage<=2)return bunker_move(crowd,u,dt,next);
    if(u.kind==8&&u.air_phase&&!data_.dragoon.empty()){
        const auto& d=data_.dragoon;Vec3 motion;
        if(u.air_phase==1){Vec3 offset=u.landing_goal+Vec3{0,-.5f,0}-u.position;motion=normalized(offset)*std::min(length(offset),float(d[D_AIM_SPEED]*dt));}
        else if(u.air_phase==3){motion={0,float(u.velocity.y*dt),0};u.special_time+=dt;}
        else {float fall=u.air_phase==2?float(-std::min(d[D_FALL_MAX],std::max(d[D_FALL_MIN],double(-u.velocity.y))+d[D_GRAVITY]*dt)):float(std::max(-d[D_FALL_MAX],double(u.velocity.y)-d[D_GRAVITY]*dt));motion={0,float(fall*dt),0};}
        if(u.air_phase==4){motion=motion+u.knockback*float(dt);u.knockback=u.knockback*float(std::exp(-8*dt));}
        auto moved=crowd.allied_terrain.air_move(u.position,motion,float(d[D_RADIUS]),float(d[D_HEIGHT]),float(d[D_CENTER]));next=moved.position;u.action_time+=dt;
        if(moved.floor){u.air_phase=0;u.just_landed=true;u.support_layer=crowd.allied_terrain.choose_layer(next);u.has_goal=false;}
        else if(u.air_phase==1){Vec3 goal=u.landing_goal+Vec3{0,-.5f,0};float progress=length(goal-u.position)-length(goal-next);u.air_stalled=progress<dt*.25?u.air_stalled+dt:0;if(length(goal-next)<.15f||u.air_stalled>.2){u.air_phase=2;u.velocity.y=-float(d[D_FALL_MIN]);}}
        return true;
    }
    if(u.kind!=5||data_.ninja.empty()||u.action!=data_.actions[9]||!u.action_active)return false;
    double duration=data_.ninja[0],step=std::min(dt,std::max(0.0,duration-u.special_time)),start=u.special_time/duration,finish=(u.special_time+step)/duration;
    double travel=step+.28*duration/M_PI*(std::sin(finish*M_PI)-std::sin(start*M_PI));u.dash_previous=u.position;u.special_time+=step;u.action_time=u.special_time;
    float speed=float(data_.ninja[1]*travel/std::max(1e-8,dt));next=crowd.allied_terrain.direct_move(u.position,u.dash_direction*(speed*float(dt)),u.radius,u.support_layer);return true;
}
void Combat::ninja_damage_segment(Crowd& crowd,Unit& u,Vec3 from,Vec3 to,float radius,bool finish){
    Vec3 pad{radius+4,radius+7,radius+4};Vec3 low{std::min(from.x,to.x),std::min(from.y,to.y),std::min(from.z,to.z)},high{std::max(from.x,to.x),std::max(from.y,to.y),std::max(from.z,to.z)};
    std::vector<std::pair<float,Handle>> candidates;
    for(auto h:crowd.query(low-pad,high+pad,0)){
        auto e=crowd.unit(h);if(!e||(!finish&&std::find(u.action_hits.begin(),u.action_hits.end(),h)!=u.action_hits.end()))continue;
        float t=enemy_segment(*e,from,to,radius);if(t>=0)candidates.push_back({t,h});
    }
    std::stable_sort(candidates.begin(),candidates.end(),[](const auto& a,const auto& b){return a.first<b.first;});
    for(const auto& entry:candidates){
        auto e=crowd.unit(entry.second);if(!e||!u.alive)continue;Vec3 origin=from+(to-from)*entry.first,point=enemy_contact(*e,origin);
        if(!crowd.terrain.ray_clear(origin,point))continue;
        Hit hit;hit.source_id=u.logical_id;hit.amount=u.attack_damage;hit.heavy=true;hit.direction=u.dash_direction;
        if(random(u)*100<allies_[5].critical)hit.amount*=2;
        if(this->hit(crowd,entry.second,hit).accepted){u.chain_left=1.75;if(!u.cast_confirmed){u.cast_confirmed=true;++u.chain_count;}if(!finish)u.action_hits.push_back(entry.second);}
    }
}
void Combat::ninja_resolve(Crowd& crowd,Unit& u){
    Vec3 height{0,1.4f,0};ninja_damage_segment(crowd,u,u.dash_previous+height,u.position+height,float(data_.ninja[3]),false);
    if(u.special_time+1e-8>=data_.ninja[0]){
        ninja_damage_segment(crowd,u,u.position+height,u.position+height+u.dash_direction*float(data_.ninja[4]),float(data_.ninja[5]),true);
        u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.action_hits.clear();u.recovery_left=.16;
    }
}
}

namespace army {
void Combat::ninja_stars(Crowd& crowd,Unit& u,Vec3 aim){
    u.shot_left=std::max(0.0,.2-u.live_delta);
    u.roll_left=data_.ninja[7];Vec3 origin=u.position+Vec3{0,u.shelter_mode==2?1.2f:1.05f,0};Vec3 direction=normalized(aim-origin);
    auto cast=std::make_shared<ProjectileCast>();cast->owner=u.handle;cast->rng=uint64_t(u.logical_id)^uint64_t(next_projectile_)*0x9e3779b97f4a7c15ull;cast->critical=allies_[5].critical;
    double amount=25*allies_[5].damage*std::min(1.5,1.0+.05*u.chain_count);
    for(int i=-2;i<=2;++i){
        Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=5;shot.source_team=1;shot.cast=cast;shot.direction=rotated_y(direction,float(i*.19));shot.position=origin+shot.direction*.9f;shot.damage=amount;shot.speed=25;shot.radius=float(.5*data_.ninja[10]);shot.life=28*data_.ninja[10]/25;
        float contact=crowd.terrain.projectile_fraction(origin,shot.position,shot.radius);
        if(contact>=0){shot.position=origin+(shot.position-origin)*contact;shot.origin=shot.position;shot.life=0;shot.range=0;}
        shot.scale=float(data_.ninja[10]*1.8);projectiles_.push_back(shot);Event event;event.kind=BULLET;event.source_id=u.logical_id;event.projectile_id=shot.id;event.unit_kind=5;event.team=1;event.amount=25;event.position=shot.position;event.direction=shot.direction;emit(event);
    }
}
}

namespace army {
void Combat::dragoon_begin(Crowd& crowd,Unit& u,Vec3 aim){
    const auto& d=data_.dragoon;Vec3 offset=aim-u.position;offset.y=0;
    if(length(offset)>d[D_MAX_RANGE]){offset=normalized(offset)*float(d[D_MAX_RANGE]);aim.x=u.position.x+offset.x;aim.z=u.position.z+offset.z;}
    bool valid=false;u.landing_goal=crowd.allied_terrain.landing(aim,std::max(aim.y,u.position.y)+2,valid);
    if(!valid)u.landing_goal.y=std::min(aim.y,u.position.y-8);
    offset=u.landing_goal-u.position;if(std::hypot(offset.x,offset.z)>.1f)u.yaw=std::atan2(offset.x,offset.z);
    u.air_phase=1;u.air_stalled=0;u.landing_attack=true;u.just_landed=false;u.action=data_.actions[10];u.action_active=true;u.action_time=0;u.has_goal=false;u.motion_impulse={};u.pending_drift=0;u.cast_confirmed=false;
    u.skill_left=u.buff_left>0?0:d[D_SKILL_CD];u.invuln=std::max(u.invuln,.72);u.velocity={0,-float(d[D_FALL_MIN]),0};
    u.attack_damage=d[D_PULSE_DAMAGE]*allies_[8].damage*std::min(1.5,1.0+.05*u.chain_count);
}
void Combat::dragoon_sweep(Unit& u){
    u.action=data_.actions[16];u.action_active=true;u.action_time=0;u.sweep_marker=0;u.has_goal=false;u.cast_confirmed=false;u.motion_impulse={};
    u.skill_left=u.buff_left>0?0:data_.dragoon[D_SKILL_CD];u.attack_damage=data_.dragoon[D_SWEEP_DAMAGE]*allies_[8].damage*std::min(1.5,1.0+.05*u.chain_count);
}
void Combat::dragoon_advance(Crowd& crowd,Unit& u,double dt){
    const auto& d=data_.dragoon;double tempo=allies_[8].rate*std::min(1.5,1.0+std::max(0,u.chain_count-1)*.05);u.action_time+=dt*tempo;
    while(u.sweep_marker<3&&u.action_time+1e-8>=d[D_SWEEP_CONTACT]+u.sweep_marker*d[D_SWEEP_INTERVAL]){
        Event event;event.kind=MELEE;event.source_id=u.logical_id;event.position=u.position;event.amount=d[D_SWEEP_DAMAGE];event.unit_kind=8;event.team=1;event.action_index=u.sweep_marker;event.source_tick=(d[D_SWEEP_CONTACT]+u.sweep_marker*d[D_SWEEP_INTERVAL])*30;emit(event);++u.sweep_marker;
        float reach=float(d[D_SWEEP_REACH]);Vec3 pad{reach+4,12,reach+4};
        for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
            auto enemy=crowd.unit(h);if(!enemy)continue;Vec3 point=enemy_contact(*enemy,u.position+Vec3{0,1,0}),offset=point-u.position;
            if(std::abs(offset.y)>3.5f||std::hypot(offset.x,offset.z)>reach||std::abs(std::remainder(std::atan2(offset.x,offset.z)-u.yaw,float(2*M_PI)))>d[D_SWEEP_ARC]||!crowd.terrain.ray_clear(u.position+Vec3{0,1,0},point))continue;
            Hit hit;hit.source_id=u.logical_id;hit.amount=u.attack_damage;hit.heavy=true;hit.direction={std::sin(u.yaw),0,std::cos(u.yaw)};if(random(u)*100<allies_[8].critical)hit.amount*=2;
            if(this->hit(crowd,h,hit).accepted){u.hit_pause=std::max(u.hit_pause,d[D_SWEEP_STOP]);u.chain_left=1.75;if(!u.cast_confirmed){u.cast_confirmed=true;++u.chain_count;}}
        }
    }
    if(u.action_time+1e-8>=d[D_SWEEP_TIME]){u.action_active=false;u.action=data_.actions[0];u.action_time=0;}
}
void Combat::dragoon_land(Crowd& crowd,Unit& u){
    u.landing_left=.8;
    u.landing_attack=false;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.motion_impulse={};
    auto cast=std::make_shared<ProjectileCast>();cast->owner=u.handle;cast->critical=allies_[8].critical;cast->rng=uint64_t(u.logical_id)^uint64_t(serial_+1)*0x9e3779b97f4a7c15ull;
    for(int i=0;i<3;++i){LandingPulse p;p.left=i*data_.dragoon[D_PULSE_INTERVAL];p.damage=u.attack_damage;p.position=u.position;p.radius=float(data_.dragoon[D_PULSE_RADIUS0+i]*data_.dragoon[D_RANGE]);p.index=i;p.source_id=u.logical_id;p.cast=cast;if(i==0)landing_pulse(crowd,p);else pulses_.push_back(p);}
}
void Combat::landing_pulse(Crowd& crowd,const LandingPulse& p){
    Event event;event.kind=LANDING_PULSE;event.source_id=p.source_id;event.position=p.position;event.unit_kind=8;event.team=1;event.action_index=p.index;event.amount=data_.dragoon[D_PULSE_DAMAGE];emit(event);
    Vec3 pad{p.radius+4,p.radius+7,p.radius+4};
    for(auto h:crowd.query(p.position-pad,p.position+pad,0)){
        auto enemy=crowd.unit(h);if(!enemy)continue;Vec3 origin=p.position+Vec3{0,1,0},point=enemy_contact(*enemy,origin);
        if(length(point-p.position)>p.radius||!crowd.terrain.ray_clear(origin,point))continue;
        Hit hit;hit.source_id=p.source_id;hit.amount=p.damage;hit.projectile=true;hit.direction=normalized(enemy->position-p.position);
        auto& cast=*p.cast;cast.rng^=cast.rng>>12;cast.rng^=cast.rng<<25;cast.rng^=cast.rng>>27;if(double((cast.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<cast.critical)hit.amount*=2;
        if(this->hit(crowd,h,hit).accepted)if(auto owner=crowd.unit(cast.owner)){owner->chain_left=1.75;if(!cast.confirmed){cast.confirmed=true;++owner->chain_count;}}
    }
}
void Combat::pulses(Crowd& crowd,double delta){
    size_t count=0;for(auto p:pulses_){auto owner=crowd.unit(p.cast->owner);p.left-=owner?owner->live_delta:delta;if(p.left<=1e-8)landing_pulse(crowd,p);else pulses_[count++]=p;}pulses_.resize(count);
}
}

namespace army {
double Combat::ally_tempo(const Unit& u) const{
    return allies_[u.kind].rate*(u.kind==10?std::min(3.0,1.0+.12*u.chain_count):std::min(1.5,1.0+std::max(0,u.chain_count-1)*.05));
}
void Combat::ranger_fire(Crowd& crowd,Unit& u,Vec3 aim,bool fan){
    u.shot_left=std::max(0.0,.2-(fan?u.live_delta:0));
    const auto& d=data_.ranger;const auto& profile=allies_[10];const auto& attack=profile.primary[u.combo_serial%6];
    bool power=u.buff_left>0||(!fan&&u.ranger_power);
    double raw=fan?(power?d[R_FAN_POWER_DAMAGE]:d[R_FAN_DAMAGE]):(power?std::round(attack.damage*d[R_POWER_DAMAGE]):attack.damage);
    double amount=fan?raw*profile.damage*std::min(1.5,1.0+.05*u.chain_count):raw*(u.attack_damage/attack.damage);
    Vec3 origin=u.position+Vec3{0,float(1.05*d[R_GROWTH]),0};
    if(!fan){
        float sample=float(std::clamp(u.action_time/attack.duration,0.0,1.0)*32);int low=int(sample),high=std::min(32,low+1),offset=(u.combo_serial%6)*33;
        Vec3 a=data_.ranger_muzzles[offset+low],b=data_.ranger_muzzles[offset+high],point=a+(b-a)*(sample-low);
        if(!data_.ranger_motion_muzzles.empty()){
            double weight=std::clamp(std::hypot(u.velocity.x,u.velocity.z)/std::max(.001,profile.speed),0.0,1.0);
            if(dot(u.velocity,Vec3{std::sin(u.yaw),0,std::cos(u.yaw)})<0)offset+=6*33;
            a=data_.ranger_motion_muzzles[offset+low];b=data_.ranger_motion_muzzles[offset+high];point=point+(a+(b-a)*(sample-low)-point)*float(weight);
        }
        origin=u.position+rotated_y(point,u.yaw);
    }
    if(u.shelter_mode==2)origin=u.position+Vec3{0,1.2f,0};
    Vec3 direction=normalized(aim-origin);
    auto cast=std::make_shared<ProjectileCast>();cast->owner=u.handle;cast->rng=uint64_t(u.logical_id)^uint64_t(next_projectile_)*0x9e3779b97f4a7c15ull;cast->critical=profile.critical;
    for(int i=fan?-2:0;i<=(fan?2:0);++i){
        Vec3 forward=rotated_y(direction,float(i*d[R_FAN_STEP])),side=normalized(cross(forward,{0,1,0}));if(length(side)<.1f)side={1,0,0};Vec3 up=normalized(cross(side,forward));
        double yaw=(random(u)*2-1)*d[power?R_POWER_YAW:R_NORMAL_YAW],pitch=(random(u)*2-1)*d[power?R_POWER_PITCH:R_NORMAL_PITCH];
        Vec3 released=normalized(forward+side*float(std::tan(yaw))+up*float(std::tan(pitch)));
        Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=10;shot.source_team=1;shot.cast=cast;shot.direction=released;shot.position=origin+released*float((fan?.9:.12)*d[R_GROWTH]);shot.origin=shot.position;shot.damage=amount;shot.speed=float(d[fan?R_FAN_SPEED:R_PRIMARY_SPEED]);shot.radius=float(d[R_WIDTH]*d[R_RANGE]);shot.range=float(d[R_RANGE_METRES]*(fan?d[R_RANGE]:d[R_PRIMARY_RANGE_SCALE]));shot.life=shot.range/shot.speed;shot.ranger=true;shot.curved=d[R_CURVED]!=0;shot.power=power;shot.heavy=!fan;shot.scale=float(d[R_RANGE]);
        side=normalized(cross(released,{0,1,0}));if(length(side)<.1f)side={1,0,0};up=normalized(cross(side,released));
        shot.curve=side*float((u.ranger_serial%2?-1:1)*d[R_CURVE_SIDE]*d[R_RANGE])+up*float(d[R_CURVE_UP]*d[R_RANGE]);++u.ranger_serial;
        float contact=crowd.terrain.projectile_fraction(origin,shot.position,shot.radius);
        if(contact>=0){shot.position=origin+(shot.position-origin)*contact;shot.origin=shot.position;shot.life=0;shot.range=0;}
        projectiles_.push_back(shot);Event event;event.kind=BULLET;event.source_id=u.logical_id;event.projectile_id=shot.id;event.unit_kind=10;event.team=1;event.action_index=fan?3:u.combo_serial%3;event.amount=raw;event.position=shot.position;event.direction=released;event.heavy=!fan;emit(event);
    }
    if(fan){u.skill_left=std::max(0.0,d[u.buff_left>0?R_BUFF_SKILL_CD:R_SKILL_CD]-u.live_delta*ally_tempo(u));u.utility_wait=std::max(0.0,.2-u.live_delta);u.action=data_.actions[12];u.action_time=u.live_delta;}
    else{++u.ranger_shots;u.motion_impulse=u.motion_impulse-Vec3{std::sin(u.yaw),0,std::cos(u.yaw)}*.8f;}
}
}

namespace army {
void Combat::knight_code(Unit& u,double dt){
    u.buff_left=std::max(0.0,data_.knight[K_BUFF_TIME]-dt);u.utility_left=std::max(0.0,data_.knight[K_BUFF_CD]-dt);
    latest_taunt_=u.handle;if(!first_taunt_||u.handle<first_taunt_)first_taunt_=u.handle;
    Event e;e.kind=STATUS_EVENT;e.source_id=u.logical_id;e.target_id=u.logical_id;e.unit_kind=7;e.team=1;e.position=u.position;e.amount=u.buff_left;e.action_index=data_.actions[14];emit(e);
}
void Combat::knight_counter(Unit& u){
    if(std::any_of(counters_.begin(),counters_.end(),[&](const ShieldCounter& c){return c.cast->owner==u.handle;}))return;
    ShieldCounter c;c.position=u.position;c.yaw=u.yaw;c.scale=float(data_.knight[K_RANGE]);c.source_id=u.logical_id;
    c.damage=data_.knight[K_COUNTER_DAMAGE]*allies_[7].damage*std::min(1.5,1.0+.05*u.chain_count);
    c.last.fill(data_.knight[K_START]-data_.knight[K_THICKNESS]);
    c.cast=std::make_shared<ProjectileCast>();c.cast->owner=u.handle;c.cast->critical=allies_[7].critical;c.cast->rng=uint64_t(u.logical_id)^uint64_t(serial_+1)*0x9e3779b97f4a7c15ull;counters_.push_back(std::move(c));
}
void Combat::counters(Crowd& crowd,double delta){
    if(counters_.empty())return;
    const auto& d=data_.knight;size_t retained=0;
    for(auto& c:counters_){
        auto owner=crowd.unit(c.cast->owner);double dt=owner?owner->live_delta:delta;
        if(dt<=0){if(&c!=&counters_[retained])counters_[retained]=std::move(c);++retained;continue;}
        c.age+=dt;Vec3 forward{std::sin(c.yaw),0,std::cos(c.yaw)},side{forward.z,0,-forward.x};
        for(int i=0;i<3;++i){
            double age=c.age-i*d[K_INTERVAL];if(age<0)continue;
            if(!c.started[i]){c.started[i]=true;Event e;e.kind=SHIELD_COUNTER;e.source_id=c.source_id;e.unit_kind=7;e.team=1;e.action_index=i;e.position=c.position;e.direction=forward;e.amount=d[K_COUNTER_DAMAGE];emit(e);}
            double from=c.last[i],to=d[K_START]+d[K_DISTANCE]*std::clamp(age/d[K_TRAVEL],0.0,1.0)+d[K_THICKNESS];
            if(to<=from+.00001)continue;
            Vec3 center=c.position+Vec3{0,float(d[K_HEIGHT]*.5*c.scale),0}+forward*float((from+to)*.5*c.scale),origin=c.position+Vec3{0,float(d[K_HEIGHT]*.5*c.scale),0};
            float reach=float((d[K_START]+d[K_DISTANCE]+d[K_THICKNESS]+d[K_WIDTH])*c.scale);Vec3 pad{reach+4,float(d[K_HEIGHT]*c.scale+7),reach+4};
            for(auto h:crowd.query(c.position-pad,c.position+pad,0)){
                auto enemy=crowd.unit(h);if(!enemy||std::find(c.hits[i].begin(),c.hits[i].end(),h)!=c.hits[i].end())continue;
                Vec3 point=enemy_contact(*enemy,center),offset=(point-c.position)*(1/c.scale);float f=dot(offset,forward),x=dot(offset,side),y=offset.y-float(d[K_HEIGHT]*.5);
                if(f<from||f>to||std::abs(x)>d[K_WIDTH]||offset.y<-.1||offset.y>d[K_HEIGHT])continue;
                // Original six-sided shield face, scaled in metre space.
                const float px[]={-6,0,6,5.8f,0,-5.8f},py[]={2.3f,3.3f,2.3f,-1.4f,-3.3f,-1.4f};bool inside=false;
                for(int a=0,b=5;a<6;b=a++)if((py[a]>y)!=(py[b]>y)&&x<(px[b]-px[a])*(y-py[a])/(py[b]-py[a])+px[a])inside=!inside;
                if(!inside||!crowd.terrain.ray_clear(origin,point))continue;
                Hit hit;hit.source_id=c.source_id;hit.amount=c.damage;hit.projectile=true;hit.heavy=true;hit.direction=forward;
                auto& cast=*c.cast;cast.rng^=cast.rng>>12;cast.rng^=cast.rng<<25;cast.rng^=cast.rng>>27;if(double((cast.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<cast.critical)hit.amount*=2;
                if(this->hit(crowd,h,hit).accepted){if(auto live=crowd.unit(cast.owner)){live->chain_left=1.75;if(!cast.confirmed){cast.confirmed=true;++live->chain_count;}}}
                c.hits[i].push_back(h);
            }
            c.last[i]=to;
        }
        if(c.age<(2*d[K_INTERVAL]+d[K_TRAVEL]+d[K_TAIL])){if(&c!=&counters_[retained])counters_[retained]=std::move(c);++retained;}
    }
    counters_.resize(retained);
}
}

namespace army {
void Combat::animation_step(Crowd& crowd,double delta){
    for(auto& u:crowd.units_)if(u.alive){
        u.pose_time+=u.live_delta;
        if(u.live_delta>0)u.pose_velocity=u.velocity;
        u.flash_left=std::max(0.0,u.flash_left-u.live_delta);
        double stride=u.team==0&&u.kind>=0&&u.kind<19&&soldiers_[u.kind].active?soldiers_[u.kind].stride:2.4;
        double speed=std::hypot(u.velocity.x,u.velocity.z);
        if(u.team==1&&u.kind>=0&&u.kind<19&&allies_[u.kind].active&&!data_.walk_cadence.empty()){
            if(u.live_delta>0&&!u.air_phase&&u.action!=data_.actions[9]&&speed>.001){double sample=std::min(160.0,speed*4);int low=int(sample),high=std::min(160,low+1);const auto& c=allies_[u.kind].cadence;u.walk_phase+=(c[low]+(c[high]-c[low])*(sample-low))*u.live_delta*2*M_PI;}
        }else if(!enabled_||u.team!=0||u.action==data_.actions[0])u.walk_phase+=speed*delta/std::max(.001,stride)*2*M_PI;
        refresh_status(u);
        pose_frame(u);
    }
}
void Combat::refresh_status(Unit& u) const{
    if(enabled_)u.status=(u.frozen>0?data_.status_bits[0]:0)|(u.slow_left>0?data_.status_bits[1]:0)|(u.stun>0?data_.status_bits[2]:0)|((u.invuln>0||(u.kind==8&&u.landing_attack))?data_.status_bits[3]:0)|(u.blocking?data_.status_bits[4]:0)|(u.buff_left>0?data_.status_bits[5]:0)|(u.shelter_mode==2?data_.status_bits[6]:0);
}
void Combat::pose_frame(Unit& u){
    if(!enabled_||u.team!=0||u.kind<0||u.kind>=19||!soldiers_[u.kind].active||data_.soldier_pose_meta.empty())return;
    const auto& meta=soldiers_[u.kind].poses;int clip=0;double tick=u.pose_time*30;bool loop=true;
    if(u.action==data_.actions[6]){clip=7;tick=(16.0/30-u.stun)*30;loop=false;}
    else {
        for(int i=1;i<=5;++i)if(u.action==data_.actions[i]){clip=i+1;tick=u.phase_tick;loop=false;break;}
        if(clip==0&&dot(u.pose_velocity,u.pose_velocity)>.01f){clip=1;tick=std::fmod(u.walk_phase,2*M_PI)/(2*M_PI)*meta[3];}
    }
    int count=meta[clip*2+1],frame=int(std::floor(tick+1e-6));frame=loop?((frame%count)+count)%count:std::clamp(frame,0,count-1);u.pose_row=data_.soldier_pose_rows[meta[clip*2]+frame];
}
}

namespace army {
void Combat::cancel_owned(const Unit& u){
    auto owns=[&](const auto& p){return p.cast&&p.cast->owner==u.handle;};
    projectiles_.erase(std::remove_if(projectiles_.begin(),projectiles_.end(),owns),projectiles_.end());
    pulses_.erase(std::remove_if(pulses_.begin(),pulses_.end(),owns),pulses_.end());
    counters_.erase(std::remove_if(counters_.begin(),counters_.end(),owns),counters_.end());
}
bool Combat::shelter(Crowd& crowd,Unit& u,double dt,bool active){
    if(u.guard_radius<=0||dt<=0)return u.shelter_mode!=0;
    const ShelterTarget* bunker=nullptr;
    for(const auto& b:shelters_)if(b.id==u.shelter_id){bunker=&b;break;}
    if(u.shelter_mode==4){
        if(!active){cancel_owned(u);bunker_finish(u,bunker);return true;}
        u.bunker_age+=dt;u.skill_left=std::max(0.0,u.skill_left-dt);
        if(!bunker&&u.bunker_stage<3){u.air_phase=4;u.landing_attack=false;bunker_finish(u,nullptr);return true;}
        if((u.bunker_stage<3&&u.bunker_age>5)||(u.bunker_stage==3&&u.air_phase==0&&!u.just_landed&&!std::any_of(pulses_.begin(),pulses_.end(),[&](const LandingPulse& p){return p.cast->owner==u.handle;})))bunker_finish(u,bunker);
        return true;
    }
    if((u.shelter_mode==1||u.shelter_mode==2)&&!bunker){
        if(u.shelter_mode==2)u.position=u.shelter_exit;
        u.shelter_mode=3;u.shelter_id=-1;u.shelter_retry=0;
    }
    if(u.shelter_mode==2){
        u.hp=std::min(u.max_hp,u.hp+10*dt);u.velocity={};u.has_goal=false;
        if(u.hp<u.max_hp){if(active&&!data_.bunker.empty())bunker_tick(crowd,u,*bunker,dt);return true;}
        u.position=u.shelter_exit;u.shelter_mode=3;u.shelter_id=-1;u.shelter_retry=0;
    }
    if(u.shelter_mode==3){u.shelter_mode=0;u.think_left=0;return false;}
    u.shelter_retry=std::max(0.0,u.shelter_retry-dt);
    if(u.shelter_mode==0&&u.hp>0&&u.hp<u.max_hp*.3&&u.shelter_retry<=0){
        u.shelter_retry=1;float distance=INFINITY;
        for(const auto& b:shelters_){float gap=horizontal(u.position,b.entrance);if(gap<distance&&crowd.allied_terrain.reachable(u.position,b.entrance,u.radius,u.support_layer)){bunker=&b;distance=gap;}}
        if(bunker){
            cancel_owned(u);u.shelter_id=bunker->id;u.shelter_exit=bunker->entrance;u.shelter_mode=1;
            u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.blocking=false;u.buff_left=0;u.riposte=false;u.air_phase=0;u.landing_attack=false;u.motion_impulse={};u.knockback={};u.opening=false;u.target_handle=0;u.routing=false;
        }
    }
    if(u.shelter_mode==1){
        if(horizontal(u.position,u.shelter_exit)<1.5f){u.shelter_mode=2;u.position=bunker->center;u.velocity={};u.has_goal=false;bunker_enter(crowd,u,*bunker);}
        else{u.goal=u.shelter_exit;u.move_speed=float(allies_[u.kind].speed);u.has_goal=true;}
        return true;
    }
    return false;
}
void Combat::rest_tick(Crowd& crowd,double delta){
    if(!enabled_||!std::isfinite(delta)||delta<=0)return;
    for(auto& u:crowd.units_)if(u.alive&&u.team==1&&u.shelter_mode==2){shelter(crowd,u,delta,false);if(u.shelter_mode==2)u.status|=data_.status_bits[6];else u.status&=~data_.status_bits[6];}
}
}
