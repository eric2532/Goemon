#include "core.h"
#include <algorithm>

namespace army {
namespace {
float flat(Vec3 a,Vec3 b){return std::hypot(a.x-b.x,a.z-b.z);}
constexpr double durations[]={0,2.5,3.3,4.67,2.6,4.67,4.0,4.0,4.67};
constexpr float climb_radius=12,climb_speed=8;
int boss_support(Terrain& terrain,Vec3 foot){
    int layer=terrain.choose_layer(foot);if(layer>=0)return layer;
    // A capsule rests above the navigation height at the center of a slope.
    bool valid=false;Vec3 floor=terrain.landing(foot,foot.y+.1f,valid);
    return valid?terrain.choose_layer(floor):-1;
}
}
void Combat::boss_enter(Unit& u,int move,Vec3 aim){
    auto& b=skullpions_[u.handle];b.time=0;b.marker=0;b.origin=u.position;b.aim=aim;
    u.action=100+move;u.action_time=0;u.action_active=move!=0;u.has_goal=false;
    if((move>=1&&move<=5)||move==8)attack_started(u); // Climbing and exposed-core reactions are not attacks.
    u.special_time=0;u.air_stalled=0;u.pose_time=0;u.just_landed=false;
    u.air_phase=move==6?1:(move==7&&u.air_phase?4:0);
    b.followup=false;
    if(move!=2&&move!=7)u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);
    Event cue;cue.kind=STATUS_EVENT;cue.unit_kind=4;cue.source_id=u.logical_id;cue.action_index=u.action;cue.position=aim;cue.direction=u.position;cue.amount=move==4?1.3:(move==5?.6:.65);emit(cue);
}
void Combat::boss_decide(Crowd& crowd,Unit& u,double dt){
    auto& b=skullpions_[u.handle];u.has_goal=false;
    if(dt<=0||u.stun>0||data_.skullpion.empty())return;
    b.seek_left=std::max(0.0,b.seek_left-dt);
    if(u.action_active){
        // Compress only the sand windup; retain its active animation and recovery.
        if(u.action!=106&&u.action!=107)dt*=u.attack_slow_factor;
        double windup=u.action==103?std::min(dt,std::max(0.0,2.33-b.time)/5.0):0;
        b.time+=dt+windup*4;u.action_time=b.time;return;
    }
    b.wait=std::max(0.0,b.wait-dt);
    if(b.wait>0){u.action=100;return;}
    if(!b.followup){
        if(b.seek_left<=0){
            b.seek_left=.75;
            b.climb=crowd.terrain.climb_surface(u.position,climb_radius,35);
            if(b.climb.valid){boss_enter(u,6,b.climb.crest);u.yaw=std::atan2(-b.climb.normal.x,-b.climb.normal.z);return;}
            b.castle_found=false;float nearest=INFINITY;int priority=-1;
            for(const auto& fort:targets_)if(fort.kind==2&&fort.hp>0&&fort.targetable&&fort.maximum.y-fort.minimum.y>=12){
                Vec3 face{std::clamp(u.position.x,fort.minimum.x,fort.maximum.x),fort.minimum.y,std::clamp(u.position.z,fort.minimum.z,fort.maximum.z)};
                float gap=flat(u.position,face);
                if(fort.assault_priority==4&&gap>28)continue;
                if(fort.assault_priority<priority||(fort.assault_priority==priority&&gap>=nearest))continue;
                Vec3 outward=normalized(Vec3{u.position.x-face.x,0,u.position.z-face.z});
                if(length(outward)<.01f)outward=normalized(u.position-(fort.minimum+fort.maximum)*.5f);
                outward.y=0;if(length(outward)<.01f)outward={0,0,1};
                Vec3 goal=face+normalized(outward)*(u.radius+1);goal.y=float(crowd.terrain.height(goal.x,goal.z));
                if(!finite(goal)||!crowd.terrain.reachable(u.position,goal,u.radius,u.support_layer))continue;
                b.castle_goal=goal;b.castle_found=true;nearest=gap;priority=fort.assault_priority;
            }
        }
        if(b.castle_found){u.action=100;crowd.set_goal(u.handle,b.castle_goal,float(data_.skullpion[0]));return;}
    }
    Vec3 aim;bool found=false;
    // Pursue the player locally; outside the fight, approach existing fort targets.
    if(hero_row_>=0){const auto& hero=targets_[hero_row_];if(hero.hp>0&&hero.targetable&&flat(u.position,hero.foot)<38&&crowd.terrain.reachable(u.position,hero.foot,u.radius,u.support_layer)){aim=hero.foot;u.target_goal=aim;found=true;u.target_handle=0;u.external_target=hero.id;u.external_kind=0;}}
    if(!found){choose_target(crowd,u);found=target(crowd,u,aim);}
    if(!found){u.action=100;return;}
    float distance=flat(u.position,aim);
    u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);
    if(distance>24&&!b.followup){
        u.action=100;crowd.set_goal(u.handle,u.target_goal,float(data_.skullpion[0]));return;
    }
    constexpr int moves[]={1,2,3,4,5,8};
    int count=b.followup||u.hp<=u.max_hp/3?6:4;
    int move=moves[b.serial++%count];
    b.followup=false;
    boss_enter(u,move,aim);
}
bool Combat::boss_move(Crowd& crowd,Unit& u,double dt,Vec3& next){
    if(u.stun>0)return true;
    auto found=skullpions_.find(u.handle);if(found==skullpions_.end()||!u.action_active)return false;
    auto& b=found->second;int move=u.action-100;double t=b.time;
    if(move==1&&t>=.65&&t<1.45){
        Vec3 direction{std::sin(u.yaw),0,std::cos(u.yaw)};
        next=crowd.terrain.direct_move(u.position,direction*float(20*dt*u.attack_slow_factor),u.radius,u.support_layer);return true;
    }
    if(move==6){
        u.special_time+=dt;
        auto phase=[&](int value){u.air_phase=value;u.special_time=0;u.air_stalled=0;u.pose_time=0;};
        if(!b.climb.valid||(u.air_phase>=2&&u.air_phase<=3&&!crowd.terrain.climb_support(b.climb,u.position,climb_radius)))phase(4);
        Vec3 motion;
        if(u.air_phase==1){
            Vec3 offset=b.climb.base-u.position;offset.y=0;
            motion=normalized(offset)*std::min(length(offset),float(12*dt));
            // Floor depenetration is not a jump impulse.
            motion.y=float(std::max(-30.0,std::min(0.0,double(u.velocity.y))-30*dt)*dt);
        }else if(u.air_phase==2){motion={0,std::min(b.climb.crest.y-u.position.y,float(climb_speed*dt)),0};}
        else if(u.air_phase==3&&u.special_time>=1.2){
            bool valid=false;Vec3 aim=u.position+b.climb.normal*18;
            aim=crowd.terrain.landing(aim,u.position.y+8,valid);
            if(valid){
                b.aim=aim;b.jump_velocity=8;phase(5);b.marker=1;
                Event cue;cue.kind=STATUS_EVENT;cue.unit_kind=4;cue.source_id=u.logical_id;cue.action_index=106;cue.position=aim;cue.amount=1.3;emit(cue);
            }else phase(4);
        }
        if(u.air_phase==5){
            b.jump_velocity=std::max(-30.0f,b.jump_velocity-float(30*dt));
            Vec3 offset=b.aim-u.position;offset.y=0;
            motion=normalized(offset)*std::min(length(offset),float(14*dt));motion.y=b.jump_velocity*float(dt);
        }
        if(u.air_phase==4){
            bool attached=crowd.terrain.climb_support(b.climb,u.position,climb_radius);
            motion={0,attached?float(-climb_speed*dt):float(std::max(-30.0,std::min(0.0,double(u.velocity.y))-30*dt)*dt),0};
        }
        auto moved=crowd.terrain.air_move(u.position,motion,climb_radius,24,12);next=moved.position;
        if(u.air_phase==5&&moved.normal.y<-.5f)b.jump_velocity=std::min(0.0f,b.jump_velocity);
        float progress=length(next-u.position);
        if(u.air_phase==1){
            if(flat(next,b.climb.base)<.3f&&std::abs(next.y-b.climb.base.y)<.5f)phase(2);
            else {u.air_stalled=progress<dt?u.air_stalled+dt:0;if(u.air_stalled>.4||u.special_time>4)phase(4);}
        }else if(u.air_phase==2){
            if(next.y>=b.climb.crest.y-.02f)phase(3);
            else {u.air_stalled=next.y-u.position.y<dt?u.air_stalled+dt:0;if(u.air_stalled>.4||u.special_time>6)phase(4);}
        }else if((u.air_phase==4||u.air_phase==5)&&moved.floor){phase(0);u.just_landed=true;u.support_layer=boss_support(crowd.terrain,next);}
        return true;
    }
    if(move==4){
        double start=.65,travel=1.0;
        if(t<start)return true;
        double fraction=std::clamp((t-start)/travel,0.0,1.0);
        Vec3 wanted=b.origin+(b.aim-b.origin)*float(fraction);
        wanted.y+=float(6*std::sin(fraction*M_PI));
        auto moved=crowd.terrain.air_move(u.position,wanted-u.position,12.0f,24.0f,12.0f);
        next=moved.position;
        return true;
    }
    if(move==7){
        auto moved=crowd.terrain.air_move(u.position,Vec3{0,float(std::max(-30.0,std::min(0.0,double(u.velocity.y))-30*dt)*dt),0},12,24,12);
        next=moved.position;if(moved.floor){u.air_phase=0;u.support_layer=boss_support(crowd.terrain,next);}else u.air_phase=4;
        return true;
    }
    return true;
}
void Combat::boss_area(Crowd& crowd,Unit& u,Vec3 center,float reach,double damage,float arc,bool poison,bool low,bool wind,std::vector<Vec3>* wind_targets){
    damage*=u.enemy_damage_scale;
    auto track_wind=[&](int64_t key,Vec3 point){
        if(!wind_targets)return;
        auto at=std::lower_bound(u.action_hits.begin(),u.action_hits.end(),key);
        if(at==u.action_hits.end()||*at!=key){u.action_hits.insert(at,key);wind_targets->push_back(point+Vec3{0,1.2f,0});}
    };
    reach*=u.kind==4?5:data_.enemy_size;
    auto contacts=[&](Vec3 foot){
        if(flat(foot,center)>reach||std::abs(foot.y-center.y)>(low?1.0f:5.0f))return false;
        Vec3 origin=wind?u.position:center;
        if(arc<float(M_PI)&&std::abs(std::remainder(std::atan2(foot.x-origin.x,foot.z-origin.z)-u.yaw-(u.kind==17?float(M_PI):0),float(2*M_PI)))>arc)return false;
        return true;
    };
    Vec3 pad{reach,8,reach};
    for(auto h:crowd.query(center-pad,center+pad,1)){
        auto ally=crowd.unit(h);if(!ally||!contacts(ally->position)||!crowd.terrain.ray_clear(center+Vec3{0,1,0},ally->position+Vec3{0,1,0}))continue;
        Hit damage_hit;damage_hit.amount=damage;damage_hit.magical=magical_attack(u.kind,poison?105:u.action,false);damage_hit.source_id=u.logical_id;damage_hit.direction=normalized(ally->position-center);
        if(wind){damage_hit.direction=normalized(ally->position-u.position);damage_hit.impulse=damage_hit.direction*24;damage_hit.flinch=.3;}
        if(poison){damage_hit.effect=2;damage_hit.slow_factor=.55f;damage_hit.status_seconds=4;}
        hit(crowd,h,damage_hit);if(wind)track_wind(h,ally->position);
    }
    for(const auto& target:targets_){
        if(target.hp<=0||!target.targetable)continue;
        Vec3 point=(target.kind==2||target.body_bounds())?Vec3{std::clamp(center.x,target.minimum.x,target.maximum.x),std::clamp(center.y,target.minimum.y,target.maximum.y),std::clamp(center.z,target.minimum.z,target.maximum.z)}:target.foot;
        if(!contacts(point)||!crowd.terrain.ray_clear(center+Vec3{0,1,0},point+Vec3{0,1,0},target.kind==2?target.id:-1))continue;
        Event event;event.kind=EXTERNAL_DAMAGE;event.source_id=u.logical_id;event.target_id=target.id;event.external_kind=target.kind;event.unit_kind=u.kind;event.action_index=poison?105:u.action;event.position=center;event.amount=damage;event.direction=normalized(point-(wind?u.position:center));event.heavy=true;external_hit(crowd,event);if(wind&&target.kind==0&&target.id>=0)track_wind(~target.id,point);
    }
}
void Combat::boss_advance(Crowd& crowd,Unit& u){
    auto& b=skullpions_[u.handle];double t=b.time;int move=u.action-100;
    if(move<1||move>8)return;
    double damage=data_.skullpion[1];
    if(move==1&&t>=.65&&t<1.45&&t>=.65+b.marker*.2){++b.marker;boss_area(crowd,u,u.position,5.5f,damage,float(M_PI));}
    if(move==2){
        const double contacts[]={.5,1.17,1.7,2.0,2.3,2.6};
        while(b.marker<6&&t>=contacts[b.marker]){int marker=b.marker++;boss_area(crowd,u,u.position,marker<2?6.5f:13.5f,damage,float(M_PI),false,true);}
        if(t>=1.5&&t<2.7)u.yaw+=float(u.live_delta*2*M_PI/1.2);
    }
    if(move==3){
        Vec3 aim;if(target(crowd,u,aim))u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);
        while(2.33+b.marker*.2<4.1&&t+.000001>=2.33+b.marker*.2){++b.marker;boss_sand(crowd,u);}
    }
    if(move==4&&b.marker==0&&t>=1.65){b.marker=1;boss_area(crowd,u,u.position,8,damage,float(M_PI));}
    if(move==5){
        // Each drill strike locks a warning point before emerging from below.
        if(b.marker<6){int strike=b.marker/2;double cue=1.3+strike*.9;
            if(b.marker%2==0&&t>=cue){Vec3 aim;if(target(crowd,u,aim))b.aim=aim;Event event;event.kind=STATUS_EVENT;event.unit_kind=4;event.source_id=u.logical_id;event.action_index=105;event.position=b.aim;event.amount=.6;emit(event);++b.marker;}
            if(b.marker%2==1&&t>=cue+.6){boss_area(crowd,u,b.aim,3.8f,damage*.65f,float(M_PI),true);++b.marker;}
        }
    }
    if(move==6){
        if(!u.just_landed)return;
        b.followup=b.marker==1;
    }
    if(move==8&&b.marker==0&&t>=2.33){
        b.marker=1;
        for(float offset:{0.0f,float(M_PI/4),float(-M_PI/4)}){
            Projectile shot;shot.id=next_projectile_++;shot.source_id=u.logical_id;shot.owner_kind=4;
            shot.direction={std::sin(u.yaw+offset),0,std::cos(u.yaw+offset)};
            shot.position=u.position+Vec3{std::sin(u.yaw)*18,3,std::cos(u.yaw)*18};
            shot.life=5;shot.speed=45;shot.radius=5.76f;shot.tail=1;shot.damage=damage*u.enemy_damage_scale;shot.vertical_speed=12;
            shot.target_kind=u.external_kind;shot.target_id=u.external_target;shot.scale=5;projectiles_.push_back(shot);
        }
    }
    if((move==6&&u.just_landed)||(move!=6&&t>=durations[move]&&(move!=7||u.air_phase==0))){
        u.action_active=false;u.action=100;u.action_time=0;b.wait=b.followup?.35:.9;b.time=0;
        u.air_phase=0;u.just_landed=false;
        if(move==6||move==7)u.velocity.y=0;
        if(move==7)b.armor=0;
    }
}
}
