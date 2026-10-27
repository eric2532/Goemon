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
float box_segment(Vec3 from,Vec3 to,Vec3 minimum,Vec3 maximum,float radius){
    Vec3 direction=to-from;float enter=0,leave=1;
    float start[]={from.x,from.y,from.z},delta[]={direction.x,direction.y,direction.z};
    float low[]={minimum.x-radius,minimum.y-radius,minimum.z-radius},high[]={maximum.x+radius,maximum.y+radius,maximum.z+radius};
    for(int axis=0;axis<3;++axis){
        if(std::abs(delta[axis])<1e-8f){if(start[axis]<low[axis]||start[axis]>high[axis])return -1;continue;}
        float t0=(low[axis]-start[axis])/delta[axis],t1=(high[axis]-start[axis])/delta[axis];enter=std::max(enter,std::min(t0,t1));leave=std::min(leave,std::max(t0,t1));if(enter>leave)return -1;
    }
    return enter;
}
bool body_contact(Vec3 from,Vec3 to,Vec3 foot,float radius){return segment_distance(from,to,foot+Vec3{0,.4f,0},foot+Vec3{0,1.8f,0})<radius;}
float horizontal(Vec3 a,Vec3 b){return std::hypot(a.x-b.x,a.z-b.z);}
}
bool Combat::configure(KitData data){
    enabled_=false;soldiers_={};allies_={};
    if(!valid_kit_data(data))return false;
    data_=std::move(data);nearest_revision_=UINT64_MAX;
    for(size_t i=0;i<data_.soldier_kinds.size();++i){const float* row=data_.soldier_profiles.data()+i*6;soldiers_[data_.soldier_kinds[i]]={true,row[0],row[1],row[2],row[3],row[4],row[5]};}
    for(size_t i=0;i<data_.soldier_kinds.size();++i){
        int kind=data_.soldier_kinds[i];auto& k=soldiers_[kind].kit;
        soldiers_[kind].contact_end=data_.enemy_contact_ends.empty()?0:data_.enemy_contact_ends[i];
        if(!data_.enemy_kits.empty())std::copy_n(data_.enemy_kits.data()+i*26,26,k.begin());
        else{
            std::copy_n(data_.phase_ticks.begin(),5,k.begin());std::copy_n(data_.contact_ticks.begin(),4,k.begin()+5);
            k[9]=data_.melee_from.x;k[10]=data_.melee_from.y;k[11]=data_.melee_from.z;k[12]=data_.melee_to.x;k[13]=data_.melee_to.y;k[14]=data_.melee_to.z;
            k[25]=-1;k[15]=.576f;k[17]=kind==1?3:0;k[18]=kind==0?1:0;
            k[19]=-.576f*data_.enemy_size;k[21]=-1.152f*data_.enemy_size;k[22]=.576f*data_.enemy_size;k[23]=2.016f*data_.enemy_size;k[24]=1.152f*data_.enemy_size;
        }
    }
    if(!data_.soldier_pose_meta.empty())for(size_t i=0;i<data_.soldier_kinds.size();++i)std::copy_n(data_.soldier_pose_meta.data()+i*16,16,soldiers_[data_.soldier_kinds[i]].poses.begin());
    for(size_t i=0;i<data_.ally_kinds.size();++i){auto& p=allies_[data_.ally_kinds[i]];const double* r=data_.ally_profiles.data()+i*5;p.active=true;p.hp=r[0];p.speed=r[1];p.damage=r[2];p.rate=r[3];p.critical=r[4];
        if(!data_.walk_cadence.empty())std::copy_n(data_.walk_cadence.data()+i*161,161,p.cadence.begin());
        for(int a=0;a<6;++a){const double* v=data_.ally_primaries.data()+i*42+a*7;p.primary[a]={v[0],v[1],v[2],v[3],v[4],v[5],v[6]};}}
    enabled_=true;return true;
}
void Combat::clear(){skullpions_.clear();nearest_entries_.clear();nearest_nodes_.clear();nearest_revision_=UINT64_MAX;nearest_contact_tests_=0;nearest_position_reads_=0;projectiles_.clear();pulses_.clear();counters_.clear();threats_.clear();mirror_targets_.clear();first_taunt_=latest_taunt_=0;events_.clear();set_targets({});shelters_.clear();}
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
    bool boss=u->team==0&&u->kind==4&&!data_.skullpion.empty();
    if(!boss&&finite(incoming.impulse)&&std::isfinite(incoming.flinch)&&incoming.flinch>=0&&(length(incoming.impulse)>0||incoming.flinch>0)){
        u->knockback=incoming.add_impulse?u->knockback+incoming.impulse:incoming.impulse;u->knockback_decay=8;u->stun=std::max(u->stun,incoming.flinch);u->action_active=false;u->action=data_.actions.empty()?0:data_.actions[0];u->action_time=0;u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};result.accepted=true;
        if(u->air_phase){u->air_phase=4;u->landing_attack=false;u->invuln=0;}
    }
    if(incoming.status_seconds>0){
        if(incoming.effect==1){u->frozen=std::max(u->frozen,incoming.status_seconds);result.accepted=true;}
        if(incoming.effect==2&&std::isfinite(incoming.slow_factor)&&incoming.slow_factor>=0&&incoming.slow_factor<=1){u->slow_left=std::max(u->slow_left,incoming.status_seconds);u->slow_factor=std::min(u->slow_factor,incoming.slow_factor);result.accepted=true;}
    }
    refresh_status(*u);
    if(incoming.amount<=0||u->invuln>0||(u->kind==8&&u->team==1&&u->landing_attack&&u->action_active))return result;
    double amount=knight&&u->buff_left>0?std::round(incoming.amount*.5):incoming.amount;
    if(boss&&u->action!=107){
        auto& state=skullpions_[handle];state.armor+=std::min(incoming.heavy?amount:amount*.15,u->max_hp*.01);amount*=.15;
        if(state.armor>=u->max_hp*.08){state.armor=0;boss_enter(*u,7,u->position);}
    }
    double damage=amount*(u->team==1?data_.damage_taken_multiplier:1);
    if(damage<=0)return result;
    result.accepted=true;u->flash_left=.115;u->hp-=damage;if(u->team==1)u->hp=std::max(0.0,u->hp);
    if(u->hp<=0&&u->team==0&&u->kind>=0&&u->kind<19&&soldiers_[u->kind].active){
        int next=int(soldiers_[u->kind].kit[25]);
        if(next>=0&&soldiers_[next].active){
            int previous=u->kind;u->kind=next;u->hp=u->max_hp=soldiers_[next].hp*u->enemy_health_scale;u->action_active=false;u->action_time=0;u->phase_tick=0;u->pose_time=0;u->has_goal=false;u->action_hits.clear();
            Event changed;changed.kind=STATUS_EVENT;changed.source_id=u->logical_id;changed.target_id=u->logical_id;changed.position=u->position;changed.direction={std::sin(u->yaw),0,std::cos(u->yaw)};changed.unit_kind=next;changed.action_index=17;changed.amount=previous;emit(changed);
            pose_frame(*u);nearest_revision_=UINT64_MAX;
        }
    }
    result.hp=u->hp;result.dead=u->hp<=0;
    Event event;event.kind=DAMAGE;event.source_id=incoming.source_id;event.target_id=u->logical_id;event.ticket_id=incoming.ticket_id;event.position=u->position+Vec3{0,1,0};event.amount=damage;event.hp=u->hp;event.projectile=incoming.projectile;event.heavy=incoming.heavy;event.critical=incoming.critical;event.unit_kind=u->kind;event.team=u->team;emit(event);
    if(result.dead){event.kind=DEATH;event.position=u->position;event.direction={std::sin(u->yaw),0,std::cos(u->yaw)};emit(event);if(boss)skullpions_.erase(handle);crowd.despawn(handle);return result;}
    if(u->team==1){u->invuln=.35;if(knight)u->hit_pause=std::max(u->hit_pause,.045);}
    else if(!boss){
        u->stun=16.0/30;u->action_active=false;u->action_time=0;u->has_goal=false;
        u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};
        if(incoming.provoke){u->retaliation=4;u->retaliation_source=incoming.source_id;u->think_left=0;}
        // Front-load marked melee hits; other skills retain their contact spacing.
        u->knockback=normalized(Vec3{incoming.direction.x,0,incoming.direction.z})*(incoming.heavy?3.0f:1.2f);
        u->knockback_decay=incoming.responsive_recoil?12:8;
        if(incoming.responsive_recoil)u->knockback=u->knockback*1.5f;
        if(enabled_&&u->frozen<=0&&u->kind>=0&&u->kind<19&&soldiers_[u->kind].active){u->action=data_.actions[6];u->phase_tick=0;pose_frame(*u);}
    }
    refresh_status(*u);
    return result;
}
void Combat::set_targets(std::vector<ExternalTarget> targets){
    targets_=std::move(targets);++target_revision_;hero_row_=taunt_row_=-1;
    for(auto& group:target_groups_)group.clear();
    for(size_t i=0;i<targets_.size();++i){
        const auto& row=targets_[i];if(row.hp<=0||!row.targetable)continue;
        if(row.kind>=0&&row.kind<4)target_groups_[row.kind].push_back(i);
        if(row.kind==0&&row.hp>0&&hero_row_<0)hero_row_=int(i);
        if(row.taunting&&row.hp>0&&taunt_row_<0)taunt_row_=int(i);
    }
}
const ExternalTarget* Combat::external_target(const Unit& unit) const{
    if(unit.external_kind<0)return nullptr;
    // Rows are immutable until set_targets. Validate the selection as well as
    // the revision because taunts can retarget a unit within the same tick.
    if(unit.external_revision==target_revision_&&unit.external_row>=0){
        const auto& row=targets_[unit.external_row];
        if(row.id==unit.external_target&&row.kind==unit.external_kind)return &row;
    }
    unit.external_revision=target_revision_;unit.external_row=-1;
    for(size_t i=0;i<targets_.size();++i){const auto& row=targets_[i];
        if(row.id==unit.external_target&&row.kind==unit.external_kind&&row.hp>0&&row.targetable){unit.external_row=int(i);return &row;}
    }
    return nullptr;
}
bool Combat::target(Crowd& crowd,const Unit& unit,Vec3& foot) const{
    if(unit.target_handle){auto other=crowd.unit(unit.target_handle);if(!other||other->hp<=0||other->shelter_mode==2)return false;foot=other->position;return true;}
    if(unit.external_kind<0)return false;
    if(auto other=external_target(unit)){foot=(other->kind==2||other->body_bounds())?Vec3{std::clamp(unit.position.x,other->minimum.x,other->maximum.x),other->minimum.y,std::clamp(unit.position.z,other->minimum.z,other->maximum.z)}:other->foot;return true;}
    return false;
}
bool Combat::melee_contact(Crowd& crowd,const Unit& unit) const{
    Vec3 foot;if(!target(crowd,unit,foot))return false;
    const auto& k=soldiers_[unit.kind].kit;
    Vec3 from=unit.position+rotated_y({k[9],k[10],k[11]},unit.yaw),to=unit.position+rotated_y({k[12],k[13],k[14]},unit.yaw);
    if(!crowd.terrain.ray_clear(from,to,unit.external_kind==2?unit.external_target:-1))return false;
    if(unit.external_kind==2){
        for(const auto& other:targets_)if(other.id==unit.external_target&&other.kind==2){
            Vec3 p{std::clamp(to.x,other.minimum.x,other.maximum.x),std::clamp(to.y,other.minimum.y,other.maximum.y),std::clamp(to.z,other.minimum.z,other.maximum.z)};
            return segment_distance(from,to,p,p)<.18f;
        }
    }
    if(auto other=external_target(unit);other&&other->body_bounds())return box_segment(from,to,other->minimum,other->maximum,k[15])>=0;
    return body_contact(from,to,foot,k[15]);
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
    nearest_radius_=1.289*data_.enemy_size;nearest_height_=2.016*data_.enemy_size;
    for(const auto& u:crowd.units_)if(u.alive&&u.team==0){
        nearest_entries_.push_back({u.handle,u.position});++nearest_position_reads_;
        // Custom test/mod bodies smaller than their fitted box must retain the
        // old expanding query's eligibility instead of widening its semantics.
        if(u.radius<1.289f*data_.enemy_size)nearest_fallback_=true;
        if(u.kind==4){nearest_radius_=std::max(nearest_radius_,25.0);nearest_height_=std::max(nearest_height_,25.0);}
        else if(u.kind>=0&&u.kind<19&&soldiers_[u.kind].active){const auto& k=soldiers_[u.kind].kit;
            nearest_radius_=std::max(nearest_radius_,double(std::hypot(std::max(std::abs(k[19]),std::abs(k[22])),std::max(std::abs(k[21]),std::abs(k[24])))));nearest_height_=std::max(nearest_height_,double(k[23]));}
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
            double dy=std::max({double(node.low.y)-origin.y,0.0,double(origin.y)-node.high.y-nearest_height_});
            double magnitude=std::max(origin_magnitude,node.magnitude);
            // Conservative for float rotation, world addition and score rounding.
            double error=magnitude*64*1.1920928955078125e-7;
            double horizontal=std::max(0.0,std::hypot(dx,dz)-nearest_radius_-error);
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
bool Combat::target_approach(Crowd& crowd,const Unit& unit,Vec3& goal){
    Vec3 foot;if(!target(crowd,unit,foot))return false;
    const auto* building=unit.external_kind==2?external_target(unit):nullptr;
    if(unit.kind==1&&soldiers_[1].active&&gun_contact(crowd,unit)){goal=unit.position;return true;}
    if(!building&&soldiers_[unit.kind].active&&horizontal(unit.position,foot)<=soldiers_[unit.kind].range&&std::abs(unit.position.y-foot.y)<=3.5f&&melee_contact(crowd,unit)){goal=unit.position;return true;}
    int layer=unit.support_layer<0?crowd.terrain.choose_layer(unit.position):unit.support_layer;
    if(layer<0)return false;
    // Continuous ground travel preserves this approach; pose/navigation changes invalidate it.
    if(building&&unit.approach_ready&&unit.approach_target==building->id&&unit.kind!=4&&unit.kind!=17&&unit.kind!=18&&
       unit.approach_minimum.x==building->minimum.x&&unit.approach_minimum.y==building->minimum.y&&unit.approach_minimum.z==building->minimum.z&&
       unit.approach_maximum.x==building->maximum.x&&unit.approach_maximum.y==building->maximum.y&&unit.approach_maximum.z==building->maximum.z){goal=unit.target_goal;return true;}
    if(!building){goal=foot;return std::abs(crowd.terrain.height(goal.x,goal.z,layer)-goal.y)<=3.5&&crowd.terrain.reachable(unit.position,goal,unit.radius,layer);}
    float best=INFINITY;
    auto consider=[&](Vec3 point){
        point.y=float(crowd.terrain.height(point.x,point.z,layer));
        float distance=length(point-unit.position);if(!finite(point)||distance>=best)return;
        Vec3 contact{std::clamp(point.x,building->minimum.x,building->maximum.x),building->minimum.y,std::clamp(point.z,building->minimum.z,building->maximum.z)};
        if(std::abs(point.y-contact.y)>3.5f||!crowd.terrain.ray_clear(point+Vec3{0,1,0},contact+Vec3{0,1,0},building->id))return;
        if(!crowd.terrain.reachable(unit.position,point,unit.radius,layer))return;
        best=distance;goal=point;
    };
    float stand=unit.radius+.1f;
    for(int side=0;side<4;++side){
        bool along_z=side<2;float low=along_z?building->minimum.z:building->minimum.x,high=along_z?building->maximum.z:building->maximum.x;
        auto face=[&](float along){return along_z?Vec3{side==0?building->minimum.x-stand:building->maximum.x+stand,0,along}:Vec3{along,0,side==2?building->minimum.z-stand:building->maximum.z+stand};};
        consider(face(std::clamp(along_z?unit.position.z:unit.position.x,low,high)));
        for(float along=low;along<=high;along+=6)consider(face(along));
        consider(face(high));
    }
    return std::isfinite(best);
}
void Combat::choose_target(Crowd& crowd,Unit& unit){
    auto previous_handle=unit.target_handle;auto previous_id=unit.external_target;int previous_kind=unit.external_kind;
    unit.target_handle=0;unit.external_kind=-1;
    auto select=[&](int row,int64_t handle){
        unit.target_handle=handle;unit.external_kind=row>=0?targets_[row].kind:-1;
        if(row>=0)unit.external_target=targets_[row].id;
        Vec3 goal;if(!target_approach(crowd,unit,goal))return false;
        unit.target_goal=goal;unit.approach_ready=unit.external_kind==2&&length(goal-unit.position)>.001f;
        if(unit.approach_ready){const auto* building=external_target(unit);unit.approach_target=building->id;unit.approach_minimum=building->minimum;unit.approach_maximum=building->maximum;}
        return true;
    };
    bool selected=false;
    if(taunt_row_>=0)selected=select(taunt_row_,0);
    if(!selected)if(auto taunt=crowd.unit(first_taunt_);taunt&&taunt->buff_left>0)selected=select(-1,taunt->handle);
    if(!selected&&unit.retaliation>0){
        auto found=crowd.ids_.find(unit.retaliation_source);
        if(found!=crowd.ids_.end()){
            auto& other=crowd.units_[found->second];
            if(other.alive&&other.team==1&&other.shelter_mode!=2&&horizontal(other.position,unit.position)<28)selected=select(-1,other.handle);
        }
        if(!selected)for(auto row:target_groups_[3])if(targets_[row].id==unit.retaliation_source&&horizontal(targets_[row].foot,unit.position)<28){selected=select(int(row),0);if(selected)break;}
        if(!selected&&hero_row_>=0&&horizontal(targets_[hero_row_].foot,unit.position)<=28)selected=select(hero_row_,0);
    }
    float score=INFINITY;int priority=-1;
    if(!selected){
        bool assault=std::any_of(target_groups_[2].begin(),target_groups_[2].end(),[&](size_t row){return targets_[row].assault_priority>0;});
        target_candidates_.clear();
        for(int kind:{2,1,3})for(auto row:target_groups_[kind]){
            const auto& other=targets_[row];
            Vec3 point=kind==2?Vec3{std::clamp(unit.position.x,other.minimum.x,other.maximum.x),other.minimum.y,std::clamp(unit.position.z,other.minimum.z,other.maximum.z)}:other.foot;
            float distance=horizontal(unit.position,point);
            int rank=kind==2?other.assault_priority:assault&&distance<=28?3:0;
            target_candidates_.push_back({int(row),0,distance,rank});
        }
        if(hero_row_>=0&&horizontal(targets_[hero_row_].foot,unit.position)<=28)target_candidates_.push_back({hero_row_,0,horizontal(targets_[hero_row_].foot,unit.position),3});
        std::stable_sort(target_candidates_.begin(),target_candidates_.end(),[](const TargetCandidate& a,const TargetCandidate& b){return a.priority!=b.priority?a.priority>b.priority:a.distance<b.distance;});
        for(auto candidate:target_candidates_)if(select(candidate.row,0)){score=candidate.distance;priority=candidate.priority;selected=true;break;}
        auto best_handle=unit.target_handle;auto best_id=unit.external_target;int best_kind=unit.external_kind;Vec3 best_goal=unit.target_goal;
        if(crowd.counts_[1]>0){
            float extent=priority>0?28:std::max(28.0f,std::isfinite(score)?score:3e8f);
            for(float radius=std::min(28.0f,extent);;radius=std::min(radius*2,extent)){
                Vec3 pad{radius,3e8f,radius};target_candidates_.clear();
                for(auto handle:crowd.query(unit.position-pad,unit.position+pad,1,false)){
                    auto other=crowd.unit(handle);if(!other||other->shelter_mode==2)continue;
                    float distance=horizontal(unit.position,other->position);int rank=assault&&distance<=28?3:0;
                    if(rank<priority||(rank==priority&&distance>=score))continue;
                    target_candidates_.push_back({-1,handle,distance,rank});
                }
                std::sort(target_candidates_.begin(),target_candidates_.end(),[&](const TargetCandidate& a,const TargetCandidate& b){return a.distance!=b.distance?a.distance<b.distance:crowd.unit(a.handle)->logical_id<crowd.unit(b.handle)->logical_id;});
                for(auto candidate:target_candidates_)if(select(-1,candidate.handle)){
                    score=candidate.distance;priority=candidate.priority;selected=true;
                    best_handle=unit.target_handle;best_id=unit.external_target;best_kind=unit.external_kind;best_goal=unit.target_goal;break;
                }
                if(priority>0||score<=radius||radius>=extent)break;
            }
        }
        unit.target_handle=best_handle;unit.external_target=best_id;unit.external_kind=best_kind;unit.target_goal=best_goal;
        if(!selected&&hero_row_>=0)selected=select(hero_row_,0);
    }
    if(!selected){unit.target_handle=0;unit.external_kind=-1;unit.has_goal=false;}
    if(unit.target_handle!=previous_handle||unit.external_target!=previous_id||unit.external_kind!=previous_kind)unit.routing=false;
}
void Combat::attack_started(const Unit& unit){
    Event event;event.kind=ATTACK_STARTED;event.source_id=unit.logical_id;event.unit_kind=unit.kind;event.team=unit.team;emit(event);
}
void Combat::begin(Unit& unit){
    unit.action_active=true;unit.just_started=true;unit.phase_tick=0;unit.attack_tick=0;unit.action_time=0;unit.soldier_shots=0;
    unit.primary_hit=false;
    unit.soldier_phase=int(soldiers_[unit.kind].kit[17]);unit.action=data_.actions[unit.soldier_phase+1];unit.has_goal=false;
    attack_started(unit);
}
void Combat::before_move(Crowd& crowd,double delta){
    if(!enabled_)return;
    threats_.clear();mirror_targets_.clear();first_taunt_=0;latest_taunt_=0;
    for(const auto& u:crowd.units_)if(u.alive){
        if(u.mirror_actions>0&&u.target_handle)mirror_targets_.push_back(u.target_handle);
        if(u.team==0&&u.action_active&&u.target_handle)threats_.insert(u.target_handle);
        if(u.team==1&&u.kind==7&&u.buff_left>0&&u.shelter_mode==0&&(!first_taunt_||u.handle<first_taunt_))first_taunt_=u.handle;
    }
    for(auto& u:crowd.units_){
        if(!u.alive)continue;
        double frozen=u.frozen;u.frozen=std::max(0.0,u.frozen-delta);u.live_delta=std::max(0.0,delta-frozen);
        double dt=u.live_delta;u.retaliation=std::max(0.0,u.retaliation-dt);u.invuln=std::max(0.0,u.invuln-dt);u.stun=std::max(0.0,u.stun-dt);u.slow_left=std::max(0.0,u.slow_left-dt);
        if(u.slow_left<=0)u.slow_factor=1;
        u.status=(u.frozen>0?data_.status_bits[0]:0)|(u.slow_left>0?data_.status_bits[1]:0)|(u.stun>0?data_.status_bits[2]:0)|(u.invuln>0?data_.status_bits[3]:0);
        if(u.mirror_actions>0){mirror_decide(crowd,u,dt);continue;}
        if(u.team==0&&u.kind==4&&!data_.skullpion.empty()){boss_decide(crowd,u,dt);continue;}
        if(u.team==0&&u.kind==18&&!data_.finale_meta.empty()){finale_decide(crowd,u,dt);continue;}
        if(u.team==0&&u.kind==17&&!data_.dark_lumina.empty()){lumina_decide(crowd,u,dt);continue;}
        if(u.team==1&&u.kind>=0&&u.kind<int(allies_.size())&&allies_[u.kind].active){if(!shelter(crowd,u,dt))ally_decide(crowd,u,dt);continue;}
        if(u.team!=0||u.kind<0||u.kind>=19||!soldiers_[u.kind].active||dt<=0)continue;
        if(u.stun>0){u.action=data_.actions[6];continue;}
        if(u.action_active){u.has_goal=false;continue;}
        u.action=data_.actions[0];u.think_left-=dt;
        Vec3 foot;
        if(u.think_left<=0||((u.target_handle||u.external_kind>=0)&&!target(crowd,u,foot))){choose_target(crowd,u);u.think_left=.1;}
        if(!target(crowd,u,foot)){u.has_goal=false;continue;}
        const auto& profile=soldiers_[u.kind];Vec3 direction=foot-u.position;
        float desired=std::atan2(-direction.x,-direction.z),turn=std::remainder(desired-u.yaw,float(2*M_PI));
        float amount=profile.turn_speed*float(dt);u.yaw+=std::clamp(turn,-amount,amount);
        bool facing=std::abs(std::remainder(desired-u.yaw,float(2*M_PI)))<.35f;
        bool reach=u.kind==1?gun_contact(crowd,u):horizontal(u.position,foot)<=profile.range&&std::abs(foot.y-u.position.y)<=3.5f&&melee_contact(crowd,u);
        if(facing&&reach){begin(u);continue;}
        crowd.set_goal(u.handle,u.target_goal,profile.speed);
    }
    // Multiple Codes in one frame coalesce to one retarget pass. A later Code
    // wins immediately; ordinary reacquisition still picks the oldest taunter.
    if(latest_taunt_)for(auto& u:crowd.units_)if(u.alive&&u.team==0&&u.kind>=0&&u.kind<19&&soldiers_[u.kind].active){u.target_handle=latest_taunt_;u.external_kind=-1;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.has_goal=false;u.routing=false;u.think_left=0;}
}
void Combat::mirror_decide(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    u.mirror_wait=std::max(0.0,u.mirror_wait-dt);
    if(u.stun>0||u.mirror_busy){u.has_goal=false;return;}
    u.think_left-=dt;
    auto victim=crowd.unit(u.target_handle);
    if(!victim||victim->hp<=0||u.think_left<=0){
        auto claim=std::find(mirror_targets_.begin(),mirror_targets_.end(),u.target_handle);
        if(claim!=mirror_targets_.end())mirror_targets_.erase(claim);
        u.think_left=.2;u.target_handle=0;float best=INFINITY;Vec3 pad{52,60,52};
        for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
            auto other=crowd.unit(h);if(!other||other->hp<=0)continue;
            Vec3 point=enemy_contact(*other,u.position+Vec3{0,1,0});float gap=dot(point-u.position,point-u.position);
            // Prefer nearby unclaimed enemies without excluding a lone target.
            float score=gap+36*std::count(mirror_targets_.begin(),mirror_targets_.end(),h);
            if(gap<48*48&&score<best&&crowd.allied_terrain.ray_clear(u.position+Vec3{0,1,0},point)){best=score;u.target_handle=h;}
        }
        victim=crowd.unit(u.target_handle);
        if(victim)mirror_targets_.push_back(u.target_handle);
    }
    if(!victim){u.has_goal=false;return;}
    Vec3 goal=enemy_contact(*victim,u.position+Vec3{0,1,0});
    Vec3 approach=enemy_contact(*victim,victim->position+u.mirror_approach*100+Vec3{0,1,0})+u.mirror_approach;
    auto& ground=crowd.allied_terrain;
    int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    bool flank=layer>=0&&ground.clear(approach,u.radius,layer)&&ground.ray_clear(approach+Vec3{0,1,0},goal);
    Vec3 offset=goal-u.position;offset.y=0;u.yaw=std::atan2(offset.x,offset.z);
    if(length(offset)<=u.mirror_reach&&(!flank||horizontal(u.position,approach)<.6f)){
        u.has_goal=false;
        if(u.mirror_wait<=0){
            int choice=std::min(u.mirror_actions-1,int(random(u)*u.mirror_actions));
            Event event;event.kind=STATUS_EVENT;event.team=1;event.unit_kind=u.kind;event.source_id=u.logical_id;event.target_id=victim->logical_id;event.ticket_id=u.handle;event.position=goal;event.action_index=400+choice;emit(event);
            u.mirror_wait=.35+double((u.rng>>16)%500)/1000;
        }
    }else crowd.set_goal(u.handle,flank?approach:goal,u.mirror_speed);
}
void Combat::deliver(Crowd& crowd,const Unit& unit,double amount,bool projectile,Vec3 origin){
    amount*=unit.enemy_damage_scale;
    if(unit.target_handle){Vec3 foot;target(crowd,unit,foot);Hit hit;hit.source_id=unit.logical_id;hit.amount=amount;hit.projectile=projectile;hit.direction=normalized(foot-origin);this->hit(crowd,unit.target_handle,hit);}
    else{
        Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=unit.kind;event.action_index=unit.action;event.source_id=unit.logical_id;event.target_id=unit.external_target;event.external_kind=unit.external_kind;event.position=origin;event.amount=amount;event.projectile=projectile;emit(event);
    }
}
void Combat::advance(Crowd& crowd,Unit& u,double delta){
    if(u.just_started){u.just_started=false;return;}
    double remaining=delta*30;
    while(u.action_active&&remaining>1e-9){
        const auto& kit=soldiers_[u.kind].kit;
        int phase=u.soldier_phase;double duration=kit[phase],before=u.phase_tick;
        double step=std::min(remaining,std::max(0.0,duration-before)),after=before+step,start=u.attack_tick-before;
        auto marker=[&](double tick,EventKind kind){
            if(!(before+1e-8<tick&&after+1e-8>=tick))return;
            Event event;event.kind=kind;event.source_id=u.logical_id;event.source_tick=start+tick;event.target_id=u.target_handle?crowd.unit(u.target_handle)?crowd.unit(u.target_handle)->logical_id:0:u.external_target;event.position=u.position;event.unit_kind=u.kind;
            if(kind==MELEE){emit(event);if(soldiers_[u.kind].contact_end==0&&melee_contact(crowd,u))deliver(crowd,u,soldiers_[u.kind].damage,false,u.position);}
            else{
                event.position=u.position+rotated_y(data_.muzzle,u.yaw);
                if(kind==MUZZLE){emit(event);return;}
                if(!gun_contact(crowd,u))return;
                Vec3 foot;target(crowd,u,foot);Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=u.kind;shot.position=event.position;shot.direction=normalized(foot+Vec3{0,1.3f,0}-shot.position);shot.life=data_.bullet_life;shot.speed=data_.bullet_speed;shot.tail=data_.bullet_tail;shot.radius=data_.bullet_radius;shot.damage=soldiers_[u.kind].damage*u.enemy_damage_scale;shot.source_team=0;shot.scale=data_.enemy_size;shot.target_kind=u.external_kind;shot.target_id=u.external_target;
                for(const auto& ext:targets_)if(ext.id==u.external_target&&ext.kind==u.external_kind){shot.ignore_building=ext.ignore_building;break;}
                projectiles_.push_back(shot);event.projectile_id=shot.id;event.direction=shot.direction;event.amount=shot.damage;emit(event);
            }
        };
        if(phase==MELEE_A)marker(kit[5],MELEE);
        else if(phase==MELEE_B)marker(kit[6],MELEE);
        else if(phase==FIRE){marker(kit[7],MUZZLE);marker(kit[8],BULLET);}
        // A source active window can catch a late arrival, but never hit twice.
        if(phase==MELEE_A&&!u.primary_hit&&soldiers_[u.kind].contact_end>0&&before<soldiers_[u.kind].contact_end&&after+1e-8>=kit[5]&&melee_contact(crowd,u)){
            u.primary_hit=true;deliver(crowd,u,soldiers_[u.kind].damage,false,u.position);
        }
        u.phase_tick=after;u.attack_tick+=step;u.action_time=u.phase_tick/30;remaining-=step;
        if(after+1e-8<duration)break;
        if(phase==MELEE_A&&kit[18]>0&&melee_contact(crowd,u))u.soldier_phase=PREPARE;
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
    for(size_t index=start;index<projectiles_.size();++index){auto shot=std::move(projectiles_[index]);
        if(shot.owner_kind==8&&shot.source_team==1){
            dragon_flight(crowd,shot,delta);
            if(shot.age+1e-8<shot.life)projectiles_[count++]=std::move(shot);
            continue;
        }
        if(shot.owner_kind==18&&shot.effect_kind==3&&shot.power){
            double before=shot.age;shot.age+=delta;
            if(int(before/.4)!=int(shot.age/.4)){
                float radius=2*shot.radius;Vec3 pad{radius,2,radius};
                for(auto handle:crowd.query(shot.position-pad,shot.position+pad,1)){
                    auto victim=crowd.unit(handle);if(!victim||!body_contact(shot.position,shot.position,victim->position,radius)||!crowd.terrain.ray_clear(shot.position+Vec3{0,1,0},victim->position+Vec3{0,1,0}))continue;
                    Hit damage;damage.amount=shot.damage;damage.source_id=shot.source_id;damage.projectile=true;hit(crowd,handle,damage);
                }
                for(const auto& victim:targets_)if(victim.kind==0&&victim.hp>0&&victim.targetable&&body_contact(shot.position,shot.position,victim.foot,radius)&&crowd.terrain.ray_clear(shot.position+Vec3{0,1,0},victim.foot+Vec3{0,1,0})){
                    Event e;e.kind=EXTERNAL_DAMAGE;e.unit_kind=18;e.source_id=shot.source_id;e.target_id=victim.id;e.external_kind=0;e.position=shot.position;e.amount=shot.damage;e.projectile=true;emit(e);
                }
            }
            if(shot.age<shot.life)projectiles_[count++]=shot;
            continue;
        }
        if(shot.life<=0){Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=shot.source_team;event.unit_kind=shot.owner_kind;emit(event);continue;}
        float elapsed=float(std::min(delta,std::max(0.0,shot.life-shot.age)));
        Vec3 before=shot.position;shot.age+=elapsed;
        if(shot.owner_kind==18&&shot.effect_kind==3&&shot.age-elapsed<8.0/30&&shot.age>=8.0/30){Event e;e.kind=STATUS_EVENT;e.unit_kind=18;e.source_id=shot.source_id;e.action_index=314;e.position=shot.position;emit(e);}
        if(shot.ranger){shot.distance=std::min(shot.range,shot.distance+shot.speed*elapsed);shot.position=shot.origin+shot.direction*shot.distance;if(shot.curved&&shot.range>.001f)shot.position=shot.position+shot.curve*std::sin(float(M_PI)*shot.distance/shot.range);}
        else {
            if(shot.owner_kind==17&&shot.source_team==0&&shot.age>.4&&shot.age<shot.life-.53){
                Vec3 aim=shot.origin;
                if(shot.age>.8){
                    if(auto victim=crowd.unit(shot.target_handle))aim=victim->position+Vec3{0,1,0};
                    else if(shot.target_kind==0&&hero_row_>=0)aim=targets_[hero_row_].foot+Vec3{0,1,0};
                }
                Vec3 desired=normalized(aim-shot.position);float angle=std::acos(std::clamp(dot(shot.direction,desired),-1.f,1.f));
                float turn=float(data_.dark_lumina[10]*(shot.age>.8?2.25:.75)*elapsed);
                if(angle>1e-5f){float fraction=std::min(1.f,turn/angle);shot.direction=normalized(shot.direction*(1-fraction)+desired*fraction);}
            }
            shot.position=shot.position+shot.direction*(shot.speed*elapsed);
        }
        if(shot.owner_kind==4&&shot.source_team==0){
            shot.position.y+=shot.vertical_speed*elapsed;shot.vertical_speed-=30*elapsed;
            float floor=float(crowd.terrain.height(shot.position.x,shot.position.z))+3;
            if(std::isfinite(floor)&&shot.position.y<floor){
                shot.position.y=floor;shot.vertical_speed=12;
                Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=4;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.amount=1;emit(event);
            }
        }
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
                    if(shot.cast){auto& c=*shot.cast;c.rng^=c.rng>>12;c.rng^=c.rng<<25;c.rng^=c.rng>>27;if(double((c.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<c.critical){hit.amount*=2;hit.critical=true;}}
                    if(this->hit(crowd,chosen,hit).accepted&&shot.cast){if(auto owner=crowd.unit(shot.cast->owner)){owner->chain_left=1.75;if(!shot.cast->confirmed){shot.cast->confirmed=true;++owner->chain_count;}}}
                    shot.position=before+(shot.position-before)*nearest;impacted=true;
                }
            }
            if(impacted||shot.age>=shot.life){Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=1;event.unit_kind=shot.owner_kind;emit(event);}else projectiles_[count++]=shot;
            continue;
        }
        bool impacted=!crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.ignore_building);
        if(shot.owner_kind==18&&!shot.power&&(shot.effect_kind==2||shot.effect_kind==3)){
            float floor=float(crowd.terrain.height(shot.position.x,shot.position.z));
            if(std::isfinite(floor)&&shot.position.y<=floor+.2f){shot.position.y=floor+.2f;impacted=true;}
        }
        auto external_hit=[&](const ExternalTarget& victim){Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=shot.owner_kind;if(shot.owner_kind==4){event.action_index=108;event.heavy=true;}if(shot.owner_kind==18)event.action_index=300+shot.effect_kind;event.source_id=shot.source_id;event.target_id=victim.id;event.external_kind=victim.kind;event.position=before;event.amount=shot.damage;event.projectile=true;event.direction=shot.direction;emit(event);};
        if(impacted&&shot.target_kind==2&&crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.target_id))
            for(const auto& victim:targets_)if(victim.kind==2&&victim.id==shot.target_id&&victim.hp>0){external_hit(victim);break;}
        Vec3 tail=shot.position-shot.direction*shot.tail;
        if(!impacted)for(const auto& victim:targets_)if(victim.kind==0&&victim.hp>0&&victim.targetable&&(victim.body_bounds()?box_segment(before,shot.position,victim.minimum,victim.maximum,shot.radius)>=0:body_contact(tail,shot.position,victim.foot,shot.radius))){external_hit(victim);impacted=true;break;}
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
        if(impacted||shot.age>=shot.life){
            Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.action_index=shot.effect_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.direction=shot.direction;if(shot.owner_kind==18&&(shot.effect_kind==0||shot.effect_kind==2)&&shot.power)event.source_tick=1;emit(event);
            if(shot.owner_kind==18&&!shot.power&&shot.effect_kind==2&&shot.finale_burst){
                for(int i=0;i<8;++i){auto child=shot;child.id=next_projectile_++;child.power=true;child.age=0;child.life=data_.finale_ranges[3];child.speed=8*data_.finale_scale;child.damage*=.5;child.position.y+=.4f*data_.finale_scale*data_.enemy_size;child.direction={float(std::sin(i*2*M_PI/8)),0,float(std::cos(i*2*M_PI/8))};projectiles_.push_back(child);}
            }
            if(shot.owner_kind==18&&!shot.power&&shot.effect_kind==3){
                Vec3 from=shot.position+Vec3{0,.1f,0},to=shot.position-Vec3{0,float(data_.finale_ranges[2]),0};
                float fraction=crowd.terrain.projectile_fraction(from,to,0),floor=fraction>0?from.y+(to.y-from.y)*fraction:float(crowd.terrain.height(shot.position.x,shot.position.z));
                if(std::isfinite(floor))shot.position.y=floor;
                shot.power=true;shot.age=0;shot.life=2.7;shot.speed=0;shot.direction={};shot.position.y+=.25f*data_.finale_scale*data_.enemy_size;projectiles_[count++]=shot;
            }
        }
        else projectiles_[count++]=shot;
    }
    projectiles_.resize(count);
}
void Combat::after_move(Crowd& crowd,double delta){
    if(!enabled_)return;
    pulses(crowd,delta);
    for(auto& u:crowd.units_)if(u.alive&&u.team==0&&u.live_delta>0&&u.stun<=0&&u.action_active){if(u.kind==4&&!data_.skullpion.empty())boss_advance(crowd,u);else if(u.kind==17&&!data_.dark_lumina.empty())lumina_advance(crowd,u,u.live_delta);else if(u.kind==18&&!data_.finale_meta.empty())finale_advance(crowd,u,u.live_delta);else advance(crowd,u,u.live_delta);}
    projectiles(crowd,delta);
    counters(crowd,delta);
    size_t newborn_start=projectiles_.size();
    for(auto& u:crowd.units_)if(u.alive&&u.team==1&&u.kind>=0&&u.kind<int(allies_.size())&&allies_[u.kind].active&&u.live_delta>0&&u.stun<=0&&(u.shelter_mode==0||u.shelter_mode==4)){
        if(u.shelter_mode==4){if(u.just_landed){u.just_landed=false;if(u.landing_attack)dragoon_land(crowd,u);}continue;}
        if(u.kind==8&&u.just_landed){u.just_landed=false;if(u.landing_attack)dragoon_land(crowd,u);}
        else if(u.kind==8&&u.air_phase)continue;
        else if(u.kind==8&&u.action_active&&u.action==data_.actions[16])dragoon_advance(crowd,u,u.live_delta);
        else if(u.kind==31&&u.action_active&&u.action==data_.actions[9])blademaster_spin(crowd,u,u.live_delta);
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
    if(victim.kind>=0&&victim.kind<19&&soldiers_[victim.kind].active){
        const auto& k=soldiers_[victim.kind].kit;
        local.x=std::clamp(local.x,k[19],k[22]);local.y=std::clamp(local.y,k[20],k[23]);local.z=std::clamp(local.z,k[21],k[24]);
        return victim.position+rotated_y(local,victim.yaw);
    }
    float x=victim.kind==4?15:.576f*data_.enemy_size,y=victim.kind==4?25:2.016f*data_.enemy_size,z=victim.kind==4?20:1.152f*data_.enemy_size;
    local.x=std::clamp(local.x,-x,x);local.y=std::clamp(local.y,0.0f,y);local.z=std::clamp(local.z,-z,z);
    return victim.position+rotated_y(local,victim.yaw);
}
int64_t Combat::guard_enemy(Crowd& crowd,const Unit& u){
    Vec3 pad{u.guard_radius,u.guard_radius+60,u.guard_radius};
    int64_t chosen=0;float best=INFINITY;
    for(auto h:crowd.query(u.guard_post-pad,u.guard_post+pad,0)){
        auto enemy=crowd.unit(h);if(!enemy)continue;
        if(horizontal(enemy_contact(*enemy,u.guard_post+Vec3{0,1,0}),u.guard_post)>u.guard_radius)continue;
        float gap=length(enemy_contact(*enemy,u.position+Vec3{0,1,0})-u.position);
        if(gap<best){best=gap;chosen=h;}
    }
    return chosen;
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
        if(auto handle=guard_enemy(crowd,u)){u.target_handle=handle;u.appearance_started=true;u.appearance_left=.08;u.age=0;u.think_left=0;if(u.kind==8)u.position.y+=12;}
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
        if(u.guard_radius>0)u.target_handle=guard_enemy(crowd,u);
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
    if(u.kind==31&&u.opening&&!u.action_active&&gap<data_.blademaster[3]){
        u.opening=false;u.action_active=true;u.action=data_.actions[9];u.action_time=0;u.attack_tick=1;
        Event event;event.kind=STATUS_EVENT;event.team=1;event.unit_kind=31;event.source_id=u.logical_id;event.action_index=9;event.position=u.position;emit(event);
    }
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
    Event event;event.kind=MELEE;event.source_id=u.logical_id;event.unit_kind=u.kind;event.team=1;event.action_index=u.combo_serial%(u.kind==7?4:3);event.source_tick=attack.contact*30;event.amount=u.riposte_attack?std::round(attack.damage*data_.knight[K_RIPOSTE]):attack.damage;event.position=u.position;emit(event);
    float reach=float(attack.reach);Vec3 pad{reach+4,12,reach+4};bool connected=false;
    for(auto handle:crowd.query(u.position-pad,u.position+pad,0)){
        auto enemy=crowd.unit(handle);if(!enemy)continue;Vec3 point=enemy_contact(*enemy,u.position+Vec3{0,1,0}),offset=point-u.position;
        if(std::abs(offset.y)>3.5f||std::hypot(offset.x,offset.z)>reach||std::abs(std::remainder(std::atan2(offset.x,offset.z)-u.yaw,float(2*M_PI)))>attack.arc)continue;
        if(!crowd.terrain.ray_clear(u.position+Vec3{0,1,0},point))continue;
        Hit hit;hit.source_id=u.logical_id;hit.amount=u.attack_damage;hit.heavy=u.combo_serial%3==2||(u.kind==7&&u.combo_serial==3);hit.direction={std::sin(u.yaw),0,std::cos(u.yaw)};
        if(u.kind==5&&u.buff_left>0&&random(u)<data_.ninja[11]){
            double raw=enemy->kind==4?attack.damage+45:std::max(attack.damage,enemy->hp);
            hit.amount=raw*(u.attack_damage/attack.damage);
        }
        if(random(u)*100<profile.critical){hit.amount*=2;hit.critical=true;}
        if(this->hit(crowd,handle,hit).accepted){connected=true;if(!u.cast_confirmed){u.cast_confirmed=true;++u.chain_count;}u.chain_left=1.75;}
    }
    if(connected&&u.kind==5)u.pending_drift=u.combo_serial%3==2?2.5:1.25;
    // One confirmed finisher cue even when the swing hits a crowd.
    if(connected&&u.kind==7&&u.combo_serial==3){event.kind=STATUS_EVENT;event.action_index=18;emit(event);}
    return connected;
}
void Combat::blademaster_spin(Crowd& crowd,Unit& u,double dt){
    const auto& kit=data_.blademaster;
    u.action_time+=dt;
    while(u.attack_tick*kit[1]<=std::min(u.action_time,kit[0])+1e-8){
        ++u.attack_tick;
        float reach=float(kit[3]);Vec3 origin=u.position+Vec3{0,1.2f,0},pad{reach+4,12,reach+4};
        for(auto handle:crowd.query(u.position-pad,u.position+pad,0)){
            auto enemy=crowd.unit(handle);if(!enemy)continue;
            Vec3 point=enemy_contact(*enemy,origin);
            if(length(point-origin)>reach||!crowd.terrain.ray_clear(origin,point))continue;
            Hit hit;hit.source_id=u.logical_id;hit.amount=kit[2]*allies_[31].damage;hit.direction=normalized(point-origin);this->hit(crowd,handle,hit);
        }
    }
    if(u.action_time+1e-8>=kit[0]){u.action_active=false;u.action=data_.actions[0];u.action_time=0;}
}
void Combat::ally_advance(Crowd& crowd,Unit& u,double dt){
    const auto& profile=allies_[u.kind];const auto& attack=profile.primary[u.combo_serial%6];
    double tempo=u.kind==10?u.frame_tempo:ally_tempo(u);double before=u.action_time;u.action_time+=dt*tempo;
    if(!u.primary_hit&&u.action_time+1e-8>=attack.contact){u.primary_hit=true;if(u.kind==10){if(auto enemy=crowd.unit(u.target_handle))ranger_fire(crowd,u,enemy_contact(*enemy,u.position+Vec3{0,1,0}),false);}else if(ally_primary(crowd,u))u.hit_pause=attack.stop;}
    if(u.action_time+1e-8>=attack.duration){u.action_active=false;u.action=data_.actions[0];u.action_time=0;++u.combo_serial;if(u.kind==7)u.combo_serial%=4;}
}
}

