#include "guardian_rules.h"
#include "combat.h"
#include "core.h"
#include <algorithm>
#include <numeric>

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
int bag_draw(uint64_t& remaining,uint64_t allowed,float draw){
    remaining&=allowed;if(!remaining)remaining=allowed;
    int count=0;for(int i=0;i<64;++i)if(remaining&(uint64_t(1)<<i))++count;
    int pick=std::min(count-1,int(draw*count));
    for(int i=0;i<64;++i)if(remaining&(uint64_t(1)<<i))if(pick--==0){remaining&=~(uint64_t(1)<<i);return i;}
    return -1;
}
constexpr float ZOMBIE_BLAST_RADIUS=8.f;
constexpr double ZOMBIE_FUSE=1.6,ZOMBIE_BLAST_DAMAGE=32,ZOMBIE_DRAIN_RATIO=.8;
constexpr double ENEMY_CHARGE_WINDUP_TIME=.8,ENEMY_CHARGE_RUSH_TIME=.82,ENEMY_CHARGE_RECOVERY_TIME=.55;
constexpr double REACTIVE_GUARD_TIME=.95,PRESSURE_GUARD_TIME=1.15,BLOCKED_HIT_GUARD_CAP=.85;
constexpr double ENEMY_GUARD_BREAK_TIME=.459,ENEMY_GUARD_BREAK_COOLDOWN=3.0,GUARD_BREAK_DAMAGE=1.2;
constexpr float ENEMY_CHARGE_SPEED=15.f;
float charge_contact(const Unit& u,const ExternalTarget& hero,Vec3 from,Vec3 to){
    const Vec3 front=u.dash_direction*std::max(.75f,u.radius*.9f)+Vec3{0,1,0};
    const Vec3 low=hero.body_bounds()?hero.minimum:hero.foot+Vec3{-.35f,.35f,-.35f};
    const Vec3 high=hero.body_bounds()?hero.maximum:hero.foot+Vec3{.35f,1.8f,.35f};
    return box_segment(from+front,to+front,low,high,std::clamp(u.radius*.8f,.55f,1.2f));
}
}
bool Combat::configure(KitData data,Crowd* crowd){
    const bool had_hounds=soldiers_[HOUND_KIND].active;
    const double previous_hound_hp=hound_health();
    enabled_=false;soldiers_={};allies_={};
    if(!valid_kit_data(data))return false;
    data_=std::move(data);nearest_revision_=UINT64_MAX;
    pet_query_padding_={};
    for(size_t i=0;i<data_.pet_geometry.size();i+=7){
        const auto* p=data_.pet_geometry.data()+i;
        float radius=std::hypot(std::max(std::abs(p[0]),std::abs(p[3])),std::max(std::abs(p[2]),std::abs(p[5])));
        pet_query_padding_.x=pet_query_padding_.z=std::max(pet_query_padding_.x,radius);
        pet_query_padding_.y=std::max(pet_query_padding_.y,std::max(std::abs(p[1]),std::abs(p[4])));
    }
    auto find_directional=[](const auto& attacks,auto& directional){
        directional.fill(false);
        if(attacks.empty())return;
        for(size_t skin=0;skin<directional.size();++skin){
            const auto* row=attacks.data()+skin*8*HOUND_TIMELINE_STRIDE;
            for(int direction=1;direction<8;++direction)
                directional[skin]|=!std::equal(row,row+HOUND_TIMELINE_STRIDE,row+direction*HOUND_TIMELINE_STRIDE);
        }
    };
    find_directional(data_.hound_attacks,hound_directional_);
    find_directional(data_.bear_attacks,bear_directional_);
    find_directional(data_.slime_attacks,slime_directional_);
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
    const auto& hound=soldiers_[HOUND_KIND];
    const double maximum=hound_health();
    if(crowd&&had_hounds&&hound.active&&previous_hound_hp!=maximum){
        for(auto& unit:crowd->units_)if(unit.alive&&unit.team==1&&unit.kind==HOUND_KIND){
            // Keep existing wounds when a card raises maximum health.
            unit.set_max_hp(maximum+unit.pet_health_bonus);
        }
    }
    if(crowd)for(const auto& unit:crowd->units_)if(unit.alive&&unit.body_scale!=1)include_body_bounds(unit);
    enabled_=true;return true;
}
void Combat::clear(){hound_approaches_.clear();hound_approach_units_.clear();pet_sequence_targets_.clear();hero_dodge_threat_={};skullpions_.clear();nearest_entries_.clear();nearest_nodes_.clear();nearest_revision_=UINT64_MAX;nearest_contact_tests_=0;nearest_position_reads_=0;projectiles_.clear();pulses_.clear();counters_.clear();threats_.clear();mirror_targets_.clear();first_taunt_=latest_taunt_=0;enemy_guard_break_owner_=0;enemy_guard_break_ready_=0;rescues_.clear();bodyguards_.clear();hero_rescuing_=false;hero_bodyguard_bag_=0;events_.clear();set_targets({});shelters_.clear();}
void Combat::spawned(Unit& u){if(enabled_&&u.team==1&&u.kind==8&&!data_.dragoon.empty())u.leap_left=data_.dragoon[D_LEAP_CD];if(enabled_&&u.shelter_mode==2)u.status|=data_.status_bits[6];if(pet_skin_count(u.kind))u.pose_row=0;if(u.team==1&&escort_kind(u.kind))u.pet_mana=data_.pet_mana;pose_frame(u);}
bool Combat::begin_enemy_arrival(Crowd& crowd,Handle handle){
    auto* u=crowd.unit(handle);if(!enabled_||!u||u->team!=0||!pet_skin_count(u->kind)||u->hp<=0)return false;
    if(u->action==GUARDIAN_ARRIVAL)return true;
    u->action=GUARDIAN_ARRIVAL;u->action_active=true;u->action_time=0;u->has_goal=false;
    u->velocity={};u->pose_velocity={};u->invuln=std::max(u->invuln,GUARDIAN_ARRIVAL_DURATION);u->hound_attack_direction=-1;
    Event e;e.kind=STATUS_EVENT;e.unit_kind=u->kind;e.source_id=u->logical_id;e.ticket_id=handle;e.position=u->position;e.action_index=GUARDIAN_ARRIVAL;e.amount=GUARDIAN_ARRIVAL_DURATION;emit(e);return true;
}
void Combat::emit(Event event){event.serial=++serial_;events_.push_back(event);}
bool Combat::rescue(Crowd& crowd,int64_t victim_handle,const Hit& incoming,const Event& external){
    if(incoming.intercepted||incoming.amount<=0||incoming.source_id<=0||incoming.guard_break||incoming.effect==7)return false;
    auto victim=crowd.unit(victim_handle);
    const auto* hero=hero_row_>=0?&targets_[hero_row_]:nullptr;
    if(!victim&&(!hero||hero->id!=0||hero->hp<=0||!hero->targetable))return false;
    auto source=crowd.ids_.find(incoming.source_id);
    if(source!=crowd.ids_.end()&&crowd.units_[source->second].team!=0)return false;
    const Vec3 foot=victim?victim->position:hero->foot;
    const float victim_radius=victim?victim->radius:.5f;
    Vec3 toward=normalized(Vec3{-incoming.direction.x,0,-incoming.direction.z});
    if(length(toward)<.001f)return false;
    struct Candidate {int64_t handle;float distance;};
    std::vector<Candidate> candidates;
    for(auto handle:bodyguards_)if(auto guard=crowd.unit(handle);guard&&handle!=victim_handle&&guard->hp>0&&guard->bodyguard_left<=0&&guard->frozen<=0&&guard->stun<=0&&guard->afflictions[1]<=0&&guard->afflictions[2]<=0&&guard->shelter_mode==0){
        if(std::none_of(guard->pet_skills.begin(),guard->pet_skills.end(),[](int skill){return skill==PET_BODYGUARD;}))continue;
        float distance=horizontal(guard->position,foot);
        if(distance<=12&&std::abs(guard->position.y-foot.y)<=3)candidates.push_back({handle,distance});
    }
    if(victim&&hero&&hero->id==0&&hero->bodyguard&&hero->hp>0&&hero->targetable&&!hero_rescuing_&&horizontal(hero->foot,foot)<=12&&std::abs(hero->foot.y-foot.y)<=3)
        candidates.push_back({0,horizontal(hero->foot,foot)});
    std::sort(candidates.begin(),candidates.end(),[](auto a,auto b){return a.distance!=b.distance?a.distance<b.distance:a.handle<b.handle;});
    auto& ground=crowd.allied_terrain;
    for(auto candidate:candidates){
        auto guard=crowd.unit(candidate.handle);
        const Vec3 from=guard?guard->position:hero->foot;
        const float radius=guard?guard->radius:.5f;
        Vec3 landing=foot+toward*std::max(.8f,radius*.5f);
        Vec3 pushed=foot-toward*(radius+victim_radius+1.f);
        int layer=ground.choose_layer(from),victim_layer=ground.choose_layer(foot);
        landing.y=float(ground.height(landing.x,landing.z,layer));pushed.y=float(ground.height(pushed.x,pushed.z,victim_layer));
        if(!finite(landing)||!finite(pushed)||std::abs(landing.y-foot.y)>2||std::abs(pushed.y-foot.y)>2||
           !ground.clear(landing,radius,layer)||!ground.clear(pushed,victim_radius,victim_layer)||
           !ground.ray_clear(from+Vec3{0,1,0},landing+Vec3{0,1,0})||
           length(ground.direct_move(from,landing-from,radius,layer)-landing)>.15f||
           length(ground.direct_move(foot,pushed-foot,victim_radius,victim_layer)-pushed)>.15f)continue;
        const int level=std::clamp(guard?guard->bodyguard_level:hero->bodyguard_level,1,30);
        if(!guard&&hero_bodyguard_bag_level_!=level){hero_bodyguard_bag_level_=level;hero_bodyguard_bag_=0;}
        Unit hero_rng;hero_rng.rng=hero_bodyguard_rng_;
        const double draw=random(guard?*guard:hero_rng);if(!guard)hero_bodyguard_rng_=hero_rng.rng;
        auto& bag=guard?guard->bodyguard_bag:hero_bodyguard_bag_;
        bool activates;
        if(level==1)activates=bag_draw(bag,3,draw)!=0;
        else{
            int remaining=int(bag&255),successes=int(bag>>8);
            if(!remaining){remaining=100;successes=49+level;}
            activates=std::min(remaining-1,int(draw*remaining))<successes;
            bag=uint64_t(remaining-1)|(uint64_t(successes-int(activates))<<8);
        }
        if(!activates)continue;
        Rescue pending;pending.guard=candidate.handle;pending.from=from;pending.to=landing;pending.hit=incoming;pending.hit.intercepted=true;pending.hit.counter=true;
        pending.hit.amount*=1-.01*(level-1);
        pending.external=external;pending.external.kind=EXTERNAL_DAMAGE;pending.external.external_kind=0;pending.external.target_id=0;
        pending.external.source_id=incoming.source_id;pending.external.amount=pending.hit.amount;pending.external.projectile=incoming.projectile;
        pending.external.direction=incoming.direction;pending.external.magical=incoming.magical;pending.external.intercepted=true;
        if(victim&&source!=crowd.ids_.end())pending.external.unit_kind=crowd.units_[source->second].kind;
        if(source!=crowd.ids_.end()){
            const auto& attacker=crowd.units_[source->second];
            if(attacker.action==ZOMBIE_DRAIN||(guardian(attacker)&&attacker.guardian_tech==8150)){
                pending.drain=attacker.handle;pending.external.ticket_id=attacker.handle;pending.external.action_index=ZOMBIE_DRAIN;
            }
        }
        Event start;start.kind=STATUS_EVENT;start.action_index=BODYGUARD_START;start.team=1;start.ticket_id=candidate.handle;
        start.source_id=guard?guard->logical_id:0;start.target_id=victim?victim->logical_id:0;start.position=from;start.direction=landing;start.amount=.18;emit(start);
        Event push=start;push.action_index=BODYGUARD_PUSH;push.ticket_id=victim_handle;push.position=foot;push.direction=pushed;emit(push);
        if(!victim){auto& moved=targets_[hero_row_];Vec3 shift=pushed-moved.foot;moved.foot=pushed;moved.minimum=moved.minimum+shift;moved.maximum=moved.maximum+shift;}
        // Displace the ally without cancelling its action or retained combo target.
        if(victim)crowd.set_pose(victim_handle,pushed,victim->yaw);
        if(guard){
            cancel_owned(*guard);pet_sequence_targets_.erase(guard->handle);
            guard->bodyguard_left=.18;guard->action_active=false;guard->action=0;guard->pet_skill=0;guard->pet_combo_left=0;guard->counter_active=guard->counter_pending=false;
            guard->has_goal=false;guard->velocity=guard->pose_velocity=guard->knockback=guard->motion_impulse={};guard->invuln=0;guard->dodge_left=0;guard->blocking=false;
            guard->yaw=std::atan2(-toward.x,-toward.z);
        }else hero_rescuing_=true;
        rescues_.push_back(pending);return true;
    }
    return false;
}
void Combat::external_hit(Crowd& crowd,Event event){
    if(event.external_kind==0&&event.target_id==0&&!event.intercepted){
        Hit hit;hit.source_id=event.source_id;hit.amount=event.amount;hit.projectile=event.projectile;hit.magical=magical_attack(event.unit_kind,event.action_index,event.projectile);
        hit.guard_break=event.action_index==GUARD_BREAK_HIT;hit.effect=event.action_index==GUARDIAN_FATAL?7:0;
        hit.direction=length(event.direction)>.001f?event.direction:hero_row_>=0?normalized(targets_[hero_row_].foot-event.position):Vec3{};
        if(rescue(crowd,0,hit,event))return;
    }
    emit(event);
}
void Combat::advance_rescues(Crowd& crowd,double delta){
    for(size_t i=0;i<rescues_.size();){
        auto& pending=rescues_[i];pending.left=std::max(0.,pending.left-delta);
        auto guard=crowd.unit(pending.guard);
        if(pending.guard&&(!guard||guard->hp<=0)){rescues_.erase(rescues_.begin()+i);continue;}
        if(guard){
            const float t=float(1-pending.left/.18);
            crowd.set_pose(guard->handle,pending.from+(pending.to-pending.from)*t+Vec3{0,float(std::sin(t*M_PI))*.8f,0},guard->yaw);
            guard->bodyguard_left=pending.left;
        }
        if(pending.left>0){++i;continue;}
        Rescue finished=pending;rescues_.erase(rescues_.begin()+i);
        if(guard){
            const double before=guard->hp;
            const auto result=hit(crowd,guard->handle,finished.hit);
            if(finished.drain&&result.accepted)confirm_zombie_drain(crowd,finished.drain,before-std::max(0.,result.hp));
            if(guard->hp>0){
                guard->target_handle=0;float nearest=24;Vec3 extent{24,5,24};
                for(auto handle:crowd.query(guard->position-extent,guard->position+extent,0,false)){
                    const auto* foe=crowd.unit(handle);if(!foe||foe->hp<=0||foe->shelter_mode==2)continue;
                    const float distance=horizontal(guard->position,foe->position);Vec3 goal;
                    if(distance<nearest&&pet_contact_goal(crowd,*guard,*foe,goal)){nearest=distance;guard->target_handle=handle;}
                }
                guard->bodyguard_followup=guard->target_handle!=0;guard->think_left=0;guard->hound_return_left=-1;
            }
        }else{hero_rescuing_=false;emit(finished.external);}
    }
}
bool Combat::habaru_boss(const Unit& u) const{
    return data_.habaru_bears&&u.team==0&&u.kind==SLIME_KIND&&u.pose_row==0;
}
bool Combat::habaru_decide(Crowd& crowd,Unit& u,double dt){
    if(!habaru_boss(u)||dt<=0)return false;
    u.habaru_control_left=std::max(0.0,u.habaru_control_left-dt);
    if(u.habaru_phase){
        u.has_goal=false;
        if(u.habaru_phase==2)return true;
        u.habaru_left=std::max(0.0,u.habaru_left-dt);
        if(u.habaru_phase==1){
            u.action_time+=dt;
            if(u.habaru_left<=0){u.blocking=false;u.guard_left=0;begin(u);u.action=HABARU_COUNTER;u.habaru_phase=2;}
        }else if(u.habaru_left<=0){
            u.habaru_phase=0;u.habaru_pressure=u.habaru_gap=0;u.think_left=0;
        }
        return true;
    }
    if(u.habaru_gap<=0)return false;
    u.habaru_gap=std::max(0.0,u.habaru_gap-dt);
    if(u.habaru_gap<=0){u.habaru_pressure=0;return false;}
    // Count shared pressure time, not hit count; a pet pack cannot force instant retaliation.
    if(u.habaru_control_left>0||u.frozen>0)return false;
    u.habaru_pressure+=dt;
    if(u.habaru_pressure+1e-8<1.8)return false;
    Vec3 foot;
    if(!target(crowd,u,foot)){choose_target(crowd,u);if(!target(crowd,u,foot))return false;}
    if(u.guard_radius>0&&horizontal(u.position,u.guard_post)>2*u.guard_radius)return false;
    u.yaw=std::atan2(u.position.x-foot.x,u.position.z-foot.z);
    u.habaru_phase=1;u.habaru_left=.85;u.habaru_pressure=u.habaru_gap=0;
    u.stun=0;u.knockback={};u.motion_impulse={};u.pending_drift=0;u.has_goal=false;
    u.blocking=true;u.guard_left=.85;
    u.action_active=false;u.action=HABARU_BRACE;u.action_time=0;u.action_hits.clear();
    u.hound_attack_direction=(int(std::round(std::remainder(hound_camera_yaw_-u.yaw,2*M_PI)*4/M_PI))+9)%8;
    zombie_cue(u,HABARU_BRACE,4.5,.85*30);
    return true;
}
bool Combat::zombie_boss(const Unit& u) const{
    return data_.zombie_boss&&u.team==0&&u.kind==SLIME_KIND&&u.pose_row==0;
}
bool Combat::grave_boss(const Unit& u) const{
    return data_.grave_boss&&u.team==0&&u.kind==SLIME_KIND&&u.pose_row==2;
}
int Combat::guardian(const Unit& u) const{
    if(!data_.cursed_guardian||u.team!=0||u.kind!=SLIME_KIND)return 0;
    if(data_.cursed_guardian<=5)return u.pose_row==2?data_.cursed_guardian:0;
    return u.pose_row==3?6:u.pose_row==4?7:0;
}
bool Combat::guardian_decide(Crowd& crowd,Unit& u,Vec3 foot){
    const int profile=guardian(u);
    if(!profile)return false;
    if(u.skill_left>0){u.has_goal=false;return true;}
    if(horizontal(u.position,foot)>19||
       !crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0}))return false;
    if(!u.guardian_tech){
        const Vec3 pad{49,5,49};bool partner=false;int attendants=0;double lowest=u.hp/u.max_hp;
        for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
            const auto* ally=crowd.unit(h);if(!ally||ally->hp<=0||ally->handle==u.handle||horizontal(ally->position,u.position)>49)continue;
            if(guardian(*ally))partner=true;else ++attendants;
            lowest=std::min(lowest,ally->hp/ally->max_hp);
        }
        uint16_t eligible=0;
        for(int i=0;i<10;++i){const auto& rule=GUARDIAN_RULES[profile-1][i];if(!rule.tech)continue;
            if(rule.tech==8850&&partner)continue;
            if(rule.tech==8652&&partner)continue;
            if(rule.tech==9301&&attendants>=9)continue;
            if(rule.tech==6104&&lowest>=.5)continue;
            if((rule.tech==6350||rule.tech==6602)&&lowest>=.8)continue;
            const int channel=rule.tech/100==55||rule.tech/100==57||rule.tech/100==59?0:1;
            if(rule.tech>=5500&&rule.tech<6100&&u.ruby_ward_left[channel]>0)continue;
            eligible|=1<<i;
        }
        if(eligible!=u.guardian_eligible){u.guardian_eligible=eligible;u.guardian_draws.clear();}
        if(u.guardian_draws.empty()){
            // Reference skill/chance columns; real-time eligibility replaces the unavailable BlueCG turn scheduler.
            for(int i=0;i<10;++i)if(eligible&(1<<i))for(int n=0;n<GUARDIAN_RULES[profile-1][i].chance;++n)u.guardian_draws.push_back(i);
            for(size_t n=u.guardian_draws.size();n>1;--n)std::swap(u.guardian_draws[n-1],u.guardian_draws[std::min(n-1,size_t(random(u)*n))]);
        }
        if(u.guardian_draws.empty())return false;
        const int slot=u.guardian_draws.back();u.guardian_draws.pop_back();u.guardian_tech=GUARDIAN_RULES[profile-1][slot].tech;u.guardian_hits=0;
        u.guardian_combo=u.guardian_tech==50?2+bag_draw(u.guardian_combo_draws,7,random(u)):1;
    }
    const int tech=u.guardian_tech;
    if(tech==7300||tech==50||tech==104||tech==105||tech==304||tech==305||tech==505||tech==8150)return false;
    u.action=GUARDIAN_CAST;u.action_active=true;u.action_time=0;u.has_goal=false;u.target_goal=foot;u.hound_attack_direction=-1;
    u.yaw=std::atan2(u.position.x-foot.x,u.position.z-foot.z);
    Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.action_index=GUARDIAN_CAST;
    e.position=foot;e.amount=tech;e.source_tick=60;emit(e);return true;
}
void Combat::guardian_status(Crowd& crowd,Unit& u,int status){
    const Vec3 pad{6,5,6};
    auto emit_status=[&](int64_t target,Vec3 point,int external){
        Event e;e.kind=STATUS_EVENT;e.source_id=u.logical_id;e.target_id=target;e.external_kind=external;
        e.unit_kind=u.kind;e.action_index=GUARDIAN_AFFLICTION+status;e.position=point;e.amount=4;emit(e);
    };
    auto success=[&](){return bag_draw(u.guardian_status_draws,15,random(u))==0;};
    for(auto h:crowd.query(u.target_goal-pad,u.target_goal+pad,1)){
        auto* ally=crowd.unit(h);if(!ally||ally->invuln>0||ally->avatar_left>0||horizontal(ally->position,u.target_goal)>6||
            !crowd.terrain.ray_clear(u.position+Vec3{0,1,0},ally->position+Vec3{0,1,0})||!success())continue;
        ally->afflictions[status]=4;ally->afflicted|=1<<status;if(status==4)ally->confusion_left=4;
        emit_status(ally->logical_id,ally->position,-1);
    }
    for(const auto& target:targets_)if(target.kind==0&&target.hp>0&&target.targetable&&horizontal(target.foot,u.target_goal)<=6&&
        crowd.terrain.ray_clear(u.position+Vec3{0,1,0},target.foot+Vec3{0,1,0})&&success())emit_status(target.id,target.foot,0);
}
void Combat::guardian_spell(Crowd& crowd,Unit& u,double delta){
    if((u.action_time+=delta)+1e-8<2)return;
    const int tech=u.guardian_tech;const int family=tech/100;
    if(family>=27&&family<=30){
        const double ratio=tech%100==2?96.:173.;
        boss_area(crowd,u,u.target_goal,6.f/data_.enemy_size,ratio,float(M_PI));
    }else if(family>=44&&family<=49)guardian_status(crowd,u,family-44);
    else if(tech==8652){
        const Vec3 pad{6,5,6};
        auto succeeds=[&](){return bag_draw(u.guardian_death_draws,1023,random(u))==0;};
        auto cue=[&](int64_t target,Vec3 point,int external,bool success){
            Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.target_id=target;e.external_kind=external;
            e.action_index=FALKEN_DEATH_EFFECT;e.position=point;e.amount=success;emit(e);
        };
        for(auto h:crowd.query(u.target_goal-pad,u.target_goal+pad,1)){
            auto* ally=crowd.unit(h);if(!ally||ally->invuln>0||ally->avatar_left>0||horizontal(ally->position,u.target_goal)>6||
                !crowd.terrain.ray_clear(u.position+Vec3{0,1,0},ally->position+Vec3{0,1,0}))continue;
            const bool success=succeeds();const auto point=ally->position;const auto target=ally->logical_id;
            if(success){Hit strike;strike.amount=ally->hp;strike.effect=7;strike.magical=true;strike.source_id=u.logical_id;hit(crowd,h,strike);}
            cue(target,point,-1,success);
        }
        for(const auto& target:targets_)if(target.kind==0&&target.hp>0&&target.targetable&&horizontal(target.foot,u.target_goal)<=6&&
            crowd.terrain.ray_clear(u.position+Vec3{0,1,0},target.foot+Vec3{0,1,0})){
            const bool success=succeeds();
            if(success){Event e;e.kind=EXTERNAL_DAMAGE;e.source_id=u.logical_id;e.target_id=target.id;e.external_kind=0;e.unit_kind=u.kind;e.action_index=GUARDIAN_FATAL;e.position=u.position;e.amount=target.hp;external_hit(crowd,e);}
            cue(target.id,target.foot,0,success);
        }
    }else if(tech==8850){zombie_cue(u,GRAVE_MAGIC_SEAL,6);}
    else if(tech==9301){zombie_cue(u,GUARDIAN_SUMMON,2);}
    else if(tech==1104||tech==1105){u.guardian_counter_left=4;u.counter_chance=tech==1104?.25:.30;}
    else if(tech==1000){u.guardian_magic_guard=3;}
    else if(tech==7400){u.guard_left=2;u.blocking=true;}
    else{
        const int alias=tech==850?RUBY_HOLY_SHIELD:family==55?RUBY_PHYSICAL_REFLECT:family==56?RUBY_MAGIC_REFLECT:
            family==57?RUBY_PHYSICAL_ABSORB:family==58?RUBY_MAGIC_ABSORB:family==59?RUBY_PHYSICAL_NULL:family==60?RUBY_MAGIC_NULL:
            tech==6104?RUBY_HEAL:tech==6350?RUBY_MEND:tech==6602?RUBY_GROUP_RECOVER:tech==3105?FALKEN_DRAIN:0;
        if(alias){u.action=alias;u.action_time=.99;ruby_spell(crowd,u,.02);
            if(tech==5950||tech==6050)u.ruby_ward_left[tech==5950?0:1]=10;
        }
    }
    Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.action_index=GUARDIAN_IMPACT;e.position=u.target_goal;e.amount=tech;emit(e);
    u.guardian_tech=0;u.skill_left=1.2;u.action_active=false;u.action=data_.actions[0];u.action_time=0;
}
void Combat::guardian_tick(Crowd& crowd,Unit& u,double delta){
    if(!u.afflicted&&!guardian(u))return;
    const double poisoned=std::min(delta,u.afflictions[0]);
    u.afflicted=0;for(int i=0;i<6;++i){auto& seconds=u.afflictions[i];const bool active=seconds>0;seconds=std::max(0.,seconds-delta);if(seconds>0)u.afflicted|=1<<i;
        else if(active){Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=e.target_id=u.logical_id;e.ticket_id=u.handle;e.external_kind=-1;e.action_index=GUARDIAN_AFFLICTION+i;e.position=u.position;emit(e);}
    }
    if(poisoned>0){u.poison_tick+=poisoned;while(u.poison_tick>=1){u.poison_tick-=1;Hit poison;poison.amount=u.max_hp*.025;poison.magical=true;poison.provoke=false;hit(crowd,u.handle,poison);}}
    else u.poison_tick=0;
    if(u.afflictions[1]>0||u.afflictions[2]>0){u.stun=std::max(u.stun,.05);u.has_goal=false;u.action_active=false;}
    if(u.afflictions[3]>0){u.slow_left=std::max(u.slow_left,.05);u.slow_factor=.55;u.attack_slow_left=std::max(u.attack_slow_left,.05);u.attack_slow_factor=.7;}
    if(u.guardian_counter_left>0){u.guardian_counter_left=std::max(0.,u.guardian_counter_left-delta);if(u.guardian_counter_left==0)u.counter_chance=0;}
    u.guardian_magic_guard=std::max(0.,u.guardian_magic_guard-delta);
    if(guardian(u)&&u.blocking){u.guard_left=std::max(0.,u.guard_left-delta);u.blocking=u.guard_left>0;}
}

