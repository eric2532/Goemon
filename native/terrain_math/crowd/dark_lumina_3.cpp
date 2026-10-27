#include "core.h"
#include <algorithm>
namespace army {
const float* Combat::finale_frame(const Unit& u) const{
    int move=std::clamp(u.action-300,0,5),tick=std::clamp(int(u.phase_tick),0,data_.finale_meta[move*2+1]-1);
    return data_.finale_frames.data()+(data_.finale_meta[move*2]+tick)*5;
}
void Combat::finale_cue(const Unit& u,int cue,Vec3 point,int source_tick){
    Event e;e.kind=STATUS_EVENT;e.unit_kind=18;e.source_id=u.logical_id;e.position=point;e.direction={-std::sin(u.yaw),0,-std::cos(u.yaw)};e.action_index=300+cue;e.source_tick=source_tick>=0?source_tick:u.phase_tick;if(cue==16||cue==17)e.direction=normalized(u.landing_goal+Vec3{0,data_.finale_scale,0}-point);emit(e);
}
void Combat::finale_decide(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    if(u.stun>0){if(u.action>=300&&u.action<306)finale_cue(u,31,u.position);u.action=data_.actions[6];u.has_goal=false;return;}
    if(u.action_active){u.has_goal=false;if(finale_frame(u)[3]>0)u.invuln=std::max(u.invuln,.06);return;}
    u.action=data_.actions[0];u.recovery_left=std::max(0.0,u.recovery_left-dt);
    if(u.recovery_left>0){u.has_goal=false;return;}
    u.think_left-=dt;Vec3 foot;
    if(u.think_left<=0||((u.target_handle||u.external_kind>=0)&&!target(crowd,u,foot))){choose_target(crowd,u);u.think_left=.1;}
    if(!target(crowd,u,foot)){u.has_goal=false;return;}
    const auto& profile=soldiers_[18];Vec3 direction=foot-u.position;
    float desired=std::atan2(-direction.x,-direction.z),turn=std::remainder(desired-u.yaw,float(2*M_PI));
    u.yaw+=std::clamp(turn,-float(profile.turn_speed*dt),float(profile.turn_speed*dt));
    if(std::abs(turn)<.35f&&std::hypot(direction.x,direction.z)<=24*data_.finale_scale*data_.enemy_size&&std::abs(direction.y)<6&&crowd.terrain.ray_clear(u.position+Vec3{0,1,0},foot+Vec3{0,1,0},u.external_kind==2?u.external_target:-1)){
        u.action=300+u.combo_serial++%6;u.action_active=true;u.phase_tick=0;u.action_time=0;u.sweep_marker=0;u.landing_goal=foot;u.dash_previous=u.position;u.has_goal=false;u.action_hits.clear();u.primary_hit=false;u.soldier_shots=int(random(u)*6);
        attack_started(u);
        finale_cue(u,u.action-300,u.position);return;
    }
    crowd.set_goal(u.handle,u.target_goal,profile.speed);
}
void Combat::finale_advance(Crowd& crowd,Unit& u,double dt){
    int move=u.action-300;if(move<0||move>=6)return;
    double before=u.phase_tick;u.phase_tick+=dt*30;
    if(move==4&&u.air_phase&&before<40&&u.phase_tick>=40)u.phase_tick=39;
    u.action_time=u.phase_tick/30;
    int size=data_.finale_meta[move*2+1],offset=data_.finale_meta[move*2];
    Vec3 forward{-std::sin(u.yaw),0,-std::cos(u.yaw)};
    for(int tick=int(before)+1;tick<=std::min(int(u.phase_tick),size-1);++tick){
        int cue=int(data_.finale_frames[(offset+tick)*5+4]);if(cue)finale_cue(u,cue,u.position);
        int event=int(data_.finale_frames[(offset+tick)*5+1]);if(!event)continue;
        if(event==2||event==5){
            float radius=event==2?12*data_.finale_scale:float(data_.finale_shots[move*4+2]);Vec3 center=u.position+forward*((event==2?5.f:0.f)*data_.finale_scale*data_.enemy_size);
            // Shared local damage/cover query; this boss faces controller -Z.
            std::vector<Vec3> victims;float yaw=u.yaw;u.yaw+=float(M_PI);boss_area(crowd,u,center,radius,event==2?0:soldiers_[18].damage*data_.finale_shots[move*4+3],event==2?1.1f:float(M_PI),false,event==5,event==2,event==2?&victims:nullptr);u.yaw=yaw;
            if(event==2){
                auto launch=[&](Vec3 from,Vec3 direction){
                    Projectile p;p.id=next_projectile_++;p.source_id=u.logical_id;p.owner_kind=18;p.effect_kind=1;p.source_team=0;p.position=from;p.direction=direction;
                    p.speed=float(data_.finale_shots[4]);p.life=data_.finale_shots[5];p.radius=float(data_.finale_shots[6])*data_.enemy_size;p.tail=p.radius;p.damage=soldiers_[18].damage*data_.finale_shots[7]*.5*u.enemy_damage_scale;p.scale=data_.enemy_size*.22f;projectiles_.push_back(p);
                };
                for(int lane=0;lane<4;++lane){
                    float angle=float((lane-1.5)*M_PI/24),s=std::sin(angle),c=std::cos(angle);
                    Vec3 from=u.position+(forward+Vec3{-forward.z,0,forward.x}*float(lane%2?2:-2)+Vec3{0,1,0})*(data_.finale_scale*data_.enemy_size);
                    launch(from,{forward.x*c+forward.z*s,0,-forward.x*s+forward.z*c});
                }
                for(auto point:victims){
                    Vec3 from=u.position+(forward+Vec3{0,1,0})*(data_.finale_scale*data_.enemy_size);
                    Vec3 away=normalized(Vec3{point.x-u.position.x,0,point.z-u.position.z});
                    float lead=std::min(18.f*data_.enemy_size,length(point-from)*24.f/(float(data_.finale_shots[4])-24.f));
                    launch(from,normalized(point+away*lead-from));
                }
            }
            finale_cue(u,event+10,center,tick);
        }else if(event==6){
            int index=(tick-60)/6;float angle=float(index*2*M_PI/5+(tick-60)*2*M_PI/31);
            Vec3 at=u.landing_goal+Vec3{std::sin(angle)*7,1,std::cos(angle)*7}*(data_.finale_scale*data_.enemy_size);finale_cue(u,16,at,tick);
        }else{
            Projectile p;p.id=next_projectile_++;p.source_id=u.logical_id;p.owner_kind=18;p.effect_kind=move;p.power=move==0&&tick>88;p.finale_burst=move==2&&(tick-60)/24==u.soldier_shots;p.source_team=0;
            p.position=u.position+(Vec3{0,1.3f,0}+forward*1.5f)*(data_.finale_scale*data_.enemy_size);p.direction=forward;
            if(event==1&&tick==88)p.position.y=u.position.y+.025f*data_.finale_scale*data_.enemy_size;
            if(event==7){int index=(tick-139)/12;float angle=float(index*2*M_PI/5);p.position=u.landing_goal+Vec3{std::sin(angle)*7,1,std::cos(angle)*7}*(data_.finale_scale*data_.enemy_size);p.direction=normalized(u.landing_goal+Vec3{0,data_.finale_scale*data_.enemy_size,0}-p.position);}
            if(event==3||event==4){
                // Falling hazards keep the original cadence; targets stay in the current local snapshot.
                float angle=float(random(u)*2*M_PI),radius=float(random(u)*data_.finale_ranges[move-2]*data_.enemy_size);
                p.position=u.landing_goal+Vec3{std::sin(angle)*radius,float(data_.finale_ranges[2])*data_.enemy_size,std::cos(angle)*radius};p.direction={event==4?-.18f:0.f,-1,0};p.direction=normalized(p.direction);
            }
            p.speed=float(data_.finale_shots[move*4]);p.life=data_.finale_shots[move*4+1];p.radius=float(data_.finale_shots[move*4+2])*data_.enemy_size;p.tail=p.radius;p.damage=soldiers_[18].damage*data_.finale_shots[move*4+3]*u.enemy_damage_scale;p.scale=data_.enemy_size;p.target_kind=u.external_kind;p.target_id=u.external_target;
            projectiles_.push_back(p);if(event!=4)finale_cue(u,event+10,p.position,tick);
        }
    }
    if(move==0&&finale_frame(u)[2]>0&&!u.primary_hit&&melee_contact(crowd,u)){deliver(crowd,u,soldiers_[18].damage*data_.finale_shots[3],false,u.position);u.primary_hit=true;}
    if(u.phase_tick>=size){finale_cue(u,31,u.position);u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.phase_tick=0;u.recovery_left=.8+u.hp/u.max_hp*.8;}
}
}