namespace army {
double Combat::random(Unit& u){if(!u.rng)u.rng=uint64_t(u.logical_id)*0x9e3779b97f4a7c15ull;u.rng^=u.rng>>12;u.rng^=u.rng<<25;u.rng^=u.rng>>27;return double((u.rng*2685821657736338717ull)>>11)/9007199254740992.0;}
float Combat::enemy_segment(const Unit& victim,Vec3 from,Vec3 to,float radius) const{
    Vec3 a=rotated_y(from-victim.position,-victim.yaw),b=rotated_y(to-victim.position,-victim.yaw);
    Vec3 low{-.576f*data_.enemy_size,0,-1.152f*data_.enemy_size},high{.576f*data_.enemy_size,2.016f*data_.enemy_size,1.152f*data_.enemy_size};
    if(victim.kind==4){low={-15,0,-20};high={15,25,20};}
    else if(victim.kind>=0&&victim.kind<19&&soldiers_[victim.kind].active){
        const auto& k=soldiers_[victim.kind].kit;low={k[19],k[20],k[21]};high={k[22],k[23],k[24]};
    }
    return box_segment(a,b,low,high,radius);
}
void Combat::ninja_begin(Unit& u,Vec3 aim){
    u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);u.dash_direction={std::sin(u.yaw),0,std::cos(u.yaw)};u.dash_previous=u.position;
    u.special_time=0;u.action_time=0;u.action=data_.actions[9];u.action_active=true;u.primary_hit=false;u.cast_confirmed=false;u.motion_impulse={};u.action_hits.clear();
    u.skill_left=data_.ninja[6];u.invuln=std::max(u.invuln,data_.ninja[0]);u.attack_damage=data_.ninja[2]*allies_[5].damage*std::min(1.5,1.0+.05*u.chain_count);
}
bool Combat::move_special(Crowd& crowd,Unit& u,double dt,Vec3& next){
    if(enabled_&&u.team==0&&u.kind==18&&!data_.finale_meta.empty()&&(u.air_phase||(u.action==304&&u.action_active&&u.sweep_marker==0&&u.stun<=0))){
        if(!u.air_phase){u.air_phase=1;u.special_time=13;u.sweep_marker=1;}
        if(!u.action_active)u.special_time=std::min(0.0,u.special_time);
        u.special_time-=30*dt;
        auto moved=crowd.terrain.air_move(u.position,Vec3{0,float(u.special_time*dt),0},u.radius,2.5f*data_.finale_scale*data_.enemy_size,1.25f*data_.finale_scale*data_.enemy_size);
        next=moved.position;if(moved.floor){u.air_phase=0;u.support_layer=crowd.terrain.choose_layer(next);}return true;
    }
    if(enabled_&&u.team==0&&u.kind==18&&u.action_active&&u.stun<=0&&!data_.finale_meta.empty()){
        if(u.action==305&&((u.phase_tick>=51&&u.sweep_marker==0)||(u.phase_tick>=251&&u.sweep_marker==1))){
            bool valid=false;Vec3 goal=u.sweep_marker==0?u.landing_goal+Vec3{0,0,7}*(data_.finale_scale*data_.enemy_size):u.dash_previous;++u.sweep_marker;
            goal=crowd.terrain.landing(goal,goal.y+5,valid);int layer=crowd.terrain.choose_layer(goal);
            if(valid&&crowd.terrain.clear(goal,u.radius,layer)){next=goal;u.support_layer=layer;return true;}
        }
        float speed=finale_frame(u)[2];next=crowd.terrain.direct_move(u.position,Vec3{-std::sin(u.yaw),0,-std::cos(u.yaw)}*float(speed*dt),u.radius,u.support_layer);return true;
    }
    if(enabled_&&u.team==0&&u.kind==4&&!data_.skullpion.empty())return boss_move(crowd,u,dt,next);
    if(enabled_&&u.team==0&&u.kind==17&&!data_.dark_lumina.empty()&&(u.air_phase||(u.action_active&&u.soldier_phase==RELOAD&&u.stun<=0))){
        if(u.phase_tick>=22&&u.phase_tick<data_.dark_lumina[6]&&!u.air_phase&&u.special_time==0){u.air_phase=1;u.special_time=data_.dark_lumina[18];}
        if(u.air_phase){
            if(!u.action_active)u.special_time=std::min(0.0,u.special_time);
            else if(u.soldier_phase==RELOAD&&u.phase_tick>=38&&u.stun<=0)u.special_time=std::min(u.special_time,-data_.dark_lumina[18]);
            u.special_time-=(u.special_time>0?data_.dark_lumina[19]:data_.dark_lumina[20])*dt;
            const auto& k=soldiers_[17].kit;float height=k[23]-k[20];
            auto moved=crowd.terrain.air_move(u.position,Vec3{0,float(u.special_time*dt),0},float(2*data_.enemy_size*data_.dark_lumina[16]),height,height*.5f);
            next=moved.position;if(moved.floor){u.air_phase=0;u.just_landed=true;u.support_layer=crowd.terrain.choose_layer(next);}return true;
        }
    }
    if(enabled_&&u.team==0&&u.kind==17&&!data_.dark_lumina.empty()&&u.action_active&&u.soldier_phase==MELEE_A&&u.phase_tick<data_.dark_lumina[0]&&u.stun<=0){
        Vec3 foot;if(target(crowd,u,foot)){
            float travel=std::min(float(soldiers_[17].speed*2*data_.dark_lumina[16]*data_.dark_lumina[17]*dt),std::max(0.f,horizontal(u.position,foot)-3.8f*float(data_.dark_lumina[16])*data_.enemy_size));
            next=crowd.terrain.direct_move(u.position,Vec3{-std::sin(u.yaw),0,-std::cos(u.yaw)}*travel,u.radius,u.support_layer);return true;
        }
    }
    if(enabled_&&u.team==0&&u.kind>=0&&u.kind<19&&soldiers_[u.kind].active&&u.action_active&&u.stun<=0){
        const auto& kit=soldiers_[u.kind].kit;
        if(kit[16]>0&&u.phase_tick>=kit[5]&&u.phase_tick<kit[5]+7){
            next=crowd.terrain.direct_move(u.position,Vec3{-std::sin(u.yaw),0,-std::cos(u.yaw)}*float(kit[16]*dt),u.radius,u.support_layer);return true;
        }
    }
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
void Combat::boss_sand(Crowd& crowd,Unit& u){
    constexpr float reach=250,radius=28.8f;
    Vec3 direction{std::sin(u.yaw),0,std::cos(u.yaw)};
    Vec3 origin=u.position+Vec3{direction.x*15,5,direction.z*15};
    Vec3 end=origin+direction*reach;
    float wall=crowd.terrain.projectile_fraction(origin,end,0);
    // The shared projectile sweep has a 4 cm forward half extent; fit the beam to the surface.
    if(wall>=0)end=origin+direction*std::min(reach,reach*wall+.04f);
    float limit=dot(end-origin,direction);double amount=data_.skullpion[1]*.35*u.enemy_damage_scale;
    Vec3 pad{radius,radius,radius},low{std::min(origin.x,end.x),std::min(origin.y,end.y),std::min(origin.z,end.z)},high{std::max(origin.x,end.x),std::max(origin.y,end.y),std::max(origin.z,end.z)};
    auto exposed=[&](Vec3 point,int64_t ignore=-1){float along=dot(point-origin,direction);return along>=0&&along<=limit+.001f&&crowd.terrain.ray_clear(origin,point,ignore);};
    for(auto handle:crowd.query(low-pad,high+pad,1)){
        auto victim=crowd.unit(handle);if(!victim)continue;
        Vec3 point=victim->position+Vec3{0,1,0};
        if(!body_contact(origin,end,victim->position,radius)||!exposed(point))continue;
        Hit damage;damage.amount=amount;damage.source_id=u.logical_id;damage.direction=direction;hit(crowd,handle,damage);
    }
    for(const auto& victim:targets_){
        if(victim.hp<=0||!victim.targetable)continue;
        bool bounded=victim.kind==2||victim.body_bounds();
        float t=bounded?box_segment(origin,end,victim.minimum,victim.maximum,radius):-1;
        if(bounded?t<0:!body_contact(origin,end,victim.foot,radius))continue;
        Vec3 center=bounded?origin+(end-origin)*t:victim.foot+Vec3{0,1,0};
        Vec3 point=bounded?Vec3{std::clamp(center.x,victim.minimum.x,victim.maximum.x),std::clamp(center.y,victim.minimum.y,victim.maximum.y),std::clamp(center.z,victim.minimum.z,victim.maximum.z)}:center;
        if(!exposed(point,victim.kind==2?victim.id:-1))continue;
        Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=4;event.action_index=103;event.source_id=u.logical_id;event.target_id=victim.id;event.external_kind=victim.kind;event.position=point;event.direction=direction;event.amount=amount;event.projectile=true;emit(event);
    }
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
        if(random(u)*100<allies_[5].critical){hit.amount*=2;hit.critical=true;}
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
            Hit hit;hit.source_id=u.logical_id;hit.amount=u.attack_damage;hit.heavy=true;hit.direction={std::sin(u.yaw),0,std::cos(u.yaw)};if(random(u)*100<allies_[8].critical){hit.amount*=2;hit.critical=true;}
            if(this->hit(crowd,h,hit).accepted){u.hit_pause=std::max(u.hit_pause,d[D_SWEEP_STOP]);u.chain_left=1.75;if(!u.cast_confirmed){u.cast_confirmed=true;++u.chain_count;}}
        }
    }
    if(u.action_time+1e-8>=d[D_SWEEP_TIME]){u.action_active=false;u.action=data_.actions[0];u.action_time=0;}
}
void Combat::dragoon_land(Crowd& crowd,Unit& u){
    u.landing_left=.8;
    u.landing_attack=false;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.motion_impulse={};
    auto cast=std::make_shared<ProjectileCast>();cast->owner=u.handle;cast->critical=allies_[8].critical;cast->rng=uint64_t(u.logical_id)^uint64_t(serial_+1)*0x9e3779b97f4a7c15ull;
    const auto& d=data_.dragoon;
    Projectile dragon;dragon.id=next_projectile_++;dragon.source_id=u.logical_id;dragon.owner_kind=8;dragon.source_team=1;dragon.cast=cast;
    dragon.origin=dragon.position=u.position+Vec3{0,1.8f,0};dragon.direction={std::sin(u.yaw),0,std::cos(u.yaw)};
    dragon.life=d[D_HUNT_TIME];dragon.speed=float(d[D_HUNT_SPEED]);dragon.damage=u.attack_damage*d[D_HUNT_DAMAGE]/d[D_PULSE_DAMAGE];dragon.heavy=true;
    dragon.radius=float(d[D_HUNT_WIDTH]*d[D_RANGE]);dragon.range=float(d[D_HUNT_SEEK]*d[D_RANGE]);dragon.scale=float(d[D_HUNT_SCALE]*d[D_RANGE]);
    projectiles_.push_back(std::move(dragon));
    for(int i=0;i<3;++i){LandingPulse p;p.left=i*data_.dragoon[D_PULSE_INTERVAL];p.damage=u.attack_damage;p.position=u.position;p.radius=float(data_.dragoon[D_PULSE_RADIUS0+i]*data_.dragoon[D_RANGE]);p.index=i;p.source_id=u.logical_id;p.cast=cast;if(i==0)landing_pulse(crowd,p);else pulses_.push_back(p);}
}
void Combat::dragon_flight(Crowd& crowd,Projectile& shot,double delta){
    double remaining=std::min(delta,std::max(0.0,shot.life-shot.age));
    while(remaining>1e-8){
        double dt=std::min(remaining,1.0/60);remaining-=dt;shot.age+=dt;shot.dash_left-=dt;
        Vec3 before=shot.position;
        if(shot.dash_left<=1e-8){
            shot.dash_left=data_.dragoon[D_HUNT_DASH];shot.hits.clear();
            Vec3 pad{shot.range+4,shot.range+7,shot.range+4};double best=INFINITY;int64_t selected=0;
            float orbit=float(6*data_.dragoon[D_RANGE]);Vec3 aim=shot.origin+Vec3{std::sin(float(shot.age*5))*orbit,0,std::cos(float(shot.age*5))*orbit};
            for(auto h:crowd.query(before-pad,before+pad,0)){
                auto e=crowd.unit(h);if(!e)continue;Vec3 point=enemy_contact(*e,before);float gap=length(point-before);
                if(gap>=shot.range||!crowd.terrain.ray_clear(before,point))continue;
                double score=gap*gap+(h==shot.target_id?shot.range*shot.range:0);
                if(score<best){best=score;selected=h;aim=point;}
            }
            if(selected)shot.target_id=selected;
            shot.direction=normalized(aim-before);
        }
        Vec3 end=before+shot.direction*float(shot.speed*dt);
        float wall=crowd.terrain.projectile_fraction(before,end,shot.radius);
        if(wall>=0)end=before+(end-before)*wall;
        Vec3 pad{shot.radius+4,shot.radius+7,shot.radius+4},low{std::min(before.x,end.x),std::min(before.y,end.y),std::min(before.z,end.z)},high{std::max(before.x,end.x),std::max(before.y,end.y),std::max(before.z,end.z)};
        for(auto h:crowd.query(low-pad,high+pad,0)){
            auto e=crowd.unit(h);if(!e||std::find(shot.hits.begin(),shot.hits.end(),h)!=shot.hits.end())continue;
            float t=enemy_segment(*e,before,end,shot.radius);
            if(t<0||!crowd.terrain.ray_clear(before,enemy_contact(*e,before)))continue;
            shot.hits.push_back(h);
            Hit damage;damage.source_id=shot.source_id;damage.amount=shot.damage;damage.projectile=true;damage.heavy=true;damage.direction=shot.direction;
            auto& cast=*shot.cast;cast.rng^=cast.rng>>12;cast.rng^=cast.rng<<25;cast.rng^=cast.rng>>27;
            if(double((cast.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<cast.critical){damage.amount*=2;damage.critical=true;}
            if(hit(crowd,h,damage).accepted)if(auto owner=crowd.unit(cast.owner)){owner->chain_left=1.75;if(!cast.confirmed){cast.confirmed=true;++owner->chain_count;}}
        }
        shot.position=end;
        if(length(end-before)>.00001f)shot.flight_direction=normalized(end-before);
        if(wall>=0)shot.direction={};
    }
}
void Combat::landing_pulse(Crowd& crowd,const LandingPulse& p){
    Event event;event.kind=LANDING_PULSE;event.source_id=p.source_id;event.position=p.position;event.unit_kind=8;event.team=1;event.action_index=p.index;event.amount=data_.dragoon[D_PULSE_DAMAGE];emit(event);
    Vec3 pad{p.radius+4,p.radius+7,p.radius+4};
    for(auto h:crowd.query(p.position-pad,p.position+pad,0)){
        auto enemy=crowd.unit(h);if(!enemy)continue;Vec3 origin=p.position+Vec3{0,1,0},point=enemy_contact(*enemy,origin);
        if(length(point-p.position)>p.radius||!crowd.terrain.ray_clear(origin,point))continue;
        Hit hit;hit.source_id=p.source_id;hit.amount=p.damage;hit.projectile=true;hit.direction=normalized(enemy->position-p.position);
        auto& cast=*p.cast;cast.rng^=cast.rng>>12;cast.rng^=cast.rng<<25;cast.rng^=cast.rng>>27;if(double((cast.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<cast.critical){hit.amount*=2;hit.critical=true;}
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
                auto& cast=*c.cast;cast.rng^=cast.rng>>12;cast.rng^=cast.rng<<25;cast.rng^=cast.rng>>27;if(double((cast.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<cast.critical){hit.amount*=2;hit.critical=true;}
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
        if(u.team==1&&u.kind>=0&&u.kind<int(allies_.size())&&allies_[u.kind].active&&!data_.walk_cadence.empty()){
            if(u.live_delta>0&&!u.air_phase&&u.action!=data_.actions[9]&&speed>.001){double sample=std::min(160.0,speed*4);int low=int(sample),high=std::min(160,low+1);const auto& c=allies_[u.kind].cadence;u.walk_phase+=(c[low]+(c[high]-c[low])*(sample-low))*u.live_delta*2*M_PI;}
        }else if(!enabled_||u.team!=0||u.action==data_.actions[0]){
            double before=u.walk_phase/(2*M_PI)*80;
            u.walk_phase+=speed*(u.kind==17?u.live_delta:delta)/std::max(.001,stride)*2*M_PI;
            if(enabled_&&u.team==0&&u.kind==17&&!u.air_phase&&u.stun<=0&&speed>.1){
                double after=u.walk_phase/(2*M_PI)*80;
                for(int marker:{15,53})if(std::floor((after-marker)/80)>std::floor((before-marker)/80))lumina_event(u,14);
            }
        }
        refresh_status(u);
        pose_frame(u);
    }
}
void Combat::refresh_status(Unit& u) const{
    if(enabled_)u.status=(u.frozen>0?data_.status_bits[0]:0)|(u.slow_left>0?data_.status_bits[1]:0)|(u.stun>0?data_.status_bits[2]:0)|((u.invuln>0||(u.kind==8&&u.landing_attack))?data_.status_bits[3]:0)|(u.blocking?data_.status_bits[4]:0)|(u.buff_left>0?data_.status_bits[5]:0)|(u.shelter_mode==2?data_.status_bits[6]:0);
}
void Combat::pose_frame(Unit& u){
    if(!enabled_||u.team!=0||u.kind<0||u.kind>=19||!soldiers_[u.kind].active||data_.soldier_pose_meta.empty())return;
    if(u.kind==18&&u.action>=300&&u.action<306&&u.action_active&&!data_.finale_meta.empty()){u.pose_row=int(finale_frame(u)[0]);return;}
    if(u.kind==17&&u.action==LUMINA_SPIN_ACTION&&u.action_active){u.pose_row=int(data_.dark_lumina_spin[std::clamp(int(u.phase_tick+1e-6),0,27)*3+(u.chain_count==1?0:1)]);return;}
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