bool Combat::ruby_boss(const Unit& u) const{
    return guardian(u)>0||((data_.ruby_boss||data_.falken_boss)&&u.team==0&&u.kind==SLIME_KIND&&u.pose_row==0);
}
bool Combat::undersea_boss(const Unit& u) const{
    return data_.undersea_boss&&u.team==0&&u.kind==SLIME_KIND&&u.pose_row==0;
}
void Combat::undersea_qigong(Crowd& crowd,Unit& u,double delta){
    double before=u.action_time;u.action_time+=delta;
    if(before<.75&&u.action_time>=.75){
        Vec3 origin=u.position+Vec3{0,2.1f,0};
        Vec3 direction=normalized(u.target_goal+Vec3{0,1.6f,0}-origin);
        for(int i=-1;i<=1;++i){
            Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;
            shot.owner_kind=SLIME_KIND;shot.effect_kind=UNDERSEA_QIGONG;shot.source_team=0;
            shot.direction=rotated_y(direction,i*.22f);shot.position=origin+shot.direction*1.4f;
            shot.speed=12;shot.life=2;shot.radius=1.65f;shot.scale=.82f;
            shot.damage=soldiers_[u.kind].damage*u.enemy_damage_scale;
            projectiles_.push_back(shot);
            Event event;event.kind=BULLET;event.unit_kind=u.kind;event.source_id=u.logical_id;
            event.projectile_id=shot.id;event.action_index=UNDERSEA_QIGONG;event.position=shot.position;
            event.direction=shot.direction;event.amount=shot.damage;event.source_tick=i+1;emit(event);
        }
    }
    if(u.action_time>=1.2){u.action_active=false;u.action=data_.actions[0];u.action_time=0;}
}
void Combat::undersea_support(Unit& u,double delta){
    u.action_time+=delta;
    const bool meditation=u.action==UNDERSEA_MEDITATION;
    if(u.action_time<(meditation?1.2:.5))return;
    if(meditation){
        const double restored=std::min(u.max_hp-u.hp,u.hp*.5);
        if(restored>0){u.hp+=restored;zombie_cue(u,ZOMBIE_HEAL,restored);}
    }else{
        u.buff_left=5.0;
        zombie_cue(u,UNDERSEA_HAZE,5.0);
    }
    u.action_active=false;u.action=data_.actions[0];u.action_time=0;
}
bool Combat::ruby_defense(Crowd& crowd,Unit& u,const Hit& incoming,HitResult& result){
    const int channel=incoming.magical?1:0;
    if(incoming.reflected||u.ruby_ward_left[channel]<=0||u.ruby_ward_hits[channel]<=0)return false;
    const int spell=u.ruby_ward[channel];
    --u.ruby_ward_hits[channel];
    if(u.ruby_ward_hits[channel]==0)u.ruby_ward_left[channel]=0;
    zombie_cue(u,RUBY_WARD_BLOCK,spell,u.ruby_ward_hits[channel]);
    if(spell==RUBY_PHYSICAL_ABSORB||spell==RUBY_MAGIC_ABSORB){
        const double healed=std::min(u.max_hp-u.hp,incoming.amount);
        if(healed>0){u.hp+=healed;zombie_cue(u,ZOMBIE_HEAL,healed);}
    }else if((spell==RUBY_PHYSICAL_REFLECT||spell==RUBY_MAGIC_REFLECT)&&incoming.amount>0){
        auto found=crowd.ids_.find(incoming.source_id);
        if(found!=crowd.ids_.end()&&crowd.units_[found->second].team!=u.team){
            auto& source=crowd.units_[found->second];
            Hit reply;reply.amount=incoming.amount;reply.magical=incoming.magical;reply.reflected=true;
            reply.counter=true;reply.source_id=u.logical_id;reply.direction=normalized(source.position-u.position);
            hit(crowd,source.handle,reply);
        }else if(incoming.provoke){
            for(const auto& source:targets_)if(source.kind==0&&source.id==incoming.source_id&&source.hp>0){
                Event e;e.kind=EXTERNAL_DAMAGE;e.source_id=u.logical_id;e.target_id=source.id;e.external_kind=0;
                e.unit_kind=u.kind;e.action_index=incoming.magical?RUBY_MAGIC_RETURN:RUBY_PHYSICAL_RETURN;
                e.position=u.position;e.direction=normalized(source.foot-u.position);e.amount=incoming.amount;external_hit(crowd,e);break;
            }
        }
    }
    result.hp=u.hp;
    return true;
}
// shortcut: Confusion reverses steering; recover random friendly-fire actions when original turn rules are integrated.
void Combat::ruby_confusion(Crowd& crowd,Unit& u){
    const float radius=5;
    const Vec3 pad{radius,5,radius};
    auto cue=[&](int64_t target,Vec3 point,int external){
        Event e;e.kind=STATUS_EVENT;e.source_id=u.logical_id;e.target_id=target;e.external_kind=external;
        e.unit_kind=u.kind;e.action_index=RUBY_CONFUSED;e.position=point;e.amount=4;emit(e);
    };
    for(auto h:crowd.query(u.target_goal-pad,u.target_goal+pad,1)){
        auto ally=crowd.unit(h);
        if(!ally||ally->invuln>0||ally->avatar_left>0||horizontal(ally->position,u.target_goal)>radius||
           std::abs(ally->position.y-u.target_goal.y)>5||!crowd.terrain.ray_clear(u.target_goal+Vec3{0,1,0},ally->position+Vec3{0,1,0}))continue;
        ally->confusion_left=4;cue(ally->logical_id,ally->position,-1);
    }
    for(const auto& target:targets_){
        if(target.kind!=0||target.hp<=0||!target.targetable)continue;
        Vec3 point=target.body_bounds()?Vec3{std::clamp(u.target_goal.x,target.minimum.x,target.maximum.x),
            std::clamp(u.target_goal.y,target.minimum.y,target.maximum.y),std::clamp(u.target_goal.z,target.minimum.z,target.maximum.z)}:target.foot;
        if(horizontal(point,u.target_goal)>radius||std::abs(point.y-u.target_goal.y)>5||
           !crowd.terrain.ray_clear(u.target_goal+Vec3{0,1,0},point+Vec3{0,1,0}))continue;
        cue(target.id,target.foot,0);
    }
}
void Combat::ruby_spell(Crowd& crowd,Unit& u,double delta){
    u.action_time+=delta;
    if(u.action_time<1.0)return;
    const int spell=u.action;
    if(spell==RUBY_FROST||spell==RUBY_METEOR){
        boss_area(crowd,u,u.target_goal,5.0f/data_.enemy_size,spell==RUBY_FROST?18.0:20.0,float(M_PI));
        Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;
        e.action_index=spell==RUBY_FROST?RUBY_FROST_IMPACT:RUBY_METEOR_IMPACT;e.position=u.target_goal;emit(e);
    }else if(spell==RUBY_CONFUSION){
        ruby_confusion(crowd,u);
    }else if(spell==FALKEN_SUMMON){
        zombie_cue(u,FALKEN_SUMMON_EFFECT,1+bag_draw(u.falken_family_draws,3,random(u)));
    }else if(spell==FALKEN_DRAIN||spell==FALKEN_DEATH){
        const double drain=guardian(u)==7?288:245;
        const bool success=spell==FALKEN_DRAIN||bag_draw(u.falken_death_draws,1023,random(u))==0;
        auto target=crowd.unit(u.target_handle);
        const int effect=spell==FALKEN_DRAIN?FALKEN_DRAIN_EFFECT:FALKEN_DEATH_EFFECT;
        if(target&&target->team!=u.team&&horizontal(target->position,u.position)<=19&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1,0},target->position+Vec3{0,1,0})){
            const auto point=target->position;const double before=target->hp;
            if(success){Hit strike;strike.amount=spell==FALKEN_DRAIN?drain:before;strike.magical=true;strike.source_id=u.logical_id;
                auto reply=hit(crowd,target->handle,strike);
                if(spell==FALKEN_DRAIN&&reply.accepted)confirm_zombie_drain(crowd,u.handle,before-std::max(0.0,reply.hp));}
            Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.target_id=target->logical_id;e.external_kind=-1;
            e.action_index=effect;e.position=point;e.amount=success;emit(e);
        }else for(const auto& target:targets_)if(target.kind==u.external_kind&&target.id==u.external_target&&target.hp>0&&target.targetable&&
            horizontal(target.foot,u.position)<=19&&crowd.terrain.ray_clear(u.position+Vec3{0,1,0},target.foot+Vec3{0,1,0})){
            if(success){Event e;e.kind=EXTERNAL_DAMAGE;e.unit_kind=u.kind;e.source_id=u.logical_id;e.target_id=target.id;e.external_kind=target.kind;
                e.action_index=spell;e.position=u.position;e.amount=spell==FALKEN_DRAIN?drain:target.hp;e.ticket_id=u.handle;external_hit(crowd,e);}
            Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.target_id=target.id;e.external_kind=target.kind;
            e.action_index=effect;e.position=target.foot;e.amount=success;emit(e);break;
        }
    }else if(spell==RUBY_HOLY_SHIELD){
        u.ruby_holy_left=3;zombie_cue(u,RUBY_WARD_ACTIVE,spell,3);
    }else if(spell>=RUBY_PHYSICAL_ABSORB&&spell<=RUBY_MAGIC_NULL){
        const int channel=(spell-RUBY_PHYSICAL_ABSORB)%2;
        u.ruby_ward[channel]=spell;u.ruby_ward_left[channel]=guardian(u)>0?3+bag_draw(u.guardian_ward_draws,3,random(u)):data_.falken_boss?4:3+int(random(u)*3);
        u.ruby_ward_hits[channel]=spell>=RUBY_PHYSICAL_NULL?2:1;
        zombie_cue(u,RUBY_WARD_ACTIVE,spell,u.ruby_ward_left[channel]);
    }else{
        std::vector<Unit*> party;
        const Vec3 pad{49,5,49};
        for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
            auto ally=crowd.unit(h);
            if(ally&&(guardian(u)>0||ally->kind==SLIME_KIND)&&horizontal(ally->position,u.position)<=49&&
               crowd.terrain.ray_clear(u.position+Vec3{0,1,0},ally->position+Vec3{0,1,0}))party.push_back(ally);
        }
        const bool group=spell==RUBY_MEND||spell==RUBY_GROUP_RECOVER;
        if(!group&&!party.empty()){
            auto best=*std::min_element(party.begin(),party.end(),[](auto a,auto b){return a->hp/a->max_hp<b->hp/b->max_hp;});
            party.assign(1,best);
        }
        for(auto ally:party){
            if(spell==RUBY_RECOVER||spell==RUBY_GROUP_RECOVER){
                ally->recover_left=group?10:6;ally->recover_tick=0;ally->recover_ratio=group?.0125:.025;
                zombie_cue(*ally,RUBY_RECOVER_TICK,ally->recover_left,guardian(u)?u.guardian_tech:0);
            }else{
                const double healed=std::min(ally->max_hp-ally->hp,ally->max_hp*(group?.06:.10));
                if(healed>0){ally->hp+=healed;zombie_cue(*ally,ZOMBIE_HEAL,healed);}
                zombie_cue(*ally,RUBY_HEAL_EFFECT,guardian(u)?u.guardian_tech:0);
            }
        }
    }
    ++u.ruby_casts;u.skill_left=u.ruby_casts%2?.35:2.25;
    u.action_active=false;u.action=data_.actions[0];u.action_time=0;
}

void Combat::zombie_cue(const Unit& u,int action,double amount,double tick){
    Event event;event.kind=STATUS_EVENT;event.unit_kind=u.kind;event.source_id=u.logical_id;
    event.action_index=action;event.position=u.position;event.amount=amount;event.hp=u.hp;event.source_tick=tick;emit(event);
}
void Combat::confirm_zombie_drain(Crowd& crowd,int64_t handle,double damage){
    auto u=crowd.unit(handle);
    if(!u||(!zombie_boss(*u)&&!grave_boss(*u)&&!((data_.falken_boss||guardian(*u)>0)&&ruby_boss(*u)))||!std::isfinite(damage)||damage<=0)return;
    double healed=std::min(u->max_hp-u->hp,damage*((data_.falken_boss||guardian(*u)>0)?1.0:ZOMBIE_DRAIN_RATIO));
    if(healed<=0)return;
    u->hp+=healed;zombie_cue(*u,ZOMBIE_HEAL,healed);
}
void Combat::zombie_explode(Crowd& crowd,Unit& u,double dt){
    u.action_time+=dt;
    if(u.action_time+1e-8<ZOMBIE_FUSE)return;
    zombie_cue(u,ZOMBIE_BLAST,ZOMBIE_BLAST_RADIUS);
    boss_area(crowd,u,u.position,ZOMBIE_BLAST_RADIUS/data_.enemy_size,ZOMBIE_BLAST_DAMAGE,float(M_PI));
    u.invuln=0;
    Hit sacrifice;sacrifice.amount=u.hp;sacrifice.source_id=u.logical_id;hit(crowd,u.handle,sacrifice);
}
HitResult Combat::hit(Crowd& crowd,int64_t handle,const Hit& incoming){
    auto u=crowd.unit(handle);if(!u)return {};
    HitResult result{false,false,u->hp};
    if(u->shelter_mode==2)return result;
    if(!std::isfinite(incoming.amount)||incoming.amount<0||!std::isfinite(incoming.status_seconds)||incoming.status_seconds<0)return result;
    if(u->action==GUARDIAN_ARRIVAL)return result;
    if(!incoming.intercepted&&u->team==1&&rescue(crowd,handle,incoming,{}))return {true,false,u->hp};
    const Vec3 incoming_flat{incoming.direction.x,0,incoming.direction.z};
    const auto frontal=[&]{return finite(incoming_flat)&&length(incoming_flat)>.001f&&
        dot(Vec3{std::sin(u->yaw),0,std::cos(u->yaw)},normalized(incoming_flat))>=.5f;};
    bool guarded=u->team==0&&u->blocking&&u->guard_left>0&&u->stun<=0&&u->frozen<=0&&frontal();
    const bool habaru=habaru_boss(*u);
    if(incoming.guard_break){
        const bool allied_guard=u->team==1&&u->blocking&&u->stun<=0&&u->frozen<=0;
        if((!guarded&&!allied_guard)||habaru)return result;
        guarded=false;u->blocking=false;u->guard_left=0;
    }
    if(u->avatar_left>0&&incoming.magical)return result;
    if(ruby_boss(*u)&&u->invuln<=0&&(incoming.amount>0||(incoming.magical&&incoming.status_seconds>0))&&ruby_defense(crowd,*u,incoming,result))return result;
    if(!incoming.intercepted&&incoming.amount>0&&u->dodge_chance>0&&incoming.source_id!=u->logical_id){
        if(u->dodge_left>0){queue_counter(crowd,*u,incoming);return result;}
        // Committed strikes and controlled bosses stay punishable; ordinary enemies have zero chance.
        if(u->dodge_cooldown<=0&&u->invuln<=0&&u->stun<=0&&u->frozen<=0&&!u->action_active&&!u->blocking&&random(*u)<u->dodge_chance){
            auto away=Vec3{incoming.direction.x,0,incoming.direction.z};
            u->dodge_direction=length(away)>.001f&&finite(away)?normalized(away):Vec3{std::sin(u->yaw),0,std::cos(u->yaw)};
            u->dodge_left=40.0/60;u->dodge_cooldown=3;
            queue_counter(crowd,*u,incoming);
            return result;
        }
    }
    if(undersea_boss(*u)&&u->buff_left>0&&u->action!=UNDERSEA_MEDITATION&&
       incoming.amount>0&&!incoming.magical&&random(*u)<.5){
        zombie_cue(*u,UNDERSEA_EVADE);
        return result;
    }
    bool knight=u->team==1&&u->kind==7&&allies_[7].active;
    if(knight&&incoming.amount>0){
        if(u->invuln>0)return result;
        if(u->action_active&&u->action==data_.actions[8]){const auto& a=allies_[7].primary[u->combo_serial%6];if(u->action_time>=a.contact-std::min(.04,a.contact*.6)&&u->action_time<a.contact+std::min(.035,a.contact*.5))return result;}
        if(u->blocking&&(dot(incoming.direction,incoming.direction)<=.001f||dot(Vec3{std::sin(u->yaw),0,std::cos(u->yaw)},normalized(incoming.direction))<=0)){
            if(u->buff_left>0)u->riposte=true;
            knight_counter(*u);return result;
        }
    }
    const bool reckless=u->kind==HOUND_KIND&&u->action_active&&u->action==HABARU_DOUBLE_EDGE;
    bool boss=u->team==0&&u->kind==4&&!data_.skullpion.empty();
    const bool control=incoming.status_seconds>0&&(incoming.effect==1||incoming.effect==4);
    if(u->counter_active&&control){
        u->counter_active=false;u->action_active=false;u->action=data_.actions[0];u->action_time=0;
    }
    if(habaru&&control){
        if(incoming.effect==4)u->habaru_control_left=std::max(u->habaru_control_left,incoming.status_seconds);
        if(u->habaru_phase)zombie_cue(*u,HABARU_RESET);
        u->habaru_phase=0;u->habaru_pressure=u->habaru_gap=u->habaru_left=0;
        u->blocking=false;u->guard_left=0;guarded=false;
        u->action_active=false;u->action=data_.actions[0];u->action_time=0;u->action_hits.clear();
    }
    const bool charging=u->counter_active||((u->action==ZOMBIE_CHARGE||u->action==GRAVE_EARTH_WARNING)&&u->action_active)||
        (habaru&&(u->habaru_phase==1||u->habaru_phase==2));
    const bool light_pressure=u->team==0&&incoming.amount>0&&incoming.joint_attack&&
        !incoming.heavy&&!incoming.projectile&&!incoming.magical&&!incoming.counter&&!control&&
        // A surrounding pet's rear hit must not erase a patroller's recovery window.
        incoming.flinch==0&&dot(incoming.impulse,incoming.impulse)==0&&(frontal()||(incoming.joint_pet&&u->guard_radius>0))&&
        u->kind>=0&&u->kind<ENEMY_KIND_COUNT&&soldiers_[u->kind].active&&
        u->kind!=1&&u->kind!=4&&u->kind!=17&&u->kind!=18&&
        !habaru&&!zombie_boss(*u)&&!grave_boss(*u)&&!ruby_boss(*u)&&!undersea_boss(*u);
    if(!light_pressure&&(incoming.amount>0||control||incoming.flinch>0||dot(incoming.impulse,incoming.impulse)>0)){
        u->light_stagger=false;u->light_recoil_grace=0;u->guard_pressure_hits=0;
    }
    if(!guarded&&!boss&&!charging&&finite(incoming.impulse)&&std::isfinite(incoming.flinch)&&incoming.flinch>=0&&(length(incoming.impulse)>0||incoming.flinch>0)){
        u->knockback=incoming.add_impulse?u->knockback+incoming.impulse:incoming.impulse;u->knockback_decay=8;u->stun=std::max(u->stun,incoming.flinch);u->action_active=false;u->action=data_.actions.empty()?0:data_.actions[0];u->action_time=0;u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};result.accepted=true;
        if(u->air_phase){u->air_phase=4;u->landing_attack=false;u->invuln=0;}
    }
    if(incoming.status_seconds>0){
        if(incoming.effect==4){
            u->stun=std::max(u->stun,incoming.status_seconds);u->has_goal=false;result.accepted=true;
            if(!boss&&!charging){u->action_active=false;u->action=data_.actions.empty()?0:data_.actions[0];u->action_time=0;u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};if(u->air_phase){u->air_phase=4;u->landing_attack=false;u->invuln=0;}}
        }
        if(incoming.effect==3&&u->team==1&&u->kind==133){if(u->avatar_left<=0){u->max_hp+=500;u->hp+=500;}u->avatar_left=std::max(u->avatar_left,incoming.status_seconds);result.accepted=true;}
        if(incoming.effect==5&&u->team==1&&u->kind==133){u->buff_left=std::max(u->buff_left,incoming.status_seconds);result.accepted=true;}
        if(incoming.effect==2&&std::isfinite(incoming.attack_slow_factor)&&incoming.attack_slow_factor>=0&&incoming.attack_slow_factor<1){u->attack_slow_left=std::max(u->attack_slow_left,incoming.status_seconds);u->attack_slow_factor=std::min(u->attack_slow_factor,incoming.attack_slow_factor);result.accepted=true;}
        if(incoming.effect==1){if(u->frozen<=0)u->ice_time=0;u->frozen=std::max(u->frozen,incoming.status_seconds);u->ice_thaw=0;u->ice_strength=1;result.accepted=true;}
        if(incoming.effect==6&&std::isfinite(incoming.slow_factor)&&incoming.slow_factor>=0&&incoming.slow_factor<=1){u->ice_chill=std::max(u->ice_chill,incoming.status_seconds);u->slow_left=std::max(u->slow_left,incoming.status_seconds);u->slow_factor=std::min(u->slow_factor,incoming.slow_factor);u->ice_thaw=0;u->ice_strength=u->frozen>0?1.f:.42f;result.accepted=true;}
        if(incoming.effect==2&&std::isfinite(incoming.slow_factor)&&incoming.slow_factor>=0&&incoming.slow_factor<=1){u->slow_left=std::max(u->slow_left,incoming.status_seconds);u->slow_factor=std::min(u->slow_factor,incoming.slow_factor);result.accepted=true;}
    }
    refresh_status(*u);
    if(u->frozen>0)pose_frame(*u);
    if(u->counter_active&&!u->action_active)u->counter_active=false;
    if(incoming.amount<=0||(!incoming.intercepted&&u->invuln>0)||(u->kind==8&&u->team==1&&u->landing_attack&&u->action_active))return result;
    double amount=knight&&u->buff_left>0?std::round(incoming.amount*.5):incoming.amount;
    if(guarded)amount*=.25;
    if(ruby_boss(*u)&&u->ruby_holy_left>0){amount*=.5*(1-random(*u));zombie_cue(*u,RUBY_WARD_BLOCK,RUBY_HOLY_SHIELD,u->ruby_holy_left);}
    if(boss&&u->action!=107){
        auto& state=skullpions_[handle];state.armor+=std::min(incoming.heavy?amount:amount*.15,u->max_hp*.01);amount*=.15;
        if(state.armor>=u->max_hp*.08){state.armor=0;boss_enter(*u,7,u->position);}
    }
    double damage=amount*(u->team==1?data_.damage_taken_multiplier:1)/(u->avatar_left>0?1.3:1);
    if(reckless)damage*=1.25;
    if(guardian(*u)&&u->action_active&&(u->guardian_tech==104||u->guardian_tech==105))damage*=u->guardian_tech==104?1.25:1.30;
    if(u->guardian_magic_guard>0&&incoming.magical)damage*=.25;
    if(u->afflictions[1]>0){u->afflictions[1]=0;u->afflicted&=~2;u->stun=std::min(u->stun,.05);
        Event e;e.kind=STATUS_EVENT;e.unit_kind=u->kind;e.source_id=e.target_id=u->logical_id;e.ticket_id=u->handle;e.external_kind=-1;e.action_index=GUARDIAN_AFFLICTION+1;e.position=u->position;emit(e);
    }
    if(incoming.effect==7)damage=u->hp;
    if(damage<=0)return result;
    if(habaru&&!control&&u->habaru_phase==0)u->habaru_gap=.75;
    int joint_count=0;double joint_total=0;
    if(u->team==0&&incoming.joint_attack&&!incoming.projectile&&!incoming.counter&&(incoming.joint_pet||incoming.source_id==0)){
        if(joint_clock_>=u->joint_until){u->joint_count=0;u->joint_player=false;u->joint_base=u->joint_paid=0;u->joint_until=joint_clock_+.35;}
        auto end=u->joint_sources.begin()+u->joint_count;
        bool known=std::find(u->joint_sources.begin(),end,incoming.source_id)!=end;
        if(known||u->joint_count<int(u->joint_sources.size())){
            if(!known)u->joint_sources[u->joint_count++]=incoming.source_id;
            u->joint_player|=!incoming.joint_pet;
            u->joint_base+=damage;
            // Settle the growing group multiplier against damage already applied.
            double total=u->joint_base*(u->joint_player&&u->joint_count>=2?1+.1*u->joint_count:1);
            damage=total-u->joint_paid;u->joint_paid=total;
            if(u->joint_player&&u->joint_count>=2){joint_count=u->joint_count;joint_total=total;}
        }
    }
    result.accepted=true;u->flash_left=u->kind==SLIME_KIND&&!guarded?1.0:.115;u->hp-=damage;if(u->team==1)u->hp=std::max(0.0,u->hp);
    if(u->hp<=0&&u->team==0&&u->kind>=0&&u->kind<ENEMY_KIND_COUNT&&soldiers_[u->kind].active){
        int next=int(soldiers_[u->kind].kit[25]);
        if(next>=0&&soldiers_[next].active){
            int previous=u->kind;u->kind=next;u->hp=u->max_hp=soldiers_[next].hp*u->enemy_health_scale;u->action_active=false;u->action_time=0;u->phase_tick=0;u->pose_time=0;u->has_goal=false;u->action_hits.clear();
            Event changed;changed.kind=STATUS_EVENT;changed.source_id=u->logical_id;changed.target_id=u->logical_id;changed.position=u->position;changed.direction={std::sin(u->yaw),0,std::cos(u->yaw)};changed.unit_kind=next;changed.action_index=17;changed.amount=previous;emit(changed);
            pose_frame(*u);nearest_revision_=UINT64_MAX;
        }
    }
    result.hp=u->hp;result.dead=u->hp<=0;
    Event event;event.body_scale=u->body_scale;event.kind=DAMAGE;event.source_id=incoming.source_id;event.target_id=u->logical_id;event.ticket_id=incoming.ticket_id;event.position=u->position+Vec3{0,1,0};event.amount=damage;event.hp=u->hp;event.projectile=incoming.projectile;event.heavy=incoming.heavy;event.critical=incoming.critical;event.unit_kind=u->kind;event.team=u->team;event.action_index=incoming.guard_break?GUARD_BREAK_HIT:(guarded?13:0);event.joint_count=joint_count;event.joint_total=joint_total;emit(event);
    if(result.dead){
        for(auto& entry:pet_sequence_targets_)if(entry.second.handle==handle){
            auto& saved=entry.second;saved.position=u->position;saved.yaw=u->yaw;saved.kind=u->kind;saved.pose_row=u->pose_row;saved.killed=true;
        }
        // Real-time adaptation: lethal criticals or 25% maximum-HP excess launch the cosmetic body.
        if(u->team==0&&!boss&&(incoming.critical||-u->hp>=u->max_hp*.25)){
            event.death_launch=finite(incoming_flat)&&length(incoming_flat)>.001f?normalized(incoming_flat):Vec3{-std::sin(u->yaw),0,-std::cos(u->yaw)};
        }
        event.kind=DEATH;if(pet_skin_count(u->kind))event.action_index=u->pose_row;event.position=u->position;event.direction={std::sin(u->yaw),0,std::cos(u->yaw)};emit(event);if(boss)skullpions_.erase(handle);crowd.despawn(handle);return result;}
    if(light_pressure&&u->frozen<=0){
        if(guarded){
            u->guard_left=std::min(u->guard_left,BLOCKED_HIT_GUARD_CAP);
            u->light_recoil_grace=u->guard_left+.65;
            u->guard_pressure_hits=0;
        }else{
            if(joint_clock_>=u->guard_pressure_until)u->guard_pressure_hits=0;
            u->guard_pressure_until=joint_clock_+.9;
            const bool third=u->guard_pressure_hits==2;
            if(u->guard_pressure_hits<3)++u->guard_pressure_hits;
            if(third&&incoming.joint_pet){u->retaliation=4;u->retaliation_source=incoming.source_id;}
            // Let the first stagger finish while repeated front hits still deal full damage.
            if(u->light_recoil_grace<=0&&(third||(u->light_stagger&&u->stun>0)))
                u->light_recoil_grace=u->action_active?2.0:u->stun+.55;
        }
    }
    if(u->team==1){u->invuln=.35;if(knight)u->hit_pause=std::max(u->hit_pause,.045);}
    else if(!guarded&&!boss&&!charging&&u->light_recoil_grace<=0){
        if(u->stun<=0)u->light_stagger=light_pressure&&u->frozen<=0;
        u->blocking=false;u->guard_left=0;u->guard_reaction=0;
        u->stun=std::max(u->stun,16.0/30);u->action_active=false;u->action_time=0;u->has_goal=false;
        u->action_hits.clear();u->pending_drift=0;u->motion_impulse={};
        if(incoming.provoke){u->retaliation=4;u->retaliation_source=incoming.source_id;u->think_left=0;}
        // Front-load marked melee hits; other skills retain their contact spacing.
        u->knockback=normalized(Vec3{incoming.direction.x,0,incoming.direction.z})*(incoming.heavy?3.0f:1.2f);
        u->knockback_decay=incoming.responsive_recoil?12:8;
        if(incoming.responsive_recoil)u->knockback=u->knockback*1.5f;
        if(enabled_&&u->frozen<=0&&u->kind>=0&&u->kind<ENEMY_KIND_COUNT&&soldiers_[u->kind].active){u->action=data_.actions[6];u->phase_tick=0;pose_frame(*u);}
    }
    refresh_status(*u);
    if(!result.dead){
        if(u->counter_active&&!u->action_active)u->counter_active=false;
        queue_counter(crowd,*u,incoming);
    }
    return result;
}
void Combat::queue_counter(Crowd& crowd,Unit& u,const Hit& hit){
    if(u.counter_chance<=0||(guardian(u)&&hit.magical)||hit.counter||!hit.provoke||hit.amount<=0||hit.source_id==u.logical_id)return;
    if(u.patrol_counter){
        if(u.counter_pending||u.counter_active||u.patrol_counter_cooldown>0||hit.magical||hit.projectile)return;
        if(bag_draw(u.patrol_counter_bag,0b11111,random(u))!=0)return;
    }else if(random(u)>=u.counter_chance)return;
    if(u.team==1){
        auto attacker=crowd.ids_.find(hit.source_id);
        if(attacker==crowd.ids_.end())return;
        const auto& foe=crowd.units_[attacker->second];
        if(foe.team==u.team||foe.hp<=0)return;
        u.counter_source=foe.handle;
    }else u.counter_source=hit.source_id;
    u.counter_pending=true;
}
bool Combat::begin_counter(Crowd& crowd,Unit& u){
    if(u.counter_active){u.has_goal=false;return true;}
    if(!u.counter_pending||u.action_active||u.pet_skill||u.blocking||u.habaru_phase||u.stun>0||u.frozen>0||u.dodge_left>0)return false;
    u.counter_pending=false;
    Vec3 foot;Handle attacker_handle=0;
    if(u.team==1){
        const auto* foe=crowd.unit(u.counter_source);
        if(!foe||foe->team==u.team||foe->hp<=0||foe->shelter_mode==2)return false;
        foot=foe->position;attacker_handle=foe->handle;
    }else{
        if(u.patrol_counter&&u.counter_source!=0){
            auto attacker=crowd.ids_.find(u.counter_source);
            if(attacker==crowd.ids_.end()||crowd.units_[attacker->second].team!=1||crowd.units_[attacker->second].shelter_mode==2)return false;
        }
        u.retaliation_source=u.counter_source;u.retaliation=4;choose_target(crowd,u);
        if(!target(crowd,u,foot)||u.external_kind==2)return false;
    }
    const auto* geometry=pet_geometry(u);
    float reach=u.kind==4?5.5f*data_.enemy_size:soldiers_[u.kind].range*(geometry?geometry[6]:1);
    const auto& terrain=u.team==1?crowd.allied_terrain:crowd.terrain;
    if(horizontal(u.position,foot)>reach||std::abs(u.position.y-foot.y)>3.5f||!terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0}))return false;
    if(attacker_handle)u.target_handle=attacker_handle;
    u.yaw=std::atan2(-foot.x+u.position.x,-foot.z+u.position.z);
    u.counter_active=true;u.counter_hit=false;
    if(u.patrol_counter)u.patrol_counter_cooldown=3.0;
    if(u.kind==4){boss_enter(u,1,foot);u.counter_contact=.65;u.counter_duration=2.5;}
    else{
        begin(u);
        const auto& kit=soldiers_[u.kind].kit;
        u.counter_contact=kit[5]/30;u.counter_duration=kit[0]/30;
        if(pet_skin_count(u.kind)){
            const auto* timeline=pet_timeline(u);u.counter_duration=timeline[0]/30;
            for(int i=0;i<int(timeline[1]);++i)if(companion_contact_cue(int(timeline[3+i*2]))){u.counter_contact=timeline[2+i*2]/30;break;}
        }
    }
    return true;
}
double Combat::soldier_damage(const Unit& u) const{
    if(u.team==1&&data_.hound_hp>0){
        if(u.kind==HOUND_KIND)return data_.hound_damage+u.pet_damage_bonus;
        if(u.kind==BEAR_KIND)return data_.bear_damage;
    }
    return soldiers_[u.kind].damage;
}
void Combat::advance_counter(Crowd& crowd,Unit& u,double dt){
    if(dt<=0||u.stun>0)return;
    u.action_time+=dt*u.attack_slow_factor;u.phase_tick=u.action_time*30;
    if(!u.counter_hit&&u.action_time+1e-8>=u.counter_contact){
        u.counter_hit=true;
        Vec3 foot;bool contact=target(crowd,u,foot);
        if(u.kind==4)contact=contact&&horizontal(u.position,foot)<=5.5f*data_.enemy_size&&std::abs(foot.y-u.position.y)<=3.5f&&crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0});
        else contact=contact&&melee_contact(crowd,u);
        if(contact)deliver(crowd,u,u.kind==4?data_.skullpion[1]:soldier_damage(u),false,u.position);
    }
    if(u.action_time+1e-8>=u.counter_duration){
        u.counter_active=false;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.think_left=0;
        if(u.kind==4)boss_enter(u,0,u.position);
    }
}
void Combat::set_targets(std::vector<ExternalTarget> targets,double camera_yaw,double player_speed,int64_t hound_order,int64_t hound_order_serial,int64_t hound_focus_target){
    hound_order_serial_=hound_order_serial;
    if(std::isfinite(camera_yaw))hound_camera_yaw_=std::remainder(camera_yaw,2*M_PI);
    hound_player_speed_=std::isfinite(player_speed)?std::clamp(player_speed,0.0,18.0):0;
    hound_order_=hound_order==HOUND_ATTACK?HOUND_ATTACK:hound_order==HOUND_RETURN?HOUND_RETURN:hound_order==HOUND_HOLD?HOUND_HOLD:HOUND_DEFEND;
    hound_focus_target_=hound_order_==HOUND_ATTACK?hound_focus_target:0;
    Vec3 previous_hero=hound_hero_row_>=0?targets_[hound_hero_row_].foot:Vec3{NAN,0,0};
    targets_=std::move(targets);++target_revision_;hero_row_=taunt_row_=hound_hero_row_=-1;
    for(auto& group:target_groups_)group.clear();
    for(size_t i=0;i<targets_.size();++i){
        const auto& row=targets_[i];if(row.kind==0&&row.hp>0)hound_hero_row_=int(i);
        if(row.hp<=0||!row.targetable)continue;
        if(row.kind>=0&&row.kind<4)target_groups_[row.kind].push_back(i);
        if(row.kind==0&&row.hp>0&&hero_row_<0)hero_row_=int(i);
        if(row.taunting&&row.hp>0&&taunt_row_<0)taunt_row_=int(i);
    }
    hound_escort_lead_={};
    if(hound_hero_row_>=0&&finite(previous_hero)){
        Vec3 travel=targets_[hound_hero_row_].foot-previous_hero;travel.y=0;
        if(length(travel)<2)hound_escort_lead_=normalized(travel)*float(hound_player_speed_*.16);
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
const Unit* Combat::pet_sequence_target(Crowd& crowd,const Unit& u,Unit& corpse) const{
    auto live=crowd.unit(u.target_handle);
    if(u.pet_skill!=2&&u.pet_skill!=PET_BEE_FLURRY)return live;
    if(live){
        pet_sequence_targets_[u.handle]={live->handle,live->logical_id,live->position,live->yaw,live->kind,live->pose_row,false,live->body_scale};
        return live;
    }
    auto found=pet_sequence_targets_.find(u.handle);
    if(found==pet_sequence_targets_.end()||found->second.handle!=u.target_handle||!found->second.killed)return nullptr;
    const auto& saved=found->second;
    corpse.handle=saved.handle;corpse.logical_id=saved.logical_id;corpse.position=saved.position;corpse.yaw=saved.yaw;corpse.kind=saved.kind;corpse.pose_row=saved.pose_row;corpse.hp=1;corpse.body_scale=saved.body_scale;
    return &corpse;
}
bool Combat::target(Crowd& crowd,const Unit& unit,Vec3& foot) const{
    if(unit.target_handle){
        if(unit.pet_skill==2||unit.pet_skill==PET_BEE_FLURRY){Unit corpse;auto other=pet_sequence_target(crowd,unit,corpse);if(!other||other->hp<=0||other->shelter_mode==2)return false;foot=other->position;return true;}
        auto other=crowd.unit(unit.target_handle);if(!other||other->hp<=0||other->shelter_mode==2)return false;foot=other->position;return true;
    }
    if(unit.external_kind<0)return false;
    if(auto other=external_target(unit)){foot=(other->kind==2||other->body_bounds())?Vec3{std::clamp(unit.position.x,other->minimum.x,other->maximum.x),other->minimum.y,std::clamp(unit.position.z,other->minimum.z,other->maximum.z)}:other->foot;return true;}
    return false;
}
bool Combat::melee_contact(Crowd& crowd,const Unit& unit) const{
    Vec3 foot;if(!target(crowd,unit,foot))return false;
    const auto& k=soldiers_[unit.kind].kit;
    const auto* geometry=pet_geometry(unit);float scale=geometry?geometry[6]:1,radius=k[15]*scale;
    Vec3 from=unit.position+rotated_y(Vec3{k[9],k[10],k[11]}*scale,unit.yaw),to=unit.position+rotated_y(Vec3{k[12],k[13],k[14]}*scale,unit.yaw);
    if(unit.team==1&&escort_kind(unit.kind)){
        Unit corpse;auto enemy=pet_sequence_target(crowd,unit,corpse);if(!enemy)return false;
        Vec3 contact=enemy_contact(*enemy,to);
        bool hit=geometry?enemy_segment(*enemy,from,to,radius)>=0:segment_distance(from,to,contact,contact)<radius;
        // A swing can extend past its victim into a wall; stop the cover ray at the victim.
        return hit&&crowd.allied_terrain.ray_clear(from,{enemy->position.x,contact.y,enemy->position.z});
    }
    if(unit.external_kind==2){
        if(!crowd.terrain.ray_clear(from,to,unit.external_target))return false;
        for(const auto& other:targets_)if(other.id==unit.external_target&&other.kind==2){
            Vec3 p{std::clamp(to.x,other.minimum.x,other.maximum.x),std::clamp(to.y,other.minimum.y,other.maximum.y),std::clamp(to.z,other.minimum.z,other.maximum.z)};
            return segment_distance(from,to,p,p)<.18f;
        }
    }
    if(auto enemy=crowd.unit(unit.target_handle);enemy&&pet_geometry(*enemy)){
        return enemy_segment(*enemy,from,to,radius)>=0&&crowd.terrain.ray_clear(from,enemy_contact(*enemy,from));
    }
    if(auto other=external_target(unit);other&&other->body_bounds()){
        float t=box_segment(from,to,other->minimum,other->maximum,radius);
        Vec3 p=from+(to-from)*std::max(0.f,t);
        p={std::clamp(p.x,other->minimum.x,other->maximum.x),std::clamp(p.y,other->minimum.y,other->maximum.y),std::clamp(p.z,other->minimum.z,other->maximum.z)};
        return t>=0&&crowd.terrain.ray_clear(from,p);
    }
    // Stop occlusion at the victim; scenery beyond a short-range hit cannot block it.
    Vec3 contact=foot+Vec3{0,std::clamp(from.y-foot.y,.4f,1.8f),0};
    return body_contact(from,to,foot,radius)&&crowd.terrain.ray_clear(from,contact);
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
        if(u.radius<1.289f*(pet_skin_count(u.kind)?1.f:data_.enemy_size))nearest_fallback_=true;
        if(u.kind==4){const double size=25.0*data_.map_enemy_scale;nearest_radius_=std::max(nearest_radius_,size);nearest_height_=std::max(nearest_height_,size);}
        else if(u.kind>=0&&u.kind<ENEMY_KIND_COUNT&&soldiers_[u.kind].active){Vec3 low,high;enemy_bounds(u,low,high);
            nearest_radius_=std::max(nearest_radius_,double(std::hypot(std::max(std::abs(low.x),std::abs(high.x)),std::max(std::abs(low.z),std::abs(high.z)))));nearest_height_=std::max(nearest_height_,double(high.y));}
    }
    if(!nearest_entries_.empty()&&!nearest_fallback_)build_nearest_node(crowd,0,int(nearest_entries_.size()));
    nearest_revision_=crowd.pose_revision_;
}
int64_t Combat::nearest_enemy(Crowd& crowd,Vec3 origin,const std::array<int64_t,4>* hunt_skips){
    if(crowd.counts_[0]==0)return 0;
    int64_t chosen=0;float best=INFINITY;
    if(nearest_revision_!=crowd.pose_revision_)rebuild_nearest(crowd);
    if(!nearest_fallback_||hunt_skips){
        if(nearest_nodes_.empty()&&!nearest_entries_.empty())build_nearest_node(crowd,0,int(nearest_entries_.size()));
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
                    int claimed=0;
                    if(hunt_skips){
                        if(other->hp<=0||other->shelter_mode==2||std::find(hunt_skips->begin(),hunt_skips->end(),other->handle)!=hunt_skips->end())continue;
                        claimed=int(std::count(hound_claims_.begin(),hound_claims_.end(),other->handle));
                        if(claimed>=(other->kind==4?6:4))continue;
                    }
                    ++nearest_contact_tests_;float distance=length(enemy_contact(*other,origin+Vec3{0,1,0})-origin);
                    distance+=5.f*claimed;
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
    const auto* geometry=pet_geometry(unit);
    if(!building&&soldiers_[unit.kind].active&&horizontal(unit.position,foot)<=soldiers_[unit.kind].range*(geometry?geometry[6]:1)&&std::abs(unit.position.y-foot.y)<=3.5f&&melee_contact(crowd,unit)){goal=unit.position;return true;}
    int layer=unit.support_layer<0?crowd.terrain.choose_layer(unit.position):unit.support_layer;
    if(layer<0)return false;
    // Continuous ground travel preserves this approach; pose/navigation changes invalidate it.
    if(building&&!unit.base_marching&&unit.approach_ready&&unit.approach_target==building->id&&unit.kind!=4&&unit.kind!=17&&unit.kind!=18&&
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
int Combat::snow_health_preference(const Unit& unit) const{
    if(unit.team!=0||unit.kind!=HOUND_KIND||data_.snow_patrol_skins.empty())return 0;
    return unit.pose_row==data_.snow_patrol_skins[0]?-1:unit.pose_row==data_.snow_patrol_skins[1]?1:0;
}
// One meter per map kill, capped so distant armies keep their objectives.
float Combat::player_aggro_bonus() const{return hero_row_>=0?float(std::clamp(targets_[hero_row_].aggro_kills,0,42)):0;}
void Combat::choose_target(Crowd& crowd,Unit& unit){
    const float hero_range=28+player_aggro_bonus();
    auto previous_handle=unit.target_handle;auto previous_id=unit.external_target;int previous_kind=unit.external_kind;
    enemy_unit_claims_.resize(crowd.units_.size());enemy_external_claims_.resize(targets_.size());
    auto claim=[&](int row,int64_t handle,int delta){
        if(handle&&crowd.unit(handle)){auto& count=enemy_unit_claims_[uint32_t(handle)];count=std::max(0,count+delta);}
        else if(row>=0){auto& count=enemy_external_claims_[row];count=std::max(0,count+delta);}
    };
    const auto* previous=external_target(unit);
    const auto* previous_unit=crowd.unit(previous_handle);
    const bool previous_local=previous_handle?previous_unit&&horizontal(previous_unit->position,unit.position)<=28:
        previous&&previous->kind!=2&&horizontal(previous->foot,unit.position)<=(previous->kind==0?hero_range:28);
    claim(previous?int(previous-targets_.data()):-1,previous_handle,-1);
    const int snow=snow_health_preference(unit);
    bool snow_party=false;
    auto distance_score=[&](int row,int64_t handle,float distance){
        if(distance>(row>=0&&targets_[row].kind==0?hero_range:28)||(row>=0&&targets_[row].kind==2))return distance;
        int count=handle?enemy_unit_claims_[uint32_t(handle)]:enemy_external_claims_[row];
        float health_bias=0;
        if(snow_party&&(handle||targets_[row].kind==0||targets_[row].kind==3)){
            double hp=handle?crowd.unit(handle)->hp:targets_[row].hp;
            health_bias=24.f*float((snow<0?hp:500.)/(hp+500.));
        }
        return distance+health_bias+5.f*std::min(count,3)+float(random(unit))*.75f;
    };
    auto current=[&](const TargetCandidate& candidate){return previous_local&&(candidate.handle?candidate.handle==previous_handle:
        candidate.row>=0&&targets_[candidate.row].kind==previous_kind&&targets_[candidate.row].id==previous_id);};
    auto preferred=[&](const TargetCandidate& a,const TargetCandidate& b){
        if(a.priority!=b.priority)return a.priority>b.priority;
        if(current(a)!=current(b))return current(a);
        if(a.distance!=b.distance)return a.distance<b.distance;
        return a.handle&&b.handle&&crowd.unit(a.handle)->logical_id<crowd.unit(b.handle)->logical_id;
    };
    unit.target_handle=0;unit.external_kind=-1;
    auto select=[&](int row,int64_t handle){
        unit.target_handle=handle;unit.external_kind=row>=0?targets_[row].kind:-1;
        if(row>=0)unit.external_target=targets_[row].id;
        Vec3 goal;if(!target_approach(crowd,unit,goal))return false;
        unit.base_marching=false;unit.target_goal=goal;unit.approach_ready=unit.external_kind==2&&length(goal-unit.position)>.001f;
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
        snow_party=snow!=0&&!assault;
        target_candidates_.clear();
        for(int kind:{2,1,3})for(auto row:target_groups_[kind]){
            const auto& other=targets_[row];
            Vec3 point=kind==2?Vec3{std::clamp(unit.position.x,other.minimum.x,other.maximum.x),other.minimum.y,std::clamp(unit.position.z,other.minimum.z,other.maximum.z)}:other.foot;
            float distance=horizontal(unit.position,point);
            // Military buildings intercept locally instead of diverting the whole assault.
            if((kind==2&&other.assault_priority==4||assault&&kind!=2)&&distance>28)continue;
            int rank=kind==2?other.assault_priority:distance<=28&&(assault||(snow_party&&kind==3))?(kind==1?3:5):0;
            target_candidates_.push_back({int(row),0,distance_score(int(row),0,distance),rank});
        }
        if(hero_row_>=0){
            float distance=horizontal(targets_[hero_row_].foot,unit.position);
            if(distance<=hero_range)target_candidates_.push_back({hero_row_,0,distance_score(hero_row_,0,distance),distance<=28||assault||snow_party?5:0});
        }
        std::stable_sort(target_candidates_.begin(),target_candidates_.end(),preferred);
        bool committed=false;
        for(auto candidate:target_candidates_)if(select(candidate.row,0)){score=candidate.distance;priority=candidate.priority;selected=true;committed=current(candidate);break;}
        if(auto other=previous_unit;other&&other->team==1&&other->shelter_mode!=2){
            float distance=horizontal(unit.position,other->position);int rank=(assault||snow_party)&&distance<=28?5:0;
            if(distance<=28&&(rank>priority||(rank==priority&&!committed))&&select(-1,previous_handle)){
                score=distance;priority=rank;selected=committed=true;
            }
        }
        auto best_handle=unit.target_handle;auto best_id=unit.external_target;int best_kind=unit.external_kind;Vec3 best_goal=unit.target_goal;
        if(crowd.counts_[1]>0&&(!committed||(assault&&priority<5))){
            float extent=assault||priority>0?28:std::max(28.0f,std::isfinite(score)?score:3e8f);
            for(float radius=std::min(28.0f,extent);;radius=std::min(radius*2,extent)){
                Vec3 pad{radius,3e8f,radius};target_candidates_.clear();
                for(auto handle:crowd.query(unit.position-pad,unit.position+pad,1,false)){
                    auto other=crowd.unit(handle);if(!other||other->shelter_mode==2)continue;
                    float distance=horizontal(unit.position,other->position);int rank=(assault||snow_party)&&distance<=28?5:0;
                    distance=distance_score(-1,handle,distance);
                    if(rank<priority||(rank==priority&&distance>=score))continue;
                    target_candidates_.push_back({-1,handle,distance,rank});
                }
                std::sort(target_candidates_.begin(),target_candidates_.end(),preferred);
                for(auto candidate:target_candidates_)if(select(-1,candidate.handle)){
                    score=candidate.distance;priority=candidate.priority;selected=true;
                    best_handle=unit.target_handle;best_id=unit.external_target;best_kind=unit.external_kind;best_goal=unit.target_goal;break;
                }
                if(priority>0||score<=radius||radius>=extent)break;
            }
        }
        unit.target_handle=best_handle;unit.external_target=best_id;unit.external_kind=best_kind;unit.target_goal=best_goal;
        if(!selected&&!assault&&hero_row_>=0)selected=select(hero_row_,0);
    }
    if(!selected){
        unit.target_handle=0;unit.external_kind=-1;unit.has_goal=false;
        march_on_base(crowd,unit);
    }
    if(unit.target_handle!=previous_handle||unit.external_target!=previous_id||unit.external_kind!=previous_kind)unit.routing=false;
    const auto* chosen=external_target(unit);
    claim(chosen?int(chosen-targets_.data()):-1,unit.target_handle,1);
}
void Combat::march_on_base(Crowd& crowd,Unit& unit){
    const ExternalTarget* base=nullptr;
    for(auto row:target_groups_[2])if(targets_[row].assault_priority==2){base=&targets_[row];break;}
    if(!base)return;
    int layer=unit.support_layer<0?crowd.terrain.choose_layer(unit.position):unit.support_layer;
    if(layer<0)return;
    // Keep a reachable staging point while the actual castle contact is sealed.
    float speed=unit.kind==4&&!data_.skullpion.empty()?float(data_.skullpion[0]):float(soldiers_[unit.kind].speed);
    if(unit.base_marching&&unit.approach_ready&&unit.approach_target==base->id&&horizontal(unit.position,unit.target_goal)>2&&crowd.terrain.reachable(unit.position,unit.target_goal,unit.radius,layer)){
        crowd.set_goal(unit.handle,unit.target_goal,speed);return;
    }
    float distance=horizontal(unit.position,base->foot),angle=std::atan2(unit.position.x-base->foot.x,unit.position.z-base->foot.z);
    for(float radius=6;radius<distance;radius*=2){
        float best=INFINITY;Vec3 goal;
        for(int side=0;side<16;++side){
            float a=angle+float(side*M_PI/8);Vec3 point=base->foot+Vec3{std::sin(a)*radius,0,std::cos(a)*radius};
            point.y=float(crowd.terrain.height(point.x,point.z,layer));
            float gap=length(point-unit.position);
            if(gap>=best||!crowd.terrain.reachable(unit.position,point,unit.radius,layer))continue;
            best=gap;goal=point;
        }
        if(!std::isfinite(best))continue;
        unit.target_goal=goal;unit.approach_target=base->id;unit.approach_ready=true;unit.base_marching=true;
        crowd.set_goal(unit.handle,goal,speed);return;
    }
}
void Combat::attack_started(const Unit& unit){
    Event event;event.kind=ATTACK_STARTED;event.source_id=unit.logical_id;event.unit_kind=unit.kind;event.team=unit.team;emit(event);
}
const float* Combat::pet_timeline(const Unit& unit) const{
    int direction=unit.hound_attack_direction<0?4:unit.hound_attack_direction;
    const auto& attacks=unit.kind==SLIME_KIND?data_.slime_attacks:unit.kind==BEAR_KIND?data_.bear_attacks:data_.hound_attacks;
    return attacks.data()+(unit.pose_row*8+direction)*HOUND_TIMELINE_STRIDE;
}
void Combat::pet_cue(const Unit& unit,int sound,double tick){
    sound%=10000;
    if(sound==0)return;
    Event event;event.kind=STATUS_EVENT;event.source_id=unit.logical_id;event.unit_kind=unit.kind;
    event.position=unit.position;event.action_index=HOUND_CUE_BASE+sound;event.source_tick=tick;emit(event);
}
void Combat::begin(Unit& unit){
    unit.action_active=true;unit.just_started=true;unit.phase_tick=0;unit.attack_tick=0;unit.action_time=0;unit.soldier_shots=0;
    if(unit.team==1&&escort_kind(unit.kind)){unit.pet_rush_left=5.0/32;++unit.attack_serial;}
    unit.primary_hit=false;
    if(guardian(unit)){unit.guardian_hits=0;if(unit.guardian_tech!=50)unit.guardian_combo=1;if(unit.guardian_tech)zombie_cue(unit,GUARDIAN_CAST,unit.guardian_tech,pet_timeline(unit)[0]);}
    // Give long source windups time to reach their first contact marker.
    if(unit.light_recoil_grace>0)unit.light_recoil_grace=2.0;
    unit.soldier_phase=int(soldiers_[unit.kind].kit[17]);unit.action=data_.actions[unit.soldier_phase+1];unit.has_goal=false;
    if(!unit.counter_active&&(zombie_boss(unit)||grave_boss(unit))&&unit.hp<unit.max_hp&&unit.combo_serial++%2==0){
        unit.action=ZOMBIE_DRAIN;zombie_cue(unit,ZOMBIE_DRAIN);
    }
    if(!unit.counter_active&&data_.grave_boss&&unit.kind==SLIME_KIND&&unit.pose_row==0&&unit.combo_serial++%4==0){
        zombie_cue(unit,GRAVE_MAGIC_SEAL,4.0);
    }
    if(unit.handle!=enemy_guard_break_owner_&&!unit.counter_active&&data_.habaru_bears&&unit.team==0&&unit.kind==SLIME_KIND&&unit.pose_row==1&&++unit.combo_serial%4==0){
        unit.action=HABARU_DOUBLE_EDGE;
    }
    if(unit.handle!=enemy_guard_break_owner_&&!unit.counter_active&&snow_health_preference(unit)>0&&bag_draw(unit.snow_attack_bag,0b1111,random(unit))==0){
        unit.action=HABARU_DOUBLE_EDGE;
        zombie_cue(unit,HABARU_DOUBLE_EDGE);
    }
    attack_started(unit);
    if(pet_skin_count(unit.kind)){
        // Select the source gesture and its sounds together, once per attack.
        if(unit.kind==SLIME_KIND?slime_directional_[unit.pose_row]:unit.kind==BEAR_KIND?bear_directional_[unit.pose_row]:hound_directional_[unit.pose_row]){
            int octant=int(std::round(std::remainder(hound_camera_yaw_-unit.yaw,2*M_PI)*4/M_PI));
            unit.hound_attack_direction=(octant+9)%8;
        }
        const auto* attack=pet_timeline(unit);
        if(attack[2]==0)pet_cue(unit,int(attack[3]),0);
    }
}
void Combat::pet_skill_event(Crowd& crowd,const Unit& u,EventKind kind){
    const auto* timeline=pet_timeline(u);int contacts=0;
    for(int i=0;i<int(timeline[1]);++i)if(companion_contact_cue(int(timeline[3+i*2])))++contacts;
    Event event;event.kind=kind;event.source_id=u.logical_id;event.ticket_id=u.handle;
    Unit corpse;if(auto target=pet_sequence_target(crowd,u,corpse))event.target_id=target->logical_id;
    event.projectile_id=u.pet_cast_serial;event.action_index=u.pet_skill;event.team=1;event.unit_kind=u.kind;
    event.position=u.position;event.direction=rotated_y({0,0,-1},u.yaw);
    event.amount=u.pet_skill==PET_BEE_FLURRY?1.0:1.0/std::max(1,contacts);event.source_tick=u.attack_tick/30;emit(event);
}
bool Combat::pet_flurry_ready(Crowd& crowd,const Unit& u) const{
    if(u.kind!=HOUND_KIND||u.hound_order==HOUND_HOLD||u.pet_cooldowns[PET_BEE_FLURRY-1]>0||u.pet_mana+1e-8<pet_skill_cost(PET_BEE_FLURRY))return false;
    bool equipped=false;
    for(int slot=0;slot<3;++slot)equipped|=u.pet_skills[slot]==PET_BEE_FLURRY&&(u.pet_ready_mask&(1<<slot));
    auto foe=crowd.unit(u.target_handle);if(!equipped||!foe||foe->hp<=0)return false;
    const auto* geometry=pet_geometry(u);
    float range=2*soldiers_[u.kind].range*(geometry?geometry[6]:1);
    Vec3 contact=enemy_contact(*foe,u.position+Vec3{0,1,0});
    return horizontal(u.position,contact)<=range&&std::abs(u.position.y-foe->position.y)<5&&crowd.allied_terrain.ray_clear(u.position+Vec3{0,1,0},contact);
}
bool Combat::pet_flurry_blink(Crowd& crowd,Unit& u){
    Unit corpse;auto foe=pet_sequence_target(crowd,u,corpse);if(!foe||foe->hp<=0)return false;
    auto& ground=crowd.allied_terrain;int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    for(int attempt=0;attempt<8;++attempt){
        float angle=length(u.pet_flurry_side)<.001f?float(random(u)*2*M_PI):std::atan2(u.pet_flurry_side.x,u.pet_flurry_side.z)+float(M_PI+(random(u)*2-1)*M_PI/3);
        Vec3 side{std::sin(angle),0,std::cos(angle)};
        Vec3 point=enemy_contact(*foe,foe->position+side*100+Vec3{0,1,0})+side*(u.radius+.05f);
        point.y=float(ground.height(point.x,point.z,layer));
        if(!finite(point)||std::abs(point.y-u.position.y)>5||!ground.clear(point,u.radius,layer)||!pet_landing_clear(crowd,u,point)||!ground.reachable(u.position,point,u.radius,layer)||!ground.ray_clear(point+Vec3{0,1,0},enemy_contact(*foe,point+Vec3{0,1,0})))continue;
        Vec3 actual=normalized(Vec3{point.x-foe->position.x,0,point.z-foe->position.z});
        if(length(u.pet_flurry_side)>.001f&&dot(actual,u.pet_flurry_side)>-.5f)continue;
        Event smoke;smoke.kind=STATUS_EVENT;smoke.unit_kind=u.kind;smoke.source_id=u.logical_id;smoke.team=1;smoke.action_index=HOUND_BLINK_CUE;smoke.position=u.position;emit(smoke);
        u.pet_flurry_side=actual;Vec3 toward=foe->position-point;
        crowd.set_pose(u.handle,point,std::atan2(-toward.x,-toward.z));u.support_layer=layer;u.velocity=u.pose_velocity={};u.has_goal=false;u.routing=false;
        smoke.position=point;emit(smoke);--u.pet_combo_left;begin(u);pet_skill_event(crowd,u,PET_SKILL_MOVE);return true;
    }
    return false;
}
void Combat::finish_pet_flurry(Crowd& crowd,Unit& u){
    if(u.pet_skill!=PET_BEE_FLURRY)return;
    auto& ground=crowd.allied_terrain;int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    if(ground.clear(u.pet_flurry_origin,u.radius,layer)&&pet_landing_clear(crowd,u,u.pet_flurry_origin)&&ground.reachable(u.position,u.pet_flurry_origin,u.radius,layer)){
        Event smoke;smoke.kind=STATUS_EVENT;smoke.unit_kind=u.kind;smoke.source_id=u.logical_id;smoke.team=1;smoke.action_index=HOUND_BLINK_CUE;smoke.position=u.position;emit(smoke);
        crowd.set_pose(u.handle,u.pet_flurry_origin,u.yaw);u.velocity=u.pose_velocity={};
        smoke.position=u.position;emit(smoke);pet_skill_event(crowd,u,PET_SKILL_MOVE);
    }
    u.pet_skill=0;u.pet_combo_left=0;u.pet_flurry_charge=0;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.has_goal=false;u.think_left=.22;
}
void Combat::advance_pet_flurry(Crowd& crowd,Unit& u,double delta){
    if(delta<=0)return;
    Unit corpse;auto foe=pet_sequence_target(crowd,u,corpse);if(!foe||foe->hp<=0){finish_pet_flurry(crowd,u);return;}
    if(u.pet_flurry_charge>0){
        u.pet_flurry_charge=std::max(0.,u.pet_flurry_charge-delta*BEE_FLURRY_RATE);u.action_time=.45-u.pet_flurry_charge;
        if(u.pet_flurry_charge<=0&&!pet_flurry_blink(crowd,u))finish_pet_flurry(crowd,u);
        return;
    }
    const auto* timeline=pet_timeline(u);double contact=timeline[0];
    for(int i=0;i<int(timeline[1]);++i)if(companion_contact_cue(int(timeline[3+i*2]))){contact=timeline[2+i*2];break;}
    u.phase_tick+=delta*30*BEE_FLURRY_RATE;u.attack_tick=u.phase_tick;u.action_time=u.phase_tick/30;
    if(!u.primary_hit&&u.phase_tick+1e-8>=contact){u.primary_hit=true;if(melee_contact(crowd,u))pet_skill_event(crowd,u,PET_SKILL_CONTACT);}
    if(u.phase_tick+1e-8>=contact+3){if(u.pet_combo_left<=0||!pet_flurry_blink(crowd,u))finish_pet_flurry(crowd,u);}
}
bool Combat::pet_combo_blink(Crowd& crowd,Unit& u){
    Unit corpse;auto foe=pet_sequence_target(crowd,u,corpse);if(!foe||foe->hp<=0)return false;
    auto& ground=crowd.allied_terrain;int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    Vec3 contact=enemy_contact(*foe,u.position+Vec3{0,1,0});
    Vec3 from=u.position+Vec3{0,1,0};
    if(!ground.ray_clear(from,contact))return false;
    Vec3 away=normalized(Vec3{u.position.x-foe->position.x,0,u.position.z-foe->position.z});
    if(length(away)<.001f)away={0,0,1};
    const float angles[]={0.f,1.0471976f,-1.0471976f,2.0943952f,-2.0943952f};
    for(int attempt=0;attempt<7;++attempt){
        Vec3 point;
        if(attempt==0){
            const auto& approach=hound_approaches_[uint32_t(u.handle)];
            if(approach.target!=foe->handle||approach.count<2||!approach.ready)continue;
            point=approach.goal;
        }else if(attempt==6)point=u.position;
        else{
            Vec3 direction=rotated_y(away,angles[attempt-1]);
            point=enemy_contact(*foe,foe->position+direction*100+Vec3{0,1,0})+direction*(u.radius+.05f);
        }
        point.y=float(ground.height(point.x,point.z,layer));
        if(!finite(point)||std::abs(point.y-u.position.y)>5||!ground.clear(point,u.radius,layer)||!pet_landing_clear(crowd,u,point)||!ground.reachable(u.position,point,u.radius,layer))continue;
        Unit probe;probe.handle=u.handle;probe.team=u.team;probe.kind=u.kind;probe.pose_row=u.pose_row;probe.pet_skill=u.pet_skill;probe.target_handle=u.target_handle;probe.position=point;
        Vec3 facing=foe->position-point;probe.yaw=std::atan2(-facing.x,-facing.z);
        if(!melee_contact(crowd,probe))continue;
        Event blink;blink.kind=STATUS_EVENT;blink.unit_kind=u.kind;blink.source_id=u.logical_id;blink.team=1;blink.action_index=HOUND_BLINK_CUE;blink.position=u.position;emit(blink);
        Vec3 toward=foe->position-point;u.yaw=std::atan2(-toward.x,-toward.z);
        crowd.set_pose(u.handle,point,u.yaw);u.support_layer=layer;u.velocity=u.pose_velocity={};u.has_goal=false;u.routing=false;
        blink.position=point;emit(blink);return true;
    }
    return false;
}
int Combat::pet_ranged_slots(const Unit& u) const{
    if(u.kind!=HOUND_KIND)return 0;
    int slots=0;
    for(int slot=0;slot<3;++slot){
        const int skill=u.pet_skills[slot];
        if(u.afflictions[5]<=0&&pet_ranged_skill(skill)&&(u.pet_ready_mask&(1<<slot))&&u.pet_cooldowns[skill-1]<=0&&u.pet_mana+1e-8>=pet_skill_cost(skill))slots|=1<<slot;
    }
    return slots;
}
bool Combat::pet_ranged_contact(Crowd& crowd,const Unit& u,const Unit& enemy) const{
    if(enemy.hp<=0||enemy.shelter_mode==2||length(enemy.position-u.position)>data_.pet_ranged_reach)return false;
    const auto* geometry=pet_geometry(u);
    const Vec3 from=u.position+Vec3{0,geometry?(geometry[1]+geometry[4])*.5f:1.3f,0};
    const Vec3 to=enemy_contact(enemy,from);
    return crowd.allied_terrain.ray_clear(from,to);
}
bool Combat::pet_begin(Crowd& crowd,Unit& u,int ranged_slots,bool allow_melee){
    const bool contact=allow_melee&&melee_contact(crowd,u);
    if(u.kind!=HOUND_KIND){if(contact)begin(u);return contact;}
    bool continuing=u.pet_skill==2&&u.pet_combo_left>0;
    if(!continuing){
        std::array<int,3> ready{};int count=0;
        for(int slot=0;slot<3;++slot){int skill=u.pet_skills[slot];
            if(skill==PET_BODYGUARD)continue;
            if(pet_ranged_skill(skill)){
                if(ranged_slots&(1<<slot))ready[count++]=skill;
            }else if(u.afflictions[5]<=0&&skill&&(u.pet_ready_mask&(1<<slot))&&u.pet_cooldowns[skill-1]<=0&&u.pet_mana+1e-8>=pet_skill_cost(skill)&&!(skill==2&&u.hound_order==HOUND_HOLD)&&(skill==PET_BEE_FLURRY?pet_flurry_ready(crowd,u):contact))ready[count++]=skill;
        }
        if(!count&&!contact)return false;
        u.pet_skill=count?ready[std::min(count-1,int(random(u)*count))]:0;
        u.pet_combo_left=u.pet_skill==2?u.pet_combo_limit:0;u.action_hits.clear();
    }
    if(u.pet_skill==PET_BEE_FLURRY){
        u.pet_flurry_origin=u.position;u.pet_flurry_side={};u.pet_flurry_charge=.45;u.pet_combo_left=5;
        u.invuln=std::max(u.invuln,.05);
    }
    if(u.pet_skill==2){
        if(!pet_combo_blink(crowd,u)){u.pet_skill=0;u.pet_combo_left=0;}
        else{--u.pet_combo_left;u.action_hits.push_back(u.target_handle);u.invuln=std::max(u.invuln,.05);}
    }
    if(!continuing&&u.pet_skill){
        u.pet_mana=std::max(0.0,u.pet_mana-pet_skill_cost(u.pet_skill));
        u.pet_cooldowns[u.pet_skill-1]=5.0;++u.pet_cast_serial;
    }
    begin(u);
    if(u.pet_skill)pet_skill_event(crowd,u,PET_SKILL_STARTED);
    return true;
}

bool Combat::can_guard(const Unit& u) const{
    return snow_health_preference(u)!=0||(data_.slime_guard&&u.kind==SLIME_KIND&&!habaru_boss(u)&&!undersea_boss(u));
}
bool Combat::begin_enemy_guard_break(Unit& u){
    if(enemy_guard_break_owner_||joint_clock_<enemy_guard_break_ready_||u.target_handle||u.external_kind!=0||!can_guard(u))return false;
    const auto* hero=external_target(u);
    if(!hero||!hero->guarding||hero->id!=0)return false;
    u.action=ENEMY_GUARD_BREAK_WINDUP;u.action_active=true;u.action_time=0;u.has_goal=false;
    enemy_guard_break_owner_=u.handle;enemy_guard_break_ready_=joint_clock_+ENEMY_GUARD_BREAK_COOLDOWN;
    Event event;event.kind=STATUS_EVENT;event.source_id=u.logical_id;event.ticket_id=u.handle;event.unit_kind=u.kind;
    event.action_index=u.action;event.position=u.position;event.amount=ENEMY_GUARD_BREAK_TIME;emit(event);
    return true;
}
void Combat::raise_enemy_guard(Unit& u,double seconds){
    u.guard_left=seconds;u.blocking=true;u.has_goal=false;u.action=data_.actions[13];u.action_time=0;refresh_status(u);
    Event event;event.kind=STATUS_EVENT;event.source_id=u.logical_id;event.ticket_id=u.handle;event.unit_kind=u.kind;
    event.action_index=ENEMY_GUARD_RAISED;event.position=u.position;event.amount=seconds;emit(event);
}
bool Combat::enemy_guard(Crowd& crowd,Unit& u,double dt){
    if(!can_guard(u))return false;
    u.guard_cooldown=std::max(0.0,u.guard_cooldown-dt);
    const bool pressured=u.guard_pressure_hits>=3&&joint_clock_<u.guard_pressure_until&&u.guard_cooldown<=0;
    const auto* opponent=u.external_kind==0?external_target(u):nullptr;
    ExternalTarget pet_opponent;
    const Unit* pet=crowd.unit(u.target_handle);
    if(pressured&&u.retaliation>0){
        auto found=crowd.ids_.find(u.retaliation_source);
        if(found!=crowd.ids_.end()&&escort_kind(crowd.units_[found->second].kind)&&crowd.units_[found->second].team==1)
            pet=&crowd.units_[found->second];
    }
    if(pet&&pet->team==1&&escort_kind(pet->kind)&&pet->hp>0&&pet->shelter_mode!=2){
        pet_opponent.id=pet->logical_id;pet_opponent.foot=pet->position;pet_opponent.hp=pet->hp;
        pet_opponent.attack_reach=soldiers_[pet->kind].range;
        if(pet->action_active&&pet->pet_skill==0&&!pet->counter_active&&pet->target_handle==u.handle){
            pet_opponent.attack_serial=pet->attack_serial;
            pet_opponent.attack_facing={-std::sin(pet->yaw),0,-std::cos(pet->yaw)};
        }
        opponent=&pet_opponent;
    }
    // A patroller can take its first hits before it has committed to a pursuit.
    if(pressured&&u.external_kind<0&&!u.target_handle&&u.retaliation>0&&hero_row_>=0&&u.retaliation_source==targets_[hero_row_].id)
        opponent=&targets_[hero_row_];
    const int64_t swing_source=opponent==&pet_opponent?pet->handle:opponent?opponent->id:0;
    const bool new_swing=opponent&&opponent->attack_serial>0&&
        (swing_source!=u.guard_seen_source||opponent->attack_serial!=u.guard_seen_attack);
    if(!new_swing&&!pressured&&u.guard_left<=0&&u.guard_reaction<=0)return false;
    if(u.stun>0||u.frozen>0||u.action_active||!opponent||!opponent->targetable||opponent->hp<=0||
       (u.guard_radius>0&&(horizontal(u.position,u.guard_post)>2*u.guard_radius||horizontal(opponent->foot,u.guard_post)>2*u.guard_radius))){
        u.blocking=false;u.guard_left=0;u.guard_reaction=0;return false;
    }
    if(u.guard_left>0){
        u.guard_left=std::max(0.0,u.guard_left-dt);u.blocking=u.guard_left>0;
        if(u.blocking){u.has_goal=false;u.action=data_.actions[13];u.action_time+=dt;refresh_status(u);return true;}
    }
    Vec3 toward=opponent->foot-u.position;toward.y=0;
    const float distance=length(toward);
    const bool facing=distance>.001f&&dot(Vec3{-std::sin(u.yaw),0,-std::cos(u.yaw)},normalized(toward))>=.5f;
    const bool visible=facing&&distance<=std::clamp(opponent->attack_reach+u.radius,3.f,18.f)&&std::abs(opponent->foot.y-u.position.y)<=3.5f;
    if(u.guard_reaction>0){
        u.guard_reaction=std::max(0.0,u.guard_reaction-dt);
        if(!visible){u.guard_reaction=0;return false;}
        u.has_goal=false;
        if(u.guard_reaction==0){
            if(!crowd.terrain.ray_clear(u.position+Vec3{0,1,0},opponent->foot+Vec3{0,1,0}))return false;
            raise_enemy_guard(u,REACTIVE_GUARD_TIME);
        }
        return true;
    }
    if((!new_swing&&!pressured)||!visible)return false;
    if(new_swing){u.guard_seen_attack=opponent->attack_serial;u.guard_seen_source=swing_source;}
    if(u.guard_cooldown>0||(!pressured&&dot(normalized(opponent->attack_facing),normalized(toward))>-.5f)||
       !crowd.terrain.ray_clear(u.position+Vec3{0,1,0},opponent->foot+Vec3{0,1,0}))return false;
    if(pressured){
        if(opponent==&pet_opponent){u.target_handle=pet->handle;u.external_kind=-1;}
        else {u.target_handle=0;u.external_kind=0;u.external_target=opponent->id;}
        u.guard_pressure_hits=0;u.guard_cooldown=1.8;
        raise_enemy_guard(u,PRESSURE_GUARD_TIME);
        return true;
    }
    if(snow_health_preference(u)!=0?bag_draw(u.snow_guard_bag,0b11,random(u))==0:
       opponent==&pet_opponent?bag_draw(u.pet_guard_bag,0b11111,random(u))>=3:random(u)>=.60)return false;
    u.guard_reaction=.075+.05*random(u);u.guard_cooldown=1.8;u.has_goal=false;
    return true;
}
void Combat::before_move(Crowd& crowd,double delta){
    if(!enabled_)return;
    if(enemy_guard_break_owner_){
        const auto* owner=crowd.unit(enemy_guard_break_owner_);
        if(!owner||!owner->action_active)enemy_guard_break_owner_=0;
    }
    if(enemy_charge_owner_){
        const auto* owner=crowd.unit(enemy_charge_owner_);
        if(!owner||!owner->action_active||!enemy_charge_action(owner->action))enemy_charge_owner_=0;
    }
    for(auto it=pet_sequence_targets_.begin();it!=pet_sequence_targets_.end();){
        auto owner=crowd.unit(it->first);
        if(!owner||(owner->pet_skill!=2&&owner->pet_skill!=PET_BEE_FLURRY)||owner->target_handle!=it->second.handle)it=pet_sequence_targets_.erase(it);
        else ++it;
    }
    advance_rescues(crowd,delta);
    joint_clock_+=delta;
    const float aggro_bonus=player_aggro_bonus();
    threats_.clear();mirror_targets_.clear();first_taunt_=0;latest_taunt_=0;
    hound_escort_query_radius_=0;hound_claims_.clear();hound_searches_left_=3;nearby_hero_pursuers_=0;
    hound_approaches_.resize(crowd.units_.size());hound_approach_units_.clear();
    const Unit* focused_enemy=crowd.unit(hound_focus_target_);
    bool focus_reachable=false;
    if(hound_focus_target_){
        auto& ground=crowd.allied_terrain;
        Vec3 from=hound_hero_row_>=0?targets_[hound_hero_row_].foot:Vec3{NAN,0,0};
        if(!focused_enemy||focused_enemy->team!=0||focused_enemy->hp<=0||focused_enemy->shelter_mode==2||
           !finite(from)||horizontal(from,focused_enemy->position)>120){
            focused_enemy=nullptr;
            hound_focus_target_=0;hound_order_=HOUND_DEFEND;
        }else{
            const int layer=ground.choose_layer(from);
            if(layer>=0){
                from.y=float(ground.height(from.x,from.z,layer));
                focus_reachable=std::abs(ground.height(focused_enemy->position.x,focused_enemy->position.z,layer)-focused_enemy->position.y)<5&&
                    ground.reachable(from,focused_enemy->position,.5f,layer);
            }
        }
    }
    enemy_unit_claims_.assign(crowd.units_.size(),0);enemy_external_claims_.assign(targets_.size(),0);
    bool has_commanded_pet=false;bodyguards_.clear();
    for(const auto& u:crowd.units_)if(u.alive){
        if(u.team==1&&u.kind==HOUND_KIND&&u.hp>0&&std::any_of(u.pet_skills.begin(),u.pet_skills.end(),[](int skill){return skill==PET_BODYGUARD;}))bodyguards_.push_back(u.handle);
        if(u.team==0){
            if(auto other=crowd.unit(u.target_handle);other&&other->team==1)++enemy_unit_claims_[uint32_t(other->handle)];
            else if(auto other=external_target(u)){
                ++enemy_external_claims_[size_t(other-targets_.data())];
                Vec3 foot;
                if(other->kind==0&&target(crowd,u,foot)&&horizontal(u.position,foot)<=28&&std::abs(u.position.y-foot.y)<=3.5f)++nearby_hero_pursuers_;
            }
        }
        if(u.mirror_actions>0&&u.target_handle)mirror_targets_.push_back(u.target_handle);
        if(u.team==1&&escort_kind(u.kind)){
            has_commanded_pet|=u.guard_radius>0;
            if(focused_enemy&&!focus_reachable&&u.guard_radius>0){
                Vec3 goal;
                focus_reachable=(pet_ranged_slots(u)&&pet_ranged_contact(crowd,u,*focused_enemy))||pet_contact_goal(crowd,u,*focused_enemy,goal);
            }
            if(u.target_handle)hound_claims_.push_back(u.target_handle);
            auto& approach=hound_approaches_[uint32_t(u.handle)];
            if(approach.owner!=u.handle||approach.target!=u.target_handle){approach={};approach.owner=u.handle;approach.target=u.target_handle;}
            hound_approach_units_.push_back(uint32_t(u.handle));
            if(!u.target_handle||u.hound_order==HOUND_HOLD){approach.count=1;approach.ready=false;}
        }
        if(u.team==0&&u.action_active&&u.target_handle)threats_.insert(u.target_handle);
        if(u.team==1&&(u.kind==7||u.kind==133)&&u.buff_left>0&&u.shelter_mode==0&&(!first_taunt_||u.handle<first_taunt_))first_taunt_=u.handle;
    }
    if(hound_focus_target_&&(!has_commanded_pet||!focus_reachable)){hound_focus_target_=0;hound_order_=HOUND_DEFEND;}
    std::sort(hound_approach_units_.begin(),hound_approach_units_.end(),[&](uint32_t a,uint32_t b){
        const auto& x=crowd.units_[a];const auto& y=crowd.units_[b];
        return x.target_handle!=y.target_handle?x.target_handle<y.target_handle:x.logical_id<y.logical_id;
    });
    for(size_t first=0;first<hound_approach_units_.size();){
        size_t end=first+1;auto target=crowd.units_[hound_approach_units_[first]].target_handle;
        while(end<hound_approach_units_.size()&&crowd.units_[hound_approach_units_[end]].target_handle==target)++end;
        int count=int(end-first);
        for(size_t i=first;i<end;++i){
            auto& approach=hound_approaches_[hound_approach_units_[i]];
            float angle=float(2*M_PI*(i-first)/count);
            if(approach.count!=count||approach.angle!=angle)approach.ready=false;
            approach.count=count;approach.angle=angle;
        }
        first=end;
    }
    for(auto& u:crowd.units_){
        if(!u.alive)continue;
        if(u.team==1&&escort_kind(u.kind))regen_pet_mana(u,delta);
        u.dodge_left=std::max(0.0,u.dodge_left-delta);u.dodge_cooldown=std::max(0.0,u.dodge_cooldown-delta);
        if(u.dodge_left<1e-8)u.dodge_left=0;
        const bool was_ice=u.frozen>0||u.ice_chill>0;
        u.ice_thaw=std::max(0.0,u.ice_thaw-delta);
        double frozen=u.frozen;if(frozen>0)u.ice_time+=std::min(delta,frozen);u.frozen=std::max(0.0,u.frozen-delta);u.live_delta=std::max(0.0,delta-frozen);
        u.ice_chill=std::max(0.0,u.ice_chill-u.live_delta);
        if(u.frozen>0)u.ice_strength=1;
        else if(u.ice_chill>0)u.ice_strength=.42f;
        else if(was_ice){u.ice_thaw=2;Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.team=u.team;e.source_id=u.logical_id;e.ticket_id=u.handle;e.action_index=6000;e.position=u.position;e.amount=u.ice_strength;emit(e);}
        double dt=u.live_delta;if(u.team==1&&u.kind==HOUND_KIND){for(auto& cooldown:u.pet_cooldowns)cooldown=std::max(0.0,cooldown-dt);if(u.pet_skill==2||u.pet_skill==PET_BEE_FLURRY)u.invuln=std::max(u.invuln,dt+.001);}u.retaliation=std::max(0.0,u.retaliation-dt);u.invuln=std::max(0.0,u.invuln-dt);u.stun=std::max(0.0,u.stun-dt);u.slow_left=std::max(0.0,u.slow_left-dt);
        if(ruby_boss(u)||undersea_boss(u))u.skill_left=std::max(0.0,u.skill_left-dt);
        u.confusion_left=std::max(0.0,u.confusion_left-dt);
        guardian_tick(crowd,u,delta);if(u.hp<=0)continue;
        if(ruby_boss(u)){
            u.ruby_holy_left=std::max(0.0,u.ruby_holy_left-delta);
            for(auto& left:u.ruby_ward_left)left=std::max(0.0,left-delta);
        }
        if(u.recover_left>0){
            const double span=std::min(delta,u.recover_left);
            u.recover_left=std::max(0.0,u.recover_left-delta);u.recover_tick+=span;
            while(u.recover_tick+1e-8>=1){
                u.recover_tick-=1;
                const double healed=std::min(u.max_hp-u.hp,u.max_hp*u.recover_ratio);
                if(healed>0){u.hp+=healed;zombie_cue(u,ZOMBIE_HEAL,healed);}
            }
        }
        if(undersea_boss(u)){
            u.utility_left=std::max(0.0,u.utility_left-dt);
            u.utility_wait=std::max(0.0,u.utility_wait-dt);
            u.buff_left=std::max(0.0,u.buff_left-dt);
        }
        if(u.kind==133)u.buff_left=std::max(0.0,u.buff_left-dt);
        if(u.slow_left<=0)u.slow_factor=1;
        u.attack_slow_left=std::max(0.0,u.attack_slow_left-dt);if(u.attack_slow_left<=0)u.attack_slow_factor=1;
        if(u.avatar_left>0){u.avatar_left=std::max(0.0,u.avatar_left-dt);if(u.avatar_left<=0){u.max_hp-=500;u.hp=std::min(u.hp,u.max_hp);}}
        u.status=(u.frozen>0?data_.status_bits[0]:0)|(u.slow_left>0?data_.status_bits[1]:0)|(u.stun>0?data_.status_bits[2]:0)|(u.invuln>0?data_.status_bits[3]:0);
        if(u.action==GUARDIAN_ARRIVAL){
            u.action_time+=delta;u.has_goal=false;u.velocity={};u.pose_velocity={};
            if(u.action_time+1e-8>=GUARDIAN_ARRIVAL_DURATION){u.action=data_.actions[0];u.action_active=false;u.action_time=0;u.think_left=0;if(u.invuln<1e-8)u.invuln=0;}
            continue;
        }
        if(u.bodyguard_left>0){u.has_goal=false;u.velocity=u.pose_velocity={};continue;}
        const Unit* escort_leader=u.escort_leader?crowd.unit(u.escort_leader):nullptr;
        if(u.escort_leader){
            if(!escort_leader){u.escort_leader=0;u.escort_slot=-1;u.guard_post=u.position;u.think_left=0;}
            else if((u.escort_refresh-=dt)<=0){
                u.escort_refresh=.15;
                Vec3 forward{-std::sin(escort_leader->yaw),0,-std::cos(escort_leader->yaw)};
                const auto post=PARTY_FORMATION_POSTS[u.escort_slot];
                const float spacing=std::max(1.f,(escort_leader->radius+u.radius+1)/7);
                Vec3 goal=escort_leader->position+(Vec3{-forward.z,0,forward.x}*post.x+forward*post.z)*spacing;
                const int layer=std::max(0,u.support_layer);
                // Blocked posts use a bounded nearby fallback; movement still uses native routing.
                for(int attempt=0;attempt<9;++attempt){
                    Vec3 point=goal;
                    if(attempt){const float angle=(attempt-1)*float(M_PI/4);point=point+Vec3{std::sin(angle),0,std::cos(angle)}*(u.radius+1);}
                    point.y=float(crowd.terrain.height(point.x,point.z,layer));
                    if(finite(point)&&crowd.terrain.clear(point,u.radius,layer)){u.guard_post=point;break;}
                }
            }
        }
        u.patrol_counter_cooldown=std::max(0.0,u.patrol_counter_cooldown-dt);
        if((u.counter_pending||u.counter_active)&&begin_counter(crowd,u))continue;
        if(data_.enemy_charge&&u.team==0){
            if(u.enemy_charge_cooldown>0)u.enemy_charge_cooldown=std::max(0.,u.enemy_charge_cooldown-dt);
            if(u.action_active&&enemy_charge_action(u.action)){u.has_goal=false;continue;}
        }
        if(u.team==1&&escort_kind(u.kind)&&soldiers_[u.kind].active){hound_guard(crowd,u,dt);continue;}
        if(u.mirror_actions>0){if(u.afflictions[5]<=0)mirror_decide(crowd,u,dt);else u.has_goal=false;continue;}
        if(u.team==0&&((u.kind==4&&!data_.skullpion.empty())||(u.kind==18&&!data_.finale_meta.empty())||(u.kind==17&&!data_.dark_lumina.empty()))){
            if(data_.enemy_charge&&!enemy_charge_owner_&&dt>0&&begin_enemy_charge(crowd,u))continue;
            if(u.kind==4)boss_decide(crowd,u,dt);
            else if(u.kind==18)finale_decide(crowd,u,dt);
            else lumina_decide(crowd,u,dt);
            continue;
        }
        if(u.team==1&&u.kind>=0&&u.kind<int(allies_.size())&&allies_[u.kind].active){if(!shelter(crowd,u,dt))ally_decide(crowd,u,dt);continue;}
        if(u.team!=0||u.kind<0||u.kind>=ENEMY_KIND_COUNT||!soldiers_[u.kind].active)continue;
        if(u.light_recoil_grace>0)u.light_recoil_grace=std::max(0.0,u.light_recoil_grace-dt);
        if(habaru_decide(crowd,u,dt))continue;
        if(enemy_guard(crowd,u,dt))continue;
        if(dt<=0)continue;
        if(u.action==ZOMBIE_CHARGE)continue;
        if(u.stun>0){u.action=data_.actions[6];continue;}
        if(u.action_active){u.has_goal=false;continue;}
        if(guardian(u)&&(u.blocking||u.ruby_holy_left>0)){u.action=data_.actions[13];u.has_goal=false;continue;}
        if(data_.enemy_charge&&!enemy_charge_owner_&&u.light_recoil_grace<=0&&begin_enemy_charge(crowd,u))continue;
        u.action=data_.actions[0];u.think_left-=dt;
        if(u.guard_radius>0){
            const auto& profile=soldiers_[u.kind];
            const bool returning=horizontal(u.position,u.guard_post)>2*u.guard_radius;
            const auto* hero=hero_row_>=0?&targets_[hero_row_]:nullptr;
            const bool alerted=(hero&&horizontal(hero->foot,u.guard_post)<=2*u.guard_radius&&
                horizontal(hero->foot,u.position)<=u.guard_radius*(u.external_kind==0?1.6f:1.2f)+aggro_bonus&&
                crowd.terrain.ray_clear(u.position+Vec3{0,1,0},hero->foot+Vec3{0,1,0}))||
                (escort_leader&&(escort_leader->target_handle||escort_leader->external_kind>=0||escort_leader->retaliation>0));
            if(returning||(!alerted&&u.retaliation<=0)){
                if(escort_leader){
                    const float gap=horizontal(u.position,u.guard_post);
                    if(gap>.6f)crowd.set_goal(u.handle,u.guard_post,profile.speed*(gap>4?2.f:1.f));
                    else {u.has_goal=false;u.yaw=escort_leader->yaw;}
                }else if(returning||u.external_kind>=0||u.target_handle)
                    crowd.set_goal(u.handle,u.guard_post,profile.speed*.55);
                u.external_kind=-1;u.target_handle=0;
                // Let the elite's party settle before its next patrol leg.
                if(u.body_scale==2&&u.has_goal&&horizontal(u.position,u.goal)<.15f)u.think_left=1.5;
                if(u.has_goal&&(horizontal(u.position,u.goal)<.15f||
                   (!escort_leader&&!returning&&u.think_left<=0&&horizontal(u.velocity,{})<.1f)))u.has_goal=false;
                if(!escort_leader&&!u.has_goal&&u.think_left<=0){
                    u.think_left=1.5+2*random(u);
                    for(int attempt=0;attempt<6;++attempt){
                        float angle=2*M_PI*random(u),distance=3+6*random(u);
                        Vec3 point=u.guard_post+Vec3{distance*std::cos(angle),0,distance*std::sin(angle)};
                        if(horizontal(u.position,point)<2||!crowd.terrain.segment(u.position,point,u.radius,std::max(0,u.support_layer)))continue;
                        crowd.set_goal(u.handle,point,profile.speed*.55);break;
                    }
                }
                if(u.has_goal){
                    Vec3 direction=u.goal-u.position;
                    float turn=std::remainder(std::atan2(-direction.x,-direction.z)-u.yaw,float(2*M_PI));
                    float amount=profile.turn_speed*float(dt);u.yaw+=std::clamp(turn,-amount,amount);
                }
                continue;
            }
            if(!u.target_handle&&u.external_kind<0)u.think_left=0;
        }
        Vec3 foot;
        if(u.think_left<=0||((u.target_handle||u.external_kind>=0)&&!target(crowd,u,foot))){choose_target(crowd,u);u.think_left=.1;}
        if(!target(crowd,u,foot)){continue;}
        const auto& profile=soldiers_[u.kind];Vec3 direction=foot-u.position;
        if(undersea_boss(u)&&horizontal(u.position,foot)<=20.0f&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1.6f,0},foot+Vec3{0,1.2f,0})){
            int support=0;
            if(u.hp<=u.max_hp*.6&&u.utility_left<=0){
                support=UNDERSEA_MEDITATION;u.utility_left=18.0;u.buff_left=0;
            }else if(u.utility_wait<=0){
                support=UNDERSEA_HAZE;u.utility_wait=14.0;
            }
            if(support){
                u.action=support;u.action_active=true;u.action_time=0;u.has_goal=false;
                u.yaw=std::atan2(-direction.x,-direction.z);
                zombie_cue(u,support,0,support==UNDERSEA_MEDITATION?36:15);
                continue;
            }
        }
        if(undersea_boss(u)&&u.skill_left<=0&&horizontal(u.position,foot)<=20.0f&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1.6f,0},foot+Vec3{0,1.2f,0})){
            begin(u);u.action=UNDERSEA_QIGONG;u.target_goal=foot;u.skill_left=6.0;
            u.yaw=std::atan2(-direction.x,-direction.z);
            zombie_cue(u,UNDERSEA_QIGONG,3,.75*30);
            continue;
        }
        if(guardian_decide(crowd,u,foot))continue;
        if(!guardian(u)&&ruby_boss(u)&&u.skill_left<=0&&horizontal(u.position,foot)<=19.0f&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0})){
            const Vec3 pad{64,4,64};
            int blades=0;
            for(auto handle:crowd.query(u.position-pad,u.position+pad,0)){
                const auto ally=crowd.unit(handle);
                if(ally&&ally->kind==SLIME_KIND&&(ally->pose_row==1||(data_.falken_boss&&ally->pose_row==2)))++blades;
            }
            if(data_.falken_boss){
                // Source AI 11037 weights, drawn without replacement; turn timing is fitted to real time.
                static constexpr int spells[]={RUBY_GROUP_RECOVER,FALKEN_SUMMON,FALKEN_DEATH,RUBY_PHYSICAL_REFLECT,RUBY_MAGIC_REFLECT,1,FALKEN_DRAIN,RUBY_HOLY_SHIELD};
                static constexpr int weights[]={3,6,4,4,4,5,5,10};
                uint64_t eligible=0;int offset=0;
                for(int i=0;i<8;++i){
                    if((i!=0||u.hp<u.max_hp*.5)&&(i!=1||blades==0)&&(i!=2||blades>0))eligible|=((uint64_t(1)<<weights[i])-1)<<offset;
                    offset+=weights[i];
                }
                if(eligible!=u.falken_eligible){u.falken_eligible=eligible;u.falken_draws=0;}
                int selected=bag_draw(u.falken_draws,eligible,random(u));int spell=1;offset=0;
                for(int i=0;i<8;++i){offset+=weights[i];if(selected<offset){spell=spells[i];break;}}
                if(spell==1){u.skill_left=1.6;}
                else{
                    u.action=spell;u.action_active=true;u.action_time=0;u.has_goal=false;u.skill_left=0;
                    u.target_goal=foot;u.yaw=std::atan2(-direction.x,-direction.z);
                    Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.action_index=spell;
                    e.position=spell==FALKEN_DRAIN||spell==FALKEN_DEATH?foot:u.position;e.amount=1;e.source_tick=30;emit(e);
                    continue;
                }
            }else{
            static constexpr int support[]={RUBY_MEND,RUBY_PHYSICAL_ABSORB,RUBY_MAGIC_ABSORB,RUBY_RECOVER,
                RUBY_PHYSICAL_REFLECT,RUBY_MAGIC_REFLECT,RUBY_HEAL,RUBY_PHYSICAL_NULL,RUBY_MAGIC_NULL,RUBY_GROUP_RECOVER,RUBY_HOLY_SHIELD};
            static constexpr int offense[]={RUBY_FROST,RUBY_METEOR,RUBY_CONFUSION};
            if(blades<=2&&!u.ruby_enraged){u.ruby_enraged=true;u.ruby_phase_casts=0;}
            // shortcut: Paired real-time casts use a fixed rotation; replace when original AI probabilities and turn scheduling are recovered.
            const bool attack=u.ruby_enraged&&(u.ruby_phase_casts++%2==0);
            u.action=attack?offense[u.ruby_offense++%3]:support[u.ruby_support++%11];
            u.action_active=true;u.action_time=0;u.has_goal=false;u.skill_left=0;
            u.target_goal=foot;u.yaw=std::atan2(-direction.x,-direction.z);
            Event event;event.kind=STATUS_EVENT;event.unit_kind=u.kind;event.source_id=u.logical_id;
            event.action_index=u.action;event.position=ruby_magic_attack(u.action)?foot:u.position;
            event.amount=5;event.source_tick=30;emit(event);
            continue;
            }
        }
        if(grave_boss(u)&&u.hp<=u.max_hp*.5&&u.combo_serial%3==0&&horizontal(u.position,foot)<=8.0f&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0})){
            ++u.combo_serial;
            u.action=GRAVE_EARTH_WARNING;u.action_active=true;u.action_time=0;u.has_goal=false;u.knockback={};
            zombie_cue(u,GRAVE_EARTH_WARNING,8.0,36.0);
            continue;
        }
        if(zombie_boss(u)&&u.hp<=u.max_hp*.5&&horizontal(u.position,foot)<=ZOMBIE_BLAST_RADIUS&&
           crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0})){
            u.action=ZOMBIE_CHARGE;u.action_active=true;u.action_time=0;u.has_goal=false;u.knockback={};
            u.hound_attack_direction=-1;
            zombie_cue(u,ZOMBIE_CHARGE,ZOMBIE_BLAST_RADIUS,ZOMBIE_FUSE*30);
            continue;
        }
        float desired=std::atan2(-direction.x,-direction.z),turn=std::remainder(desired-u.yaw,float(2*M_PI));
        float amount=profile.turn_speed*float(dt);u.yaw+=std::clamp(turn,-amount,amount);
        bool facing=std::abs(std::remainder(desired-u.yaw,float(2*M_PI)))<.35f;
        const auto* geometry=pet_geometry(u);
        bool reach=u.kind==1?gun_contact(crowd,u):horizontal(u.position,foot)<=profile.range*(geometry?geometry[6]:1)&&std::abs(foot.y-u.position.y)<=3.5f&&melee_contact(crowd,u);
        if(facing&&reach){
            if(!begin_enemy_guard_break(u))begin(u);
            continue;
        }
        float speed=profile.speed;
        const bool player_approach=u.external_kind==0&&!u.target_handle&&u.kind!=4&&u.kind!=17&&u.kind!=18&&
            !habaru_boss(u)&&!zombie_boss(u)&&!grave_boss(u)&&!ruby_boss(u)&&!undersea_boss(u);
        if(player_approach){
            // Count close pursuits once per tick; distant arrivals do not create their own slowdown.
            float crowding=std::clamp(float(nearby_hero_pursuers_-1)/9.f,0.f,1.f);
            float nearby=1-.65f*crowding;
            float approach=std::clamp((horizontal(u.position,foot)-40.f)/80.f,0.f,1.f);
            speed*=nearby+(3-nearby)*approach*approach*(3-2*approach);
        }else if(data_.slime_approach_boost&&u.kind==SLIME_KIND){
            float approach=std::clamp((horizontal(u.position,foot)-40.f)/80.f,0.f,1.f);
            speed*=1+2*approach*approach*(3-2*approach);
        }
        crowd.set_goal(u.handle,u.target_goal,speed);
    }
    // Multiple Codes in one frame coalesce to one retarget pass. A later Code
    // wins immediately; ordinary reacquisition still picks the oldest taunter.
    if(latest_taunt_)for(auto& u:crowd.units_)if(u.alive&&u.team==0&&u.kind>=0&&u.kind<ENEMY_KIND_COUNT&&soldiers_[u.kind].active&&u.action!=ZOMBIE_CHARGE&&!(habaru_boss(u)&&u.habaru_phase)){u.target_handle=latest_taunt_;u.external_kind=-1;u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.has_goal=false;u.routing=false;u.think_left=0;}
}
void Combat::mirror_decide(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    u.mirror_wait=std::max(0.0,u.mirror_wait-dt);
    if(u.stun>0||u.mirror_busy){u.has_goal=false;return;}
    u.think_left-=dt;
    auto victim=crowd.unit(u.target_handle);
    if(u.think_left<=0||(u.target_handle&&(!victim||victim->hp<=0))){
        auto claim=std::find(mirror_targets_.begin(),mirror_targets_.end(),u.target_handle);
        if(claim!=mirror_targets_.end())mirror_targets_.erase(claim);
        const float search=std::max(80.f,u.mirror_reach);
        u.think_left=.2;u.target_handle=0;float best=INFINITY;Vec3 pad{search+4,60,search+4};
        if(u.guard_radius>0)u.target_handle=guard_enemy(crowd,u);
        else{
            for(auto h:crowd.query(u.position-pad,u.position+pad,0)){
                auto other=crowd.unit(h);if(!other||other->hp<=0)continue;
                Vec3 point=enemy_contact(*other,u.position+Vec3{0,1,0});float gap=dot(point-u.position,point-u.position);
                // Prefer nearby unclaimed enemies without excluding a lone target.
                float score=gap+36*std::count(mirror_targets_.begin(),mirror_targets_.end(),h);
                if(gap>=search*search||score>=best)continue;
                if(!crowd.allied_terrain.ray_clear(u.position+Vec3{0,1,0},point))score+=search*search;
                if(score<best){best=score;u.target_handle=h;}
            }
        }
        victim=crowd.unit(u.target_handle);
        if(victim)mirror_targets_.push_back(u.target_handle);
    }
    if(!victim){
        u.has_goal=false;
        if(u.guard_radius>0){
            if(horizontal(u.position,u.guard_post)>.65f)crowd.set_goal(u.handle,u.guard_post,u.mirror_speed);
        }else if(hound_hero_row_>=0){
            Vec3 center=targets_[hound_hero_row_].foot;
            if(horizontal(u.position,center)>5.0f)crowd.set_goal(u.handle,center,u.mirror_speed);
        }
        return;
    }
    Vec3 goal=enemy_contact(*victim,u.position+Vec3{0,1,0});
    auto& ground=crowd.allied_terrain;
    Vec3 approach=goal;bool flank=false;
    if(dot(u.mirror_approach,u.mirror_approach)>0){
        approach=enemy_contact(*victim,victim->position+u.mirror_approach*100+Vec3{0,1,0})+u.mirror_approach;
        int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
        flank=layer>=0&&ground.clear(approach,u.radius,layer)&&ground.ray_clear(approach+Vec3{0,1,0},goal);
    }
    Vec3 offset=goal-u.position;offset.y=0;u.yaw=std::atan2(offset.x,offset.z);
    float distance=length(offset);
    bool basic=distance<=u.mirror_reach&&(!flank||horizontal(u.position,approach)<.6f);
    bool skill=u.mirror_wait<=0&&u.mirror_spell_reach>0&&distance<=u.mirror_spell_reach;
    bool clear=(basic||skill)&&ground.ray_clear(u.position+Vec3{0,1,0},goal);
    if(basic&&clear)u.has_goal=false;
    else crowd.set_goal(u.handle,flank?approach:goal,u.mirror_speed);
    if(clear&&u.mirror_wait<=0){
        int choice=std::min(u.mirror_actions-1,int(random(u)*u.mirror_actions));
        Event event;event.kind=STATUS_EVENT;event.team=1;event.unit_kind=u.kind;event.source_id=u.logical_id;event.target_id=victim->logical_id;event.ticket_id=u.handle;event.position=goal;event.action_index=400+choice;event.amount=basic?1:0;emit(event);
        u.mirror_wait=.35+double((u.rng>>16)%500)/1000;
    }
}
void Combat::deliver(Crowd& crowd,const Unit& unit,double amount,bool projectile,Vec3 origin){
    amount*=unit.enemy_damage_scale;
    if(unit.target_handle){
        auto victim=crowd.unit(unit.target_handle);if(!victim)return;
        double before=victim->hp;Vec3 foot;target(crowd,unit,foot);Hit hit;
        hit.source_id=unit.logical_id;hit.amount=amount;hit.projectile=projectile;hit.magical=magical_attack(unit.kind,unit.action,projectile);hit.direction=normalized(foot-origin);hit.counter=unit.counter_active;hit.guard_break=guardian(unit)&&unit.guardian_tech==505;
        hit.joint_pet=unit.team==1&&escort_kind(unit.kind)&&unit.pet_skill==0&&!unit.counter_active;
        hit.joint_attack=hit.joint_pet;
        auto result=this->hit(crowd,unit.target_handle,hit);
        if((unit.action==ZOMBIE_DRAIN||(guardian(unit)&&unit.guardian_tech==8150))&&result.accepted)confirm_zombie_drain(crowd,unit.handle,before-std::max(0.0,result.hp));
    }
    else{
        Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=unit.kind;event.action_index=unit.action;event.source_id=unit.logical_id;event.target_id=unit.external_target;event.external_kind=unit.external_kind;event.position=origin;event.amount=amount;event.projectile=projectile;
        if(unit.action==ZOMBIE_DRAIN||(guardian(unit)&&unit.guardian_tech==8150)){event.ticket_id=unit.handle;if(guardian(unit))event.action_index=ZOMBIE_DRAIN;}
        if(guardian(unit)&&unit.guardian_tech==505)event.action_index=GUARD_BREAK_HIT;
        if(unit.counter_active)event.action_index=718;
        if(unit.handle==enemy_guard_break_owner_)event.action_index=GUARD_BREAK_HIT;
        external_hit(crowd,event);
    }
}
void Combat::advance(Crowd& crowd,Unit& u,double delta){
    const bool starting=u.just_started;
    if(starting){u.just_started=false;if(!pet_skin_count(u.kind)||pet_timeline(u)[2]!=0)return;}
    const bool double_edge=u.action==HABARU_DOUBLE_EDGE;
    const bool guard_break=u.handle==enemy_guard_break_owner_;
    const bool hound_edge=double_edge&&u.kind==HOUND_KIND;
    double remaining=starting?0:delta*(double_edge?22:30);
    while(u.action_active&&(starting||remaining>1e-9)){
        const auto& kit=soldiers_[u.kind].kit;
        int phase=u.soldier_phase;
        const float* timeline=pet_skin_count(u.kind)?pet_timeline(u):nullptr;
        double duration=timeline?timeline[0]:kit[phase],before=u.phase_tick;
        double step=std::min(remaining,std::max(0.0,duration-before)),after=before+step,start=u.attack_tick-before;
        auto marker=[&](double tick,EventKind kind){
            if(!(before+1e-8<tick&&after+1e-8>=tick))return;
            Event event;event.kind=kind;event.source_id=u.logical_id;event.source_tick=start+tick;event.target_id=u.target_handle?crowd.unit(u.target_handle)?crowd.unit(u.target_handle)->logical_id:0:u.external_target;event.position=u.position;event.unit_kind=u.kind;
            if(kind==MELEE){u.light_recoil_grace=0;emit(event);if(soldiers_[u.kind].contact_end==0&&melee_contact(crowd,u))deliver(crowd,u,soldiers_[u.kind].damage,false,u.position);}
            else{
                event.position=u.position+rotated_y(data_.muzzle,u.yaw);
                if(kind==MUZZLE){emit(event);return;}
                if(!gun_contact(crowd,u))return;
                Vec3 foot;target(crowd,u,foot);Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=u.kind;shot.position=event.position;shot.direction=normalized(foot+Vec3{0,1.3f,0}-shot.position);shot.life=data_.bullet_life;shot.speed=data_.bullet_speed;shot.tail=data_.bullet_tail;shot.radius=data_.bullet_radius;shot.damage=soldiers_[u.kind].damage*u.enemy_damage_scale;shot.source_team=0;shot.scale=data_.enemy_size;shot.target_kind=u.external_kind;shot.target_id=u.external_target;
                for(const auto& ext:targets_)if(ext.id==u.external_target&&ext.kind==u.external_kind){shot.ignore_building=ext.ignore_building;break;}
                projectiles_.push_back(shot);event.projectile_id=shot.id;event.direction=shot.direction;event.amount=shot.damage;emit(event);
            }
        };
        if(timeline){
            for(int i=0;i<int(timeline[1]);++i){
                if(hound_edge&&u.primary_hit)break;
                double tick=timeline[2+i*2];
                if((before+1e-8>=tick||after+1e-8<tick)&&!(starting&&tick==0))continue;
                int cue=int(timeline[3+i*2]);if(!starting)pet_cue(u,cue,tick);
                bool contact=u.kind!=HOUND_KIND?(cue>=10000?companion_contact_cue(cue):(cue==135||cue==138||cue==164||cue==165)):companion_contact_cue(cue);
                if(!contact)continue;
                if(u.team==1&&u.kind==HOUND_KIND&&u.pet_skill){
                    if(pet_ranged_skill(u.pet_skill)){
                        const auto* enemy=crowd.unit(u.target_handle);
                        if(enemy&&pet_ranged_contact(crowd,u,*enemy))pet_skill_event(crowd,u,PET_SKILL_CONTACT);
                    }else if(melee_contact(crowd,u))pet_skill_event(crowd,u,PET_SKILL_CONTACT);
                    continue;
                }
                u.light_recoil_grace=0;
                if(guard_break){
                    if(u.primary_hit)continue;
                    u.primary_hit=true;
                    const auto* hero=external_target(u);
                    if(hero&&hero->guarding&&melee_contact(crowd,u))deliver(crowd,u,soldier_damage(u)*GUARD_BREAK_DAMAGE,false,u.position);
                    continue;
                }
                if(double_edge&&u.primary_hit)continue;
                const bool landed=melee_contact(crowd,u);
                if(double_edge){
                    u.primary_hit=true;
                    if(hound_edge){
                        Vec3 contact=u.position+rotated_y({0,0,-1.4f},u.yaw);
                        if(landed)target(crowd,u,contact);
                        Event cue;cue.kind=STATUS_EVENT;cue.action_index=HABARU_DOUBLE_EDGE;cue.unit_kind=u.kind;
                        cue.source_id=u.logical_id;cue.source_tick=tick;cue.amount=1;cue.position=contact+Vec3{0,.8f,0};emit(cue);
                    }else zombie_cue(u,HABARU_DOUBLE_EDGE);
                }
                if(guardian(u)){
                    if(u.guardian_hits++>=1)continue;
                    const int tech=u.guardian_tech;
                    if((tech==304||tech==305)&&bag_draw(u.guardian_accuracy_draws,(uint64_t(1)<<(tech==304?25:50))-1,random(u))>=(tech==304?22:43))continue;
                    const auto* foe=crowd.unit(u.target_handle);const auto* ext=external_target(u);
                    if(tech==505&&!(foe?foe->blocking:ext&&ext->guarding))continue;
                    const double scale=tech==50?.8:tech==104?1.35:tech==105?1.42:tech==304?1.5:tech==305||tech==505?1.6:1;
                    if(landed)deliver(crowd,u,soldier_damage(u)*scale,false,u.position);
                }else if(landed)deliver(crowd,u,soldier_damage(u)*(hound_edge?1.45:double_edge?2:1),false,u.position);
            }
        }
        else if(phase==MELEE_A)marker(kit[5],MELEE);
        else if(phase==MELEE_B)marker(kit[6],MELEE);
        else if(phase==FIRE){marker(kit[7],MUZZLE);marker(kit[8],BULLET);}
        // Begin already delivered frame-zero audio; dispatch its impact without advancing the pose.
        if(starting)return;
        // A source active window can catch a late arrival, but never hit twice.
        if(phase==MELEE_A&&!u.primary_hit&&soldiers_[u.kind].contact_end>0&&before<soldiers_[u.kind].contact_end&&after+1e-8>=kit[5]&&melee_contact(crowd,u)){
            u.primary_hit=true;deliver(crowd,u,soldiers_[u.kind].damage,false,u.position);
        }
        u.phase_tick=after;u.attack_tick+=step;u.action_time=u.phase_tick/30;remaining-=step;
        if(after+1e-8<duration)break;
        if(guardian(u)){if(u.guardian_tech==50&&u.guardian_combo>1)--u.guardian_combo;else{u.guardian_tech=0;u.skill_left=1.2;}}
        if(phase==MELEE_A&&kit[18]>0&&melee_contact(crowd,u))u.soldier_phase=PREPARE;
        else if(phase==PREPARE)u.soldier_phase=MELEE_B;
        else if(phase==FIRE)u.soldier_phase=++u.soldier_shots<3?FIRE:RELOAD;
        else{
            u.action_active=false;u.action=data_.actions[0];u.action_time=0;
            u.light_recoil_grace=0;
            if(u.pet_skill!=2)u.pet_skill=0;
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
                float radius=2*shot.radius;Vec3 pad=Vec3{radius,2,radius}+pet_query_padding_;
                for(auto handle:crowd.query(shot.position-pad,shot.position+pad,1)){
                    auto victim=crowd.unit(handle);if(!victim||!ally_segment(*victim,shot.position,shot.position,radius)||!crowd.terrain.ray_clear(shot.position+Vec3{0,1,0},victim->position+Vec3{0,1,0}))continue;
                    Hit damage;damage.amount=shot.damage;damage.source_id=shot.source_id;damage.projectile=true;damage.magical=magical_attack(shot.owner_kind,shot.owner_kind==4?108:300+shot.effect_kind,true);hit(crowd,handle,damage);
                }
                for(const auto& victim:targets_)if(victim.kind==0&&victim.hp>0&&victim.targetable&&body_contact(shot.position,shot.position,victim.foot,radius)&&crowd.terrain.ray_clear(shot.position+Vec3{0,1,0},victim.foot+Vec3{0,1,0})){
                    Event e;e.kind=EXTERNAL_DAMAGE;e.unit_kind=18;e.source_id=shot.source_id;e.target_id=victim.id;e.external_kind=0;e.position=shot.position;e.amount=shot.damage;e.projectile=true;external_hit(crowd,e);
                }
            }
            if(shot.age<shot.life)projectiles_[count++]=shot;
            continue;
        }
        if(shot.life<=0){if(shot.owner_kind==18&&shot.effect_kind==2)continue;Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=shot.source_team;event.unit_kind=shot.owner_kind;emit(event);continue;}
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
        warn_projectile(crowd,shot);
        if(shot.source_team==1){
            float world=crowd.terrain.projectile_fraction(before,shot.position,shot.radius);bool impacted=world>=0;
            if(impacted)shot.position=before+(shot.position-before)*world;
            {
                Vec3 pad{shot.radius+4,shot.radius+7,shot.radius+4},low{std::min(before.x,shot.position.x),std::min(before.y,shot.position.y),std::min(before.z,shot.position.z)},high{std::max(before.x,shot.position.x),std::max(before.y,shot.position.y),std::max(before.z,shot.position.z)};
                Handle chosen=0;float nearest=2;
                for(auto h:crowd.query(low-pad,high+pad,0)){auto e=crowd.unit(h);if(!e)continue;float t=enemy_segment(*e,before,shot.position,shot.radius);if(t>=0&&t<nearest){nearest=t;chosen=h;}}
                if(chosen){
                    Hit hit;hit.source_id=shot.source_id;hit.amount=shot.damage;hit.projectile=true;hit.magical=magical_attack(shot.owner_kind,300+shot.effect_kind,true);hit.direction=shot.direction;hit.heavy=shot.heavy;
                    if(shot.cast){auto& c=*shot.cast;c.rng^=c.rng>>12;c.rng^=c.rng<<25;c.rng^=c.rng>>27;if(double((c.rng*2685821657736338717ull)>>11)*(100.0/9007199254740992.0)<c.critical){hit.amount*=2;hit.critical=true;}}
                    if(this->hit(crowd,chosen,hit).accepted&&shot.cast){if(auto owner=crowd.unit(shot.cast->owner)){owner->chain_left=1.75;if(!shot.cast->confirmed){shot.cast->confirmed=true;++owner->chain_count;}}}
                    shot.position=before+(shot.position-before)*nearest;impacted=true;
                }
            }
            if(impacted||shot.age>=shot.life){if(!impacted&&shot.owner_kind==18&&shot.effect_kind==2)continue;Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.team=1;event.unit_kind=shot.owner_kind;emit(event);}else projectiles_[count++]=shot;
            continue;
        }
        bool impacted=!crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.ignore_building);
        if(shot.owner_kind==18&&(shot.effect_kind==2||(!shot.power&&shot.effect_kind==3))){
            float floor=float(crowd.terrain.height(shot.position.x,shot.position.z));
            if(std::isfinite(floor)&&shot.position.y<=floor+.2f){shot.position.y=floor+.2f;impacted=true;}
        }
        auto external_hit=[&](const ExternalTarget& victim){Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=shot.owner_kind;if(shot.owner_kind==4){event.action_index=108;event.heavy=true;}if(shot.owner_kind==18)event.action_index=300+shot.effect_kind;if(shot.effect_kind==UNDERSEA_QIGONG)event.action_index=UNDERSEA_QIGONG;event.source_id=shot.source_id;event.target_id=victim.id;event.external_kind=victim.kind;event.position=before;event.amount=shot.damage;event.projectile=true;event.direction=shot.direction;this->external_hit(crowd,event);};
        if(impacted&&shot.target_kind==2&&crowd.terrain.ray_clear(before,shot.position+shot.direction*.5f,shot.target_id))
            for(const auto& victim:targets_)if(victim.kind==2&&victim.id==shot.target_id&&victim.hp>0){external_hit(victim);break;}
        Vec3 tail=shot.position-shot.direction*shot.tail;
        if(!impacted)for(const auto& victim:targets_)if(victim.kind==0&&victim.hp>0&&victim.targetable&&(victim.body_bounds()?box_segment(before,shot.position,victim.minimum,victim.maximum,shot.radius)>=0:body_contact(tail,shot.position,victim.foot,shot.radius))){external_hit(victim);impacted=true;break;}
        if(!impacted){
            Vec3 pad=Vec3{shot.radius,shot.radius,shot.radius}+pet_query_padding_;Vec3 low{std::min(tail.x,shot.position.x),std::min(tail.y,shot.position.y)-1.8f,std::min(tail.z,shot.position.z)},high{std::max(tail.x,shot.position.x),std::max(tail.y,shot.position.y),std::max(tail.z,shot.position.z)};
            for(auto handle:crowd.query(low-pad,high+pad,1)){
                auto victim=crowd.unit(handle);if(!victim||!ally_segment(*victim,tail,shot.position,shot.radius))continue;
                Hit damage;damage.amount=shot.damage;damage.source_id=shot.source_id;damage.projectile=true;damage.magical=magical_attack(shot.owner_kind,shot.owner_kind==4?108:300+shot.effect_kind,true);damage.direction=shot.direction;hit(crowd,handle,damage);impacted=true;break;
            }
        }
        if(!impacted)for(const auto& victim:targets_){
            if(victim.hp<=0||!victim.targetable||victim.kind==0)continue;
            bool contact=victim.kind==2?shot.target_kind==2&&shot.target_id==victim.id&&length(shot.position-Vec3{std::clamp(shot.position.x,victim.minimum.x,victim.maximum.x),std::clamp(shot.position.y,victim.minimum.y,victim.maximum.y),std::clamp(shot.position.z,victim.minimum.z,victim.maximum.z)})<.35f:body_contact(tail,shot.position,victim.foot,shot.radius);
            if(contact){external_hit(victim);impacted=true;break;}
        }
        if(impacted||shot.age>=shot.life){
            if(!impacted&&shot.owner_kind==18&&shot.effect_kind==2)continue;
            Event event;event.kind=PROJECTILE_IMPACT;event.unit_kind=shot.owner_kind;event.action_index=shot.effect_kind;event.source_id=shot.source_id;event.projectile_id=shot.id;event.position=shot.position;event.direction=shot.direction;if(shot.owner_kind==18&&(shot.effect_kind==0||shot.effect_kind==2)&&shot.power)event.source_tick=1;emit(event);
            if(shot.owner_kind==18&&!shot.power&&shot.effect_kind==2){
                for(int i=0;i<5;++i){auto child=shot;child.id=next_projectile_++;child.power=true;child.age=0;child.life=data_.finale_ranges[3];child.speed=8*data_.finale_scale;child.damage*=.5;child.position.y+=.4f*data_.finale_scale*data_.enemy_size;child.direction={float(std::sin(i*2*M_PI/5)),0,float(std::cos(i*2*M_PI/5))};projectiles_.push_back(child);}
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
bool Combat::begin_enemy_charge(Crowd& crowd,Unit& u){
    if(guardian(u)||u.action_active||u.blocking||u.guard_reaction>0||u.stun>0||u.air_phase||u.habaru_phase||u.dodge_left>0||u.enemy_charge_cooldown>0||
       u.external_kind!=0||u.external_target!=0||u.target_handle||hero_row_<0||
       !((u.kind>=0&&u.kind<ENEMY_KIND_COUNT&&soldiers_[u.kind].active)||(u.kind==4&&!data_.skullpion.empty())))return false;
    const auto& hero=targets_[hero_row_];
    const float gap=horizontal(u.position,hero.foot), minimum=std::max(4.5f,u.radius+1.f);
    if(!hero.targetable||hero.hp<=0||gap<minimum||gap>std::max(10.f,minimum+4.f)||std::abs(u.position.y-hero.foot.y)>2.5f||
       (u.guard_radius>0&&(horizontal(u.position,u.guard_post)>2*u.guard_radius||horizontal(hero.foot,u.guard_post)>2*u.guard_radius)))return false;
    const Vec3 toward{(hero.foot.x-u.position.x)/gap,0,(hero.foot.z-u.position.z)/gap};
    const int layer=u.support_layer>=0?u.support_layer:crowd.terrain.choose_layer(u.position);
    if(layer<0||!crowd.terrain.ray_clear(u.position+Vec3{0,1,0},hero.foot+Vec3{0,1,0})||
       !crowd.terrain.segment(u.position,hero.foot-toward*std::max(1.f,u.radius),u.radius,layer)){
        u.enemy_charge_cooldown=.3;
        return false;
    }
    u.yaw=u.kind==4?std::atan2(toward.x,toward.z):std::atan2(-toward.x,-toward.z);
    u.dash_direction=toward;u.dash_previous=u.position;u.hound_attack_direction=-1;
    u.action=ENEMY_CHARGE_WINDUP;u.action_active=true;u.action_time=0;u.phase_tick=0;u.primary_hit=false;
    u.has_goal=false;u.blocking=false;u.guard_left=u.guard_reaction=0;u.enemy_charge_cooldown=5.0;
    enemy_charge_owner_=u.handle;
    attack_started(u);
    return true;
}
void Combat::advance_enemy_charge(Crowd& crowd,Unit& u,double dt){
    if(u.stun>0){u.action_active=false;u.action=u.kind==4?100:data_.actions[6];return;}
    if(dt<=0||u.frozen>0)return;
    const auto* hero=hero_row_>=0?&targets_[hero_row_]:nullptr;
    const bool can_hit=hero&&hero->targetable&&hero->hp>0&&!hero->evading;
    const float speed=ENEMY_CHARGE_SPEED*u.slow_factor;
    if(u.action==ENEMY_CHARGE_RECOVERY){
        if((u.action_time+=dt)+1e-8>=ENEMY_CHARGE_RECOVERY_TIME){u.action_active=false;u.action=u.kind==4?100:data_.actions[0];u.action_time=0;}
        return;
    }
    if(u.action==ENEMY_CHARGE_WINDUP){
        u.action_time+=dt*u.attack_slow_factor;
        u.phase_tick=std::min(5.0,8*u.action_time);
        if(u.action_time+1e-8>=ENEMY_CHARGE_WINDUP_TIME){u.action=ENEMY_CHARGE_RUSH;u.action_time=0;}
    }else{
        u.action_time+=dt;
        if(can_hit&&!u.primary_hit&&charge_contact(u,*hero,u.dash_previous,u.position)>=0&&
           crowd.terrain.ray_clear(u.dash_previous+Vec3{0,1,0},hero->foot+Vec3{0,1,0})){
            u.primary_hit=true;
            const double damage=u.kind==4&&!data_.skullpion.empty()?data_.skullpion[1]:soldiers_[u.kind].damage;
            deliver(crowd,u,damage,false,u.dash_previous);
            if(hero->guarding){u.action=ENEMY_CHARGE_RECOVERY;u.action_time=0;return;}
        }
        if(u.action_time+1e-8>=ENEMY_CHARGE_RUSH_TIME||horizontal(u.dash_previous,u.position)<.0001f){
            u.action=ENEMY_CHARGE_RECOVERY;u.action_time=0;return;
        }
    }
    if(!can_hit||u.primary_hit||speed<=0||u.attack_slow_factor<=0)return;
    const bool windup=u.action==ENEMY_CHARGE_WINDUP;
    const double windup_left=windup?(ENEMY_CHARGE_WINDUP_TIME-u.action_time)/u.attack_slow_factor:0;
    const double rush_left=ENEMY_CHARGE_RUSH_TIME-(windup?0:u.action_time);
    if(windup_left>.55)return;
    const float crossing=charge_contact(u,*hero,u.position,u.position+u.dash_direction*float(speed*rush_left));
    if(crossing>=0)warn_hero(crowd,u.logical_id,u.position,std::max(1.0/120,windup_left+crossing*rush_left),true);
}
void Combat::warn_hero(Crowd& crowd,int64_t source,Vec3 origin,double seconds,bool charge){
    if(hero_row_<0||seconds<=0||seconds>.55)return;
    const auto& hero=targets_[hero_row_];
    if(hero.id!=0||hero.hp<=0||!hero.targetable||!crowd.terrain.ray_clear(origin+Vec3{0,1,0},hero.foot+Vec3{0,1,0}))return;
    if(hero_dodge_threat_.seconds<0||seconds<hero_dodge_threat_.seconds)hero_dodge_threat_={seconds,source,origin,charge};
}
void Combat::warn_melee(Crowd& crowd,const Unit& u,double delta){
    if(u.team!=0||u.live_delta<=0||u.stun>0||u.frozen>0||hero_row_<0)return;
    const auto& hero=targets_[hero_row_];
    if(u.handle==enemy_guard_break_owner_&&(u.primary_hit||!hero.guarding))return;
    if(u.action==ZOMBIE_CHARGE||u.action==GRAVE_EARTH_WARNING){
        const float radius=u.action==ZOMBIE_CHARGE?ZOMBIE_BLAST_RADIUS:8.f;
        if(horizontal(u.position,hero.foot)<=radius&&std::abs(u.position.y-hero.foot.y)<=(u.action==ZOMBIE_CHARGE?5.f:1.f))
            warn_hero(crowd,u.logical_id,u.position,(u.action==ZOMBIE_CHARGE?ZOMBIE_FUSE:1.2)-u.action_time-delta);
        return;
    }
    if(u.target_handle||u.external_kind!=0||u.external_target!=0||u.attack_slow_factor<=0)return;
    double ticks=-1;
    if(u.counter_active){if(!u.counter_hit)ticks=(u.counter_contact-u.action_time)*30;}
    else if(u.action==data_.actions[1]||u.action==data_.actions[3]||u.action==HABARU_DOUBLE_EDGE||u.action==HABARU_COUNTER){
        if(const auto* timeline=pet_skin_count(u.kind)?pet_timeline(u):nullptr){
            for(int i=0;i<int(timeline[1]);++i){
                int cue=int(timeline[3+i*2]);
                bool contact=u.kind==HOUND_KIND?companion_contact_cue(cue):(cue>=10000?companion_contact_cue(cue):(cue==135||cue==138||cue==164||cue==165));
                if(contact&&timeline[2+i*2]>u.phase_tick+1e-8){ticks=timeline[2+i*2]-u.phase_tick;break;}
            }
        }else ticks=soldiers_[u.kind].kit[u.soldier_phase==MELEE_B?6:5]-u.phase_tick;
    }
    const double seconds=ticks/((u.kind==HOUND_KIND&&u.action==HABARU_DOUBLE_EDGE?22:30)*u.attack_slow_factor)-delta;
    if(seconds>0&&seconds<=.55&&melee_contact(crowd,u))warn_hero(crowd,u.logical_id,u.position,seconds);
}
void Combat::warn_projectile(Crowd& crowd,const Projectile& shot){
    if(shot.source_team!=0||hero_row_<0||shot.speed<=0||shot.life<=shot.age)return;
    const auto& hero=targets_[hero_row_];
    const float horizon=float(std::min(.55,shot.life-shot.age));
    const Vec3 end=shot.position+shot.direction*(shot.speed*horizon);
    auto contacts=[&](float fraction){
        Vec3 tip=shot.position+(end-shot.position)*fraction;
        return hero.body_bounds()?box_segment(shot.position,tip,hero.minimum,hero.maximum,shot.radius)>=0:body_contact(shot.position,tip,hero.foot,shot.radius);
    };
    if(!contacts(1))return;
    float low=0,high=1;
    for(int i=0;i<12;++i){float mid=(low+high)*.5f;if(contacts(mid))high=mid;else low=mid;}
    if(!crowd.terrain.ray_clear(shot.position,shot.position+(end-shot.position)*high,shot.ignore_building))return;
    warn_hero(crowd,shot.source_id,shot.position,high*horizon);
}
void Combat::after_move(Crowd& crowd,double delta){
    hero_dodge_threat_={};
    if(!enabled_)return;
    pulses(crowd,delta);
    for(auto& u:crowd.units_)if(u.alive&&(u.team==0||escort_kind(u.kind))&&u.action_active){
        if(u.action==GUARDIAN_ARRIVAL)continue;
        if(u.team==0&&enemy_charge_action(u.action)){advance_enemy_charge(crowd,u,u.live_delta);continue;}
        if(u.action==ENEMY_GUARD_BREAK_WINDUP){
            if(u.stun<=0){
                u.action_time+=u.live_delta*u.attack_slow_factor;
                if(u.action_time+1e-8>=ENEMY_GUARD_BREAK_TIME)begin(u);
            }
            continue;
        }
        const double attack_delta=u.live_delta*(u.team==1&&u.kind==HOUND_KIND?u.pet_attack_multiplier:1);
        if(u.pet_skill==PET_BEE_FLURRY){advance_pet_flurry(crowd,u,attack_delta);continue;}
        warn_melee(crowd,u,delta);
        if(u.counter_active){advance_counter(crowd,u,attack_delta);continue;}
        if(u.action==UNDERSEA_MEDITATION||u.action==UNDERSEA_HAZE){undersea_support(u,u.live_delta);continue;}
        if(u.action==UNDERSEA_QIGONG){undersea_qigong(crowd,u,delta);continue;}
        if(u.action==ZOMBIE_CHARGE){zombie_explode(crowd,u,delta);continue;}
        if(u.action==GUARDIAN_CAST){if(u.live_delta>0&&u.stun<=0)guardian_spell(crowd,u,u.live_delta);continue;}
        if(ruby_spell_action(u.action)){if(u.live_delta>0&&u.stun<=0)ruby_spell(crowd,u,u.live_delta);continue;}
        if(u.action==GRAVE_EARTH_WARNING){
            u.action_time+=delta;
            if(u.action_time>=1.2){
                zombie_cue(u,GRAVE_EARTH_IMPACT,8.0);
                boss_area(crowd,u,u.position,8.0f/data_.enemy_size,23.0,float(M_PI),false,true);
                u.action_active=false;u.action=data_.actions[0];u.action_time=0;
            }
            continue;
        }
        if(u.live_delta<=0||u.stun>0)continue;
        if(u.team==1&&escort_kind(u.kind)&&u.pet_rush_left>0&&u.has_goal&&!u.counter_active&&!pet_ranged_skill(u.pet_skill)){
            const auto* timeline=pet_timeline(u);double first_contact=timeline[0];
            for(int i=0;i<int(timeline[1]);++i){int cue=int(timeline[3+i*2]);
                if(u.kind==HOUND_KIND?companion_contact_cue(cue):(cue>=10000?companion_contact_cue(cue):(cue==135||cue==138||cue==164||cue==165))){first_contact=timeline[2+i*2];break;}}
            if(u.phase_tick<first_contact&&!melee_contact(crowd,u))continue;
        }
        if(u.kind==4&&!data_.skullpion.empty())boss_advance(crowd,u);
        else if(u.kind==17&&!data_.dark_lumina.empty())lumina_advance(crowd,u,u.live_delta*u.attack_slow_factor);
        else if(u.kind==18&&!data_.finale_meta.empty())finale_advance(crowd,u,u.live_delta*u.attack_slow_factor);
        else advance(crowd,u,attack_delta*u.attack_slow_factor);
        if(guardian(u)&&u.guardian_tech==50&&!u.action_active)begin(u);
        if(habaru_boss(u)&&u.habaru_phase==2&&!u.action_active){
            u.habaru_phase=3;u.habaru_left=1.2;u.habaru_pressure=u.habaru_gap=0;
        }
    }
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
const float* Combat::pet_geometry(const Unit& u) const{
    if(data_.pet_geometry.empty()||u.pose_row<0||u.pose_row>=pet_skin_count(u.kind))return nullptr;
    const auto* source=data_.pet_geometry.data()+7*(u.pose_row+(u.kind==SLIME_KIND?HOUND_SKINS:u.kind==BEAR_KIND?HOUND_SKINS+SLIME_SKINS:0));
    if(u.body_scale==1)return source;
    for(int i=0;i<7;++i)u.scaled_geometry[i]=source[i]*u.body_scale;
    return u.scaled_geometry.data();
}
void Combat::include_body_bounds(const Unit& u){
    if(const auto* p=pet_geometry(u)){
        const float radius=std::hypot(std::max(std::abs(p[0]),std::abs(p[3])),std::max(std::abs(p[2]),std::abs(p[5])));
        pet_query_padding_.x=pet_query_padding_.z=std::max(pet_query_padding_.x,radius);
        pet_query_padding_.y=std::max(pet_query_padding_.y,std::max(std::abs(p[1]),std::abs(p[4])));
    }
}
void Combat::enemy_bounds(const Unit& u,Vec3& low,Vec3& high) const{
    if(const auto* p=pet_geometry(u)){low={p[0],p[1],p[2]};high={p[3],p[4],p[5]};return;}
    const auto& k=soldiers_[u.kind].kit;low={k[19],k[20],k[21]};high={k[22],k[23],k[24]};
}
Vec3 Combat::enemy_contact(const Unit& victim,Vec3 from) const{
    Vec3 local=rotated_y(from-victim.position,-victim.yaw);
    if(victim.kind>=0&&victim.kind<ENEMY_KIND_COUNT&&soldiers_[victim.kind].active){
        Vec3 low,high;enemy_bounds(victim,low,high);
        local.x=std::clamp(local.x,low.x,high.x);local.y=std::clamp(local.y,low.y,high.y);local.z=std::clamp(local.z,low.z,high.z);
        return victim.position+rotated_y(local,victim.yaw);
    }
    float x=victim.kind==4?15*data_.map_enemy_scale:.576f*data_.enemy_size,y=victim.kind==4?25*data_.map_enemy_scale:2.016f*data_.enemy_size,z=victim.kind==4?20*data_.map_enemy_scale:1.152f*data_.enemy_size;
    local.x=std::clamp(local.x,-x,x);local.y=std::clamp(local.y,0.0f,y);local.z=std::clamp(local.z,-z,z);
    return victim.position+rotated_y(local,victim.yaw);
}
bool Combat::pet_landing_clear(Crowd& crowd,const Unit& u,Vec3 point) const{
    // Reuse the tick's pet list; a teleport invalidates the army query grid.
    for(auto slot:hound_approach_units_){
        const auto& other=crowd.units_[slot];
        if(!other.alive||other.handle==u.handle||std::abs(other.position.y-point.y)>=3)continue;
        if(horizontal(other.position,point)<.98f*(u.radius+other.radius))return false;
    }
    return true;
}
bool Combat::pet_contact_goal(Crowd& crowd,const Unit& u,const Unit& enemy,Vec3& goal){
    auto& ground=crowd.allied_terrain;int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    if(layer<0)return false;
    Vec3 away=u.position-enemy.position;away.y=0;away=normalized(away);
    if(length(away)<.001f)away={0,0,1};
    Unit probe;probe.team=u.team;probe.kind=u.kind;probe.pose_row=u.pose_row;probe.target_handle=enemy.handle;
    for(float angle:{0.f,1.0471976f,-1.0471976f,2.0943952f,-2.0943952f}){
        Vec3 side=rotated_y(away,angle);
        Vec3 contact=enemy_contact(enemy,enemy.position+side*100+Vec3{0,1,0});
        for(float stand:{u.radius+.15f,u.radius*.7f}){
            Vec3 point=contact+side*stand;point.y=float(ground.height(point.x,point.z,layer));
            if(!finite(point)||std::abs(point.y-enemy.position.y)>=5||!ground.clear(point,u.radius,layer))continue;
            Vec3 toward=enemy.position-point;probe.position=point;probe.yaw=std::atan2(-toward.x,-toward.z);
            if(melee_contact(crowd,probe)&&ground.reachable(u.position,point,u.radius,layer)){goal=point;return true;}
        }
    }
    return false;
}
bool Combat::pet_surround_goal(Crowd& crowd,Unit& u,const Unit& enemy,Vec3& goal){
    auto& approach=hound_approaches_[uint32_t(u.handle)];
    if(approach.count<2||approach.target!=enemy.handle)return false;
    auto& ground=crowd.allied_terrain;int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
    if(layer<0)return false;
    float stand=(u.radius+.35f)/std::sin(float(M_PI/approach.count));
    Vec3 waiting;bool has_waiting=false;
    Unit probe;probe.team=u.team;probe.kind=u.kind;probe.pose_row=u.pose_row;probe.target_handle=enemy.handle;
    auto first=std::lower_bound(hound_approach_units_.begin(),hound_approach_units_.end(),enemy.handle,[&](uint32_t slot,int64_t target){return hound_approaches_[slot].target<target;});
    for(int attempt=0;attempt<12;++attempt){
        int offset=(attempt+1)/2*(attempt%2?1:-1);
        float angle=approach.angle+offset*float(M_PI/6);
        Vec3 side{std::sin(angle),0,std::cos(angle)};
        Vec3 contact=enemy_contact(enemy,enemy.position+side*100+Vec3{0,1,0});
        for(float fit:{1.f,1.4f,.8f,.6f,0.f,2.f,3.f}){
            Vec3 point=contact+side*std::max(u.radius*.7f,stand*fit);
            point.y=float(ground.height(point.x,point.z,layer));
            if(!finite(point)||std::abs(point.y-enemy.position.y)>=5||!ground.clear(point,u.radius+.1f,layer))continue;
            bool occupied=false;
            for(auto it=first;it!=hound_approach_units_.end()&&hound_approaches_[*it].target==enemy.handle;++it){
                const auto& other=crowd.units_[*it];const auto& reserved=hound_approaches_[*it];
                if(other.handle==u.handle||other.target_handle!=enemy.handle||(!other.action_active&&!reserved.ready))continue;
                Vec3 anchor=other.action_active?other.position:reserved.goal;
                if(std::abs(anchor.y-point.y)<3&&horizontal(anchor,point)<u.radius+other.radius+.2f){occupied=true;break;}
            }
            if(occupied)continue;
            Vec3 toward=enemy.position-point;probe.position=point;probe.yaw=std::atan2(-toward.x,-toward.z);
            bool contact=melee_contact(crowd,probe);
            if((!contact&&has_waiting)||!ground.reachable(u.position,point,u.radius,layer))continue;
            if(!contact){waiting=point;has_waiting=true;continue;}
            approach.goal=goal=point;approach.anchor=enemy.position;approach.ready=true;return true;
        }
    }
    if(pet_landing_clear(crowd,u,u.position)&&ground.clear(u.position,u.radius,layer)&&
       (!has_waiting||horizontal(u.position,enemy.position)<horizontal(waiting,enemy.position))){waiting=u.position;has_waiting=true;}
    if(has_waiting){approach.goal=goal=waiting;approach.anchor=enemy.position;approach.ready=true;return true;}
    approach.ready=false;return false;
}
int64_t Combat::guard_enemy(Crowd& crowd,Unit& u,float escort_radius,const std::vector<int64_t>* skipped){
    bool escort=escort_kind(u.kind)&&hound_hero_row_>=0;
    const bool holding=escort&&u.hound_order==HOUND_HOLD;
    const int ranged_slots=escort?pet_ranged_slots(u):0;
    Vec3 center=escort?u.position:u.guard_post;
    if(!escort)for(auto row:target_groups_[2])if(targets_[row].assault_priority==2){center=targets_[row].foot;break;}
    int layer=u.support_layer<0?crowd.allied_terrain.choose_layer(u.position):u.support_layer;
    if(layer<0)layer=0;
    Vec3 from=u.position;from.y=float(crowd.allied_terrain.height(from.x,from.z,layer));
    auto inside=[&](const Unit& other){
        return escort?horizontal(other.position,center)<=escort_radius&&std::abs(other.position.y-center.y)<5:
            std::max(std::abs(other.position.x-center.x),std::abs(other.position.z-center.z))<=u.guard_radius;
    };
    auto eligible=[&](const Unit& other){
        if(other.hp<=0||!inside(other))return false;
        if((ranged_slots&&pet_ranged_contact(crowd,u,other))||crowd.allied_terrain.reachable(from,other.position,u.radius,layer))return true;
        Vec3 goal;return escort&&pet_contact_goal(crowd,u,other,goal);
    };
    if(escort&&hound_order_==HOUND_ATTACK&&hound_focus_target_){
        auto foe=crowd.unit(hound_focus_target_);
        return foe&&foe->team==0&&foe->shelter_mode!=2&&eligible(*foe)?foe->handle:0;
    }
    if(!escort)if(auto other=crowd.unit(nearest_enemy(crowd,u.position));other&&eligible(*other))return other->handle;
    float radius=escort?escort_radius:u.guard_radius;
    Vec3 pad{radius,3e8f,radius};
    target_candidates_.clear();
    for(auto handle:crowd.query(center-pad,center+pad,0,false)){
        auto other=crowd.unit(handle);if(!other||other->hp<=0||other->shelter_mode==2||!inside(*other)||(skipped&&std::find(skipped->begin(),skipped->end(),handle)!=skipped->end()))continue;
        if(holding){
            Unit probe;probe.team=u.team;probe.kind=u.kind;probe.pose_row=u.pose_row;probe.position=u.position;probe.target_handle=handle;
            Vec3 toward=other->position-u.position;probe.yaw=std::atan2(-toward.x,-toward.z);
            if(!melee_contact(crowd,probe)&&!(ranged_slots&&pet_ranged_contact(crowd,u,*other)))continue;
        }
        Vec3 point=enemy_contact(*other,u.position+Vec3{0,1,0});
        bool threat=escort&&!other->target_handle&&other->external_kind==0&&other->external_target==targets_[hound_hero_row_].id;
        float distance=length(point-u.position);
        if(escort){
            int claimed=int(std::count(hound_claims_.begin(),hound_claims_.end(),handle))-(u.target_handle==handle?1:0);
            distance+=5.f*std::max(0,claimed)+float(random(u))*.75f;
        }
        target_candidates_.push_back({-1,handle,distance,threat?1:0});
    }
    std::sort(target_candidates_.begin(),target_candidates_.end(),[&](const TargetCandidate& a,const TargetCandidate& b){return a.priority!=b.priority?a.priority>b.priority:a.distance!=b.distance?a.distance<b.distance:crowd.unit(a.handle)->logical_id<crowd.unit(b.handle)->logical_id;});
    for(auto candidate:target_candidates_){
        auto other=crowd.unit(candidate.handle);
        if(crowd.allied_terrain.reachable(from,other->position,u.radius,layer)||(ranged_slots&&pet_ranged_contact(crowd,u,*other))){
            if(escort&&candidate.handle!=u.target_handle){
                auto old=std::find(hound_claims_.begin(),hound_claims_.end(),u.target_handle);
                if(old!=hound_claims_.end())hound_claims_.erase(old);
                hound_claims_.push_back(candidate.handle);
            }
            return candidate.handle;
        }
    }
    return 0;
}
void Combat::hound_guard(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    const auto order=hound_order_;
    const bool commanded_attack=order==HOUND_ATTACK;
    const bool commanded_hold=order==HOUND_HOLD;
    const bool new_order=u.hound_order!=order||u.hound_order_serial!=hound_order_serial_;
    const bool commanded_return=order==HOUND_RETURN&&(new_order||u.hound_return_left>=0);
    const bool release_focus=commanded_attack&&!hound_focus_target_&&u.hound_focused;
    // Let a committed strike or sequence finish before releasing its focused target.
    if(new_order&&!(release_focus&&(u.action_active||u.pet_skill==2||u.pet_skill==PET_BEE_FLURRY))){
        u.bodyguard_followup=false;
        if((commanded_return||commanded_hold)&&u.pet_skill==PET_BEE_FLURRY)finish_pet_flurry(crowd,u);
        u.hound_order_serial=hound_order_serial_;
        u.hound_order=order;
        u.hound_focused=hound_focus_target_!=0;
        if(commanded_return||commanded_hold){u.pet_skill=0;u.pet_combo_left=0;u.action_hits.clear();}
        if(commanded_return){
            if(u.target_handle)u.approach_ready=false;
            u.target_handle=0;u.action_active=false;u.has_goal=false;
            u.hound_strolling=false;u.hound_return_left=0;
        }else if(commanded_hold){
            u.target_handle=0;u.action_active=false;u.has_goal=false;u.approach_ready=false;
            u.hound_strolling=false;u.hound_return_left=-1;u.think_left=0;u.guard_post=u.position;
        }else if(commanded_attack){
            if(release_focus){
                auto claim=std::find(hound_claims_.begin(),hound_claims_.end(),u.target_handle);
                if(claim!=hound_claims_.end())hound_claims_.erase(claim);
                u.target_handle=0;u.has_goal=false;u.approach_ready=false;
            }
            u.hound_return_left=-1;u.think_left=0;
        }
    }
    if(hound_hero_row_<0||u.guard_radius<=0){
        if(u.pet_skill==PET_BEE_FLURRY)finish_pet_flurry(crowd,u);
        u.action_active=false;u.target_handle=0;u.has_goal=false;
        u.hound_return_left=-1;u.action=data_.actions[0];return;
    }
    if(u.stun>0){
        if(u.pet_skill==PET_BEE_FLURRY)finish_pet_flurry(crowd,u);
        u.action_active=false;u.has_goal=false;u.action=data_.actions[6];return;
    }
    if(u.pet_skill==PET_BEE_FLURRY){u.has_goal=false;return;}
    if(u.kind==HOUND_KIND&&u.pet_skill==2&&!commanded_return&&!commanded_hold){
        Unit corpse;auto foe=pet_sequence_target(crowd,u,corpse);
        if(!u.action_active||!foe||foe->hp<=0){
            u.action_active=false;
            if(foe==&corpse&&u.pet_combo_left>0){pet_begin(crowd,u);return;}
            Handle next=u.pet_combo_left>0?guard_enemy(crowd,u,32,&u.action_hits):0;
            if(!next&&u.pet_combo_left>0)next=guard_enemy(crowd,u,32);
            if(next){u.target_handle=next;pet_begin(crowd,u);return;}
            u.pet_skill=0;u.pet_combo_left=0;u.action_hits.clear();
        }
        if(u.pet_skill==2&&foe){u.has_goal=false;return;}
    }
    const auto& profile=soldiers_[u.kind];
    auto face=[&](Vec3 direction){
        float desired=std::atan2(-direction.x,-direction.z);
        float turn=std::remainder(desired-u.yaw,float(2*M_PI)),step=float(dt*profile.turn_speed);
        u.yaw+=std::clamp(turn,-step,step);
        return std::abs(turn)<.35f;
    };
    if(u.bodyguard_followup){
        const auto* enemy=crowd.unit(u.target_handle);Vec3 goal;
        if(!enemy||enemy->hp<=0||!pet_contact_goal(crowd,u,*enemy,goal))u.bodyguard_followup=false;
        else if(melee_contact(crowd,u)){
            u.has_goal=false;
            if(face(enemy->position-u.position)){u.pet_skill=0;begin(u);u.bodyguard_followup=false;}
            return;
        }else{face(enemy->position-u.position);crowd.set_goal(u.handle,goal,32);return;}
    }
    if(commanded_hold){
        u.has_goal=false;
        auto enemy=crowd.unit(u.target_handle);
        if(!enemy||enemy->hp<=0||enemy->shelter_mode==2){u.target_handle=0;u.action_active=false;}
        if(u.action_active)return;
        u.action=data_.actions[0];u.think_left-=dt;
        if(u.think_left<=0){u.think_left=.22+.12*random(u);u.target_handle=guard_enemy(crowd,u,u.guard_radius);}
        enemy=crowd.unit(u.target_handle);
        if(enemy&&face(enemy->position-u.position)){
            const int slots=pet_ranged_slots(u);
            pet_begin(crowd,u,slots&&pet_ranged_contact(crowd,u,*enemy)?slots:0);
        }
        return;
    }
    const Vec3 center=targets_[hound_hero_row_].foot;
    const float player_gap=horizontal(u.position,center);
    const bool player_moving=hound_player_speed_>.5;
    const bool running=hound_player_speed_>profile.speed;
    const auto& hero=targets_[hound_hero_row_];
    auto slot=std::find(hero.pet_formation_ids.begin(),hero.pet_formation_ids.end(),u.logical_id);
    const int index=int(slot-hero.pet_formation_ids.begin());
    Vec3 forward=hero.pet_formation_facing;forward.y=0;
    const bool assigned=(order==HOUND_RETURN||order==HOUND_DEFEND)&&slot!=hero.pet_formation_ids.end()&&index<5&&finite(forward)&&horizontal(forward,{})>.01f;
    // Party slots follow the approved preview: front sides, rear centre, then rear sides.
    Vec3 offset{};
    if(assigned){forward=normalized(forward);offset=Vec3{-forward.z,0,forward.x}*PARTY_FORMATION_POSTS[index].x+forward*PARTY_FORMATION_POSTS[index].z;}
    const Vec3 formation=center+(running?hound_escort_lead_:Vec3{})+offset;
    if(u.age==0){u.approach_ready=!assigned;u.target_goal=formation;u.hound_roam_left=4+8*random(u);}
    u.age+=dt;
    auto enemy=crowd.unit(u.target_handle);
    const int ready_ranged=pet_ranged_slots(u);
    const auto& previous_approach=hound_approaches_[uint32_t(u.handle)];
    Vec3 reachable_goal=enemy&&previous_approach.target==enemy->handle&&previous_approach.ready?previous_approach.goal:enemy?enemy->position:u.position;
    Vec3 contact_goal;
    Handle contact_goal_target=0;
    if(enemy&&!u.action_active&&u.think_left<=dt&&horizontal(u.velocity,{})<.25f&&
       !melee_contact(crowd,u)&&!(ready_ranged&&pet_ranged_contact(crowd,u,*enemy))&&!crowd.allied_terrain.reachable(u.position,reachable_goal,u.radius,u.support_layer)){
        if(pet_contact_goal(crowd,u,*enemy,contact_goal))contact_goal_target=enemy->handle;
        else enemy=nullptr;
    }
    if(!enemy||enemy->hp<=0||enemy->shelter_mode==2||(!commanded_attack&&horizontal(enemy->position,u.position)>u.guard_radius)){
        if(u.target_handle){
            u.target_handle=0;u.action_active=false;u.think_left=0;u.approach_ready=false;u.has_goal=false;
            u.hound_return_left=commanded_attack?-1:.15+.35*random(u);
        }
        enemy=nullptr;
    }
    if(u.action_active&&commanded_attack&&hound_focus_target_&&u.target_handle!=hound_focus_target_){
        u.think_left=0;
        u.has_goal=false;
        return;
    }
    u.think_left-=dt;
    // Recheck nearby enemies after a kill and while regrouping.
    bool refresh=u.think_left<=0;
    if(refresh){
        u.think_left=(running?.14:.22)+.12*random(u);
        if(commanded_attack&&hound_focus_target_&&!u.action_active){
            if(!enemy||enemy->handle!=hound_focus_target_){u.target_handle=guard_enemy(crowd,u,120);enemy=crowd.unit(u.target_handle);u.routing=false;}
            u.hound_return_left=-1;
        }else if(!enemy&&u.hound_return_left<0&&commanded_attack){
            if(hound_searches_left_>0){
                --hound_searches_left_;
                u.think_left=.65+.25*random(u);
                auto& ground=crowd.allied_terrain;
                int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
                // shortcut: try four routes per search, widen the shortlist if a map's cover strands the pack.
                std::array<int64_t,4> skipped{};
                for(auto& rejected:skipped){
                    auto foe=crowd.unit(nearest_enemy(crowd,u.position,&skipped));
                    if(!foe)break;
                    double height=ground.height(foe->position.x,foe->position.z,layer);
                    const bool direct=(ready_ranged&&pet_ranged_contact(crowd,u,*foe))||(layer>=0&&std::abs(height-foe->position.y)<5&&ground.reachable(u.position,foe->position,u.radius,layer));
                    if(direct||pet_contact_goal(crowd,u,*foe,contact_goal)){
                        if(!direct)contact_goal_target=foe->handle;
                        u.target_handle=foe->handle;enemy=foe;hound_claims_.push_back(foe->handle);break;
                    }
                    rejected=foe->handle;
                }
            }else u.think_left=0;
        }else if(!commanded_attack&&!commanded_return&&!u.action_active){
            auto threatens_player=[&](const Unit& foe){return !foe.target_handle&&foe.external_kind==0&&foe.external_target==targets_[hound_hero_row_].id;};
            if(!enemy||!threatens_player(*enemy)){
                auto candidate=crowd.unit(guard_enemy(crowd,u,u.guard_radius));
                if(candidate&&(!enemy||threatens_player(*candidate))){u.target_handle=candidate->handle;enemy=candidate;u.hound_return_left=-1;}
            }
        }
    }
    const bool returning=u.hound_return_left>=0;
    if(returning&&u.hound_return_left>0){
        u.hound_return_left=std::max(0.,u.hound_return_left-dt);
        if(u.hound_return_left==0)u.think_left=0;
        u.action=data_.actions[0];return;
    }
    if(enemy){
        u.approach_ready=false;u.hound_strolling=false;
        if(u.action_active){
            if(!pet_ranged_skill(u.pet_skill)&&!melee_contact(crowd,u)){
                Vec3 toward=enemy->position-u.position;toward.y=0;face(toward);
                Vec3 goal=enemy->position-normalized(toward)*(enemy->radius+u.radius*.7f);
                float speed=u.pet_rush_left>0?32.f:(profile.speed+std::min(profile.speed,8.f))*(u.kind==BEAR_KIND?1.f:data_.hound_move_scale);
                u.pet_rush_left=std::max(0.0,u.pet_rush_left-dt);
                crowd.set_goal(u.handle,goal,speed);
            }else u.has_goal=false;
            return;
        }
        u.action=data_.actions[0];
        Vec3 toward=enemy->position-u.position;toward.y=0;
        const int ranged=ready_ranged&&pet_ranged_contact(crowd,u,*enemy)?ready_ranged:0;
        Vec3 goal=enemy->position-normalized(toward)*(enemy->radius+u.radius*.7f);
        if(commanded_attack){
            Vec3 contact=enemy_contact(*enemy,u.position+Vec3{0,1,0});contact.y=u.position.y;
            goal=contact-normalized(contact-u.position)*(u.radius*.7f);
        }
        auto& approach=hound_approaches_[uint32_t(u.handle)];bool surrounding=false;
        if(approach.count>1&&approach.target==enemy->handle){
            if(!approach.ready||refresh||horizontal(approach.anchor,enemy->position)>.5f)surrounding=pet_surround_goal(crowd,u,*enemy,goal);
            else {goal=approach.goal;surrounding=true;}
        }
        if(!surrounding&&contact_goal_target==enemy->handle)goal=contact_goal;
        else if(!surrounding&&commanded_attack){
            auto& ground=crowd.allied_terrain;
            const int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
            if(layer>=0&&!ground.clear(goal,u.radius,layer))pet_contact_goal(crowd,u,*enemy,goal);
        }
        bool planted=!surrounding||horizontal(u.position,goal)<.25f;
        if(planted||ranged||pet_flurry_ready(crowd,u)){
            if(face(toward)&&pet_begin(crowd,u,ranged,planted))return;
        }else face(goal-u.position);
        if(ranged){u.has_goal=false;return;}
        const float gap=horizontal(u.position,goal);
        const float rush=std::min(profile.speed*.65f,6.f)*std::clamp((gap-1.25f)*.5f,0.f,1.f)*std::clamp((12.f-gap)*.4f,0.f,1.f);
        float speed=profile.speed+rush;
        if(gap>1.f&&gap<=5.f)speed=std::max(speed,32.f/(u.kind==BEAR_KIND?1.f:data_.hound_move_scale));
        if(commanded_attack)speed+=std::clamp((gap-8)*.8f,0.f,17.5f);
        if(u.hound_focused){
            const float body_gap=horizontal(u.position,enemy->position)-enemy->radius-u.radius;
            speed=std::max(speed,profile.speed+std::clamp((std::min(gap,body_gap)-1.f)*3.f,0.f,10.f));
        }
        crowd.set_goal(u.handle,goal,speed*(u.kind==BEAR_KIND?1.f:data_.hound_move_scale));
        return;
    }

    u.action=data_.actions[0];
    if(player_moving)u.hound_strolling=false;
    else if(!u.has_goal)u.hound_roam_left-=dt;
    bool moved=horizontal(u.target_goal,formation)>(player_moving?.8f:2.f);
    bool patrol=!assigned&&u.approach_ready&&!u.has_goal&&!moved&&!player_moving&&u.hound_roam_left<=0;
    bool stalled=u.has_goal&&horizontal(u.velocity,{})<.25f&&horizontal(u.position,u.guard_post)>2;
    const bool sprint_escort=running&&!commanded_attack;
    const float inner_post_radius=u.kind==BEAR_KIND?8.f:4.f;
    const float post_radius=(u.kind==BEAR_KIND||returning||sprint_escort)?16.f:14.f;
    bool outside=(player_gap>u.guard_radius&&horizontal(u.guard_post,center)>post_radius)||(u.kind==BEAR_KIND&&player_gap<inner_post_radius);
    auto escort_neighbors=[&]() -> const std::vector<int64_t>& {
        float radius=u.guard_radius+(commanded_return?5:3);
        if(hound_escort_query_radius_<radius){
            Vec3 pad{radius,8,radius};
            hound_escort_neighbors_=crowd.query(center-pad,center+pad,1,false);
            hound_escort_query_radius_=radius;
        }
        return hound_escort_neighbors_;
    };
    Vec3 away{};
    if(commanded_return&&refresh&&player_gap<=u.guard_radius&&horizontal(u.velocity,{})<.6f){
        for(auto handle:escort_neighbors())if(auto other=crowd.unit(handle);
            other&&escort_kind(other->kind)&&other->logical_id<u.logical_id&&horizontal(other->velocity,{})<.6f&&std::abs(other->position.y-u.position.y)<2&&
            horizontal(other->position,u.position)<3.2f){
            away=u.position-other->position;
            if(horizontal(away,{})<.001f)away.x=1;
            break;
        }
    }
    const bool crowded=horizontal(away,{})>0;
    if(refresh&&(!u.approach_ready||moved||patrol||stalled||outside||crowded)){
        const bool translate=u.approach_ready&&!patrol&&!stalled&&!crowded;
        const bool keep_side=sprint_escort&&u.approach_ready&&!crowded;
        const Vec3 preferred=assigned?formation:formation+(u.guard_post-u.target_goal);
        if(!patrol)u.approach_ready=false;
        u.hound_roam_left=4+8*random(u);
        auto& ground=crowd.allied_terrain;
        int layer=u.support_layer<0?ground.choose_layer(u.position):u.support_layer;
        const auto& nearby=escort_neighbors();
        Vec3 detour{NAN,0,0};
        for(int attempt=0;attempt<((returning||crowded)?20:12);++attempt){
            float angle=float(random(u)*2*M_PI);
            float distance=float(patrol?2+3*random(u):u.kind==BEAR_KIND?9+7*random(u):attempt>=12?12+4*random(u):4.5+9*random(u));
            Vec3 start=patrol?u.position:formation;
            if(crowded&&attempt<8){
                start=u.position;distance=4;
                angle=std::atan2(away.x,away.z)+attempt*float(M_PI/4);
            }else if(keep_side&&attempt<8){
                start=preferred;
                distance=attempt<4?2.5f:5.f;
            }
            Vec3 goal=attempt==0&&(translate||assigned)?preferred:start+Vec3{std::sin(angle)*distance,0,std::cos(angle)*distance};
            float from_player=horizontal(goal,center);
            if(from_player<inner_post_radius||from_player>post_radius)continue;
            goal.y=float(ground.height(goal.x,goal.z,layer));
            if(!finite(goal)||std::abs(goal.y-center.y)>4)continue;
            bool occupied=false;
            for(auto handle:nearby)if(auto other=crowd.unit(handle);other&&other!=&u){
                // Fixed party posts are distinct; do not reject one because another pet is still crossing it.
                if(assigned&&std::find(hero.pet_formation_ids.begin(),hero.pet_formation_ids.end(),other->logical_id)!=hero.pet_formation_ids.end())continue;
                Vec3 anchor=escort_kind(other->kind)&&other->approach_ready?(assigned?other->guard_post:other->guard_post+(formation-other->target_goal)):other->position;
                float spacing=other->radius+u.radius+.3f;
                if((returning||sprint_escort)&&escort_kind(other->kind))spacing=std::max(spacing,3.7f);
                if(horizontal(anchor,goal)<spacing||(returning&&horizontal(other->position,goal)<spacing)){occupied=true;break;}
            }
            // Returning pets can reserve a post before entering the player's local query.
            if(returning&&!assigned&&!occupied)for(auto slot:hound_approach_units_){
                const auto& other=crowd.units_[slot];
                if(!other.alive||&other==&u||!other.approach_ready||other.hound_return_left<0)continue;
                Vec3 anchor=other.guard_post+(formation-other.target_goal);
                if(std::abs(anchor.y-goal.y)<3&&horizontal(anchor,goal)<std::max(other.radius+u.radius+.3f,3.7f)){occupied=true;break;}
            }
            if(occupied)continue;
            if(!ground.segment(u.position,goal,u.radius,layer)){
                if(!patrol&&!finite(detour)&&ground.reachable(u.position,goal,u.radius,layer)){
                    detour=goal;
                    if(assigned&&attempt==0)break;
                }
                continue;
            }
            u.guard_post=goal;u.target_goal=formation;u.approach_ready=true;u.hound_strolling=patrol&&!crowded;u.routing=false;break;
        }
        if(!u.approach_ready&&finite(detour)){
            u.guard_post=detour;u.target_goal=formation;u.approach_ready=true;u.hound_strolling=false;u.routing=true;
        }
        if(player_gap>u.guard_radius&&(!u.approach_ready||(stalled&&u.routing))){
            // A dog with no usable route to its post can take a short clear step out of cover.
            Vec3 toward=center-u.position;
            float heading=std::atan2(toward.x,toward.z);
            for(float offset:{0.f,.55f,-.55f,1.1f,-1.1f,1.55f,-1.55f}){
                float angle=heading+offset;
                Vec3 goal=u.position+Vec3{std::sin(angle)*5,0,std::cos(angle)*5};
                goal.y=float(ground.height(goal.x,goal.z,layer));
                if(!finite(goal)||!ground.segment(u.position,goal,u.radius,layer))continue;
                u.guard_post=goal;u.target_goal=formation;u.approach_ready=true;u.hound_strolling=false;u.routing=false;break;
            }
        }
    }
    float gap=horizontal(u.position,u.guard_post);
    if(u.approach_ready&&gap>(u.has_goal?.55f:1.f)){
        face(u.guard_post-u.position);
        float catch_up=std::clamp((player_gap-10)*.75f,0.f,12.f);
        float pace=u.hound_strolling?1.3f:std::max(profile.speed,float(hound_player_speed_)+std::min(3.f,gap*.5f))+catch_up;
        if(returning)
            pace=std::max(pace,9.f+std::clamp((player_gap-16)*1.25f,0.f,25.f));
        crowd.set_goal(u.handle,u.guard_post,std::min(pace*(u.kind==BEAR_KIND?1.f:data_.hound_move_scale),gap*(returning?2.6f:1.5f)+float(hound_player_speed_)));
    }else{
        u.has_goal=false;
        if(u.approach_ready)u.hound_return_left=-1;
        Vec3 outward=u.position-center;
        if(horizontal(u.position,center)>.5f)face(outward);
    }
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
bool Combat::ally_segment(const Unit& victim,Vec3 from,Vec3 to,float radius) const{
    return pet_geometry(victim)?enemy_segment(victim,from,to,radius)>=0:body_contact(from,to,victim.position,radius);
}
float Combat::enemy_segment(const Unit& victim,Vec3 from,Vec3 to,float radius) const{
    Vec3 a=rotated_y(from-victim.position,-victim.yaw),b=rotated_y(to-victim.position,-victim.yaw);
    Vec3 low{-.576f*data_.enemy_size,0,-1.152f*data_.enemy_size},high{.576f*data_.enemy_size,2.016f*data_.enemy_size,1.152f*data_.enemy_size};
    if(victim.kind==4){low=Vec3{-15,0,-20}*data_.map_enemy_scale;high=Vec3{15,25,20}*data_.map_enemy_scale;}
    else if(victim.kind>=0&&victim.kind<ENEMY_KIND_COUNT&&soldiers_[victim.kind].active){
        enemy_bounds(victim,low,high);
    }
    return box_segment(a,b,low,high,radius);
}
void Combat::ninja_begin(Unit& u,Vec3 aim){
    u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);u.dash_direction={std::sin(u.yaw),0,std::cos(u.yaw)};u.dash_previous=u.position;
    u.special_time=0;u.action_time=0;u.action=data_.actions[9];u.action_active=true;u.primary_hit=false;u.cast_confirmed=false;u.motion_impulse={};u.action_hits.clear();
    u.skill_left=data_.ninja[6];u.invuln=std::max(u.invuln,data_.ninja[0]);u.attack_damage=data_.ninja[2]*allies_[5].damage*std::min(1.5,1.0+.05*u.chain_count);
}
bool Combat::move_special(Crowd& crowd,Unit& u,double dt,Vec3& next){
    if(u.bodyguard_left>0){next=u.position;return true;}
    if(u.team==0&&u.action_active&&enemy_charge_action(u.action)){
        if(u.action==ENEMY_CHARGE_RUSH&&u.stun<=0){
            u.dash_previous=u.position;
            const auto step=u.dash_direction*float(ENEMY_CHARGE_SPEED*u.slow_factor*std::min(dt,ENEMY_CHARGE_RUSH_TIME-u.action_time));
            if(u.guard_radius<=0||horizontal(u.position+step,u.guard_post)<=2*u.guard_radius)
                next=crowd.terrain.direct_move(u.position,step,u.radius,u.support_layer);
        }
        return true;
    }
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
    if(enabled_&&u.team==0&&u.kind>=0&&u.kind<ENEMY_KIND_COUNT&&soldiers_[u.kind].active&&u.action_active&&u.stun<=0){
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
    for(auto handle:crowd.query(low-pad-pet_query_padding_,high+pad+pet_query_padding_,1)){
        auto victim=crowd.unit(handle);if(!victim)continue;
        Vec3 point=victim->position+Vec3{0,1,0};
        if(!ally_segment(*victim,origin,end,radius)||!exposed(point))continue;
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
        Event event;event.kind=EXTERNAL_DAMAGE;event.unit_kind=4;event.action_index=103;event.source_id=u.logical_id;event.target_id=victim.id;event.external_kind=victim.kind;event.position=point;event.direction=direction;event.amount=amount;event.projectile=true;external_hit(crowd,event);
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
            Hit damage;damage.source_id=shot.source_id;damage.amount=shot.damage;damage.projectile=true;damage.magical=magical_attack(shot.owner_kind,shot.owner_kind==4?108:300+shot.effect_kind,true);damage.heavy=true;damage.direction=shot.direction;
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
        u.flash_left=std::max(0.0,u.flash_left-delta);
        double stride=u.team==0&&u.kind>=0&&u.kind<ENEMY_KIND_COUNT&&soldiers_[u.kind].active?soldiers_[u.kind].stride:2.4;
        double speed=std::hypot(u.velocity.x,u.velocity.z);
        if(u.team==1&&u.kind>=0&&u.kind<int(allies_.size())&&allies_[u.kind].active&&!data_.walk_cadence.empty()){
            if(u.live_delta>0&&!u.air_phase&&u.action!=data_.actions[9]&&speed>.001){double sample=std::min(160.0,speed*4);int low=int(sample),high=std::min(160,low+1);const auto& c=allies_[u.kind].cadence;u.walk_phase+=(c[low]+(c[high]-c[low])*(sample-low))*u.live_delta*2*M_PI;}
        }else if(!enabled_||u.team!=0||u.action==data_.actions[0]||u.action==ENEMY_CHARGE_RUSH){
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
    if(!enabled_||u.team!=0||u.kind<0||u.kind>=ENEMY_KIND_COUNT||!soldiers_[u.kind].active||data_.soldier_pose_meta.empty())return;
    if(pet_skin_count(u.kind))return; // The sprite shader resolves direction and pose from the packed clock.
    if(u.frozen>0&&soldiers_[u.kind].poses[15]>0){const auto& meta=soldiers_[u.kind].poses;int frame=int(std::min(u.ice_time*30,double(meta[15]-1)));u.pose_row=data_.soldier_pose_rows[meta[14]+frame];return;}
    if(u.kind==18&&u.action>=300&&u.action<306&&u.action_active&&!data_.finale_meta.empty()){u.pose_row=int(finale_frame(u)[0]);return;}
    if(u.kind==17&&u.action==LUMINA_SPIN_ACTION&&u.action_active){u.pose_row=int(data_.dark_lumina_spin[std::clamp(int(u.phase_tick+1e-6),0,27)*3+(u.chain_count==1?0:1)]);return;}
    const auto& meta=soldiers_[u.kind].poses;int clip=0;double tick=u.pose_time*30;bool loop=true;
    if(u.action==data_.actions[6]){clip=7;tick=(16.0/30-u.stun)*30;loop=false;}
    else if(u.action==ENEMY_CHARGE_WINDUP){clip=2;tick=u.phase_tick;loop=false;}
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
    for(auto& u:crowd.units_)if(u.alive&&u.team==1){
        if(escort_kind(u.kind))regen_pet_mana(u,delta);
        if(u.shelter_mode==2){shelter(crowd,u,delta,false);if(u.shelter_mode==2)u.status|=data_.status_bits[6];else u.status&=~data_.status_bits[6];}
    }
}
void Combat::regen_pet_mana(Unit& u,double delta){
    u.pet_mana=std::min<double>(data_.pet_mana+u.pet_mana_bonus,u.pet_mana+data_.pet_mana_regen*delta);
}
}
