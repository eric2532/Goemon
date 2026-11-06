#include "core.h"
#include <algorithm>
namespace army {
// Same Unit, target queries, hit delivery, projectiles and pose rows as the army.
void Combat::lumina_event(const Unit& u,int cue){
    Event e;e.kind=STATUS_EVENT;e.unit_kind=u.kind;e.source_id=u.logical_id;e.position=u.position;e.direction={-std::sin(u.yaw),0,-std::cos(u.yaw)};e.action_index=200+cue;if(cue==11)e.amount=u.chain_count;emit(e);
}
void Combat::lumina_begin(Unit& u,int phase){
    if(!u.action_active)attack_started(u);
    bool fast_recovery=phase==PREPARE&&(u.soldier_phase==MELEE_A||u.soldier_phase==MELEE_B);
    u.soldier_phase=phase;u.action=phase==LUMINA_SPIN?LUMINA_SPIN_ACTION:data_.actions[phase+1];u.action_active=true;
    u.phase_tick=0;u.action_time=0;u.sweep_marker=0;u.primary_hit=fast_recovery;u.has_goal=false;u.pose_velocity={};u.air_phase=0;u.special_time=0;
    if(phase==LUMINA_SPIN){Vec3 direction=u.landing_goal-u.position;u.chain_count=std::remainder(std::atan2(-direction.x,-direction.z)-u.yaw,float(2*M_PI))<0?1:-1;}
    lumina_event(u,phase==LUMINA_SPIN?11:phase==FIRE?1:phase==MELEE_A?0:phase==PREPARE?6:phase==RELOAD?2:3);
}
void Combat::lumina_decide(Crowd& crowd,Unit& u,double dt){
    if(dt<=0)return;
    if(u.air_phase&&!u.action_active){u.has_goal=false;return;}
    if(u.stun>0){u.action=data_.actions[6];u.has_goal=false;return;}
    if(u.action_active){u.has_goal=false;return;}
    u.action=data_.actions[0];u.recovery_left=std::max(0.0,u.recovery_left-dt);
    if(u.recovery_left>0){u.has_goal=false;return;}
    u.think_left-=dt;Vec3 foot;
    if(u.think_left<=0||((u.target_handle||u.external_kind>=0)&&!target(crowd,u,foot))){choose_target(crowd,u);u.think_left=.1;}
    if(!target(crowd,u,foot)){return;}
    const auto& profile=soldiers_[17];Vec3 direction=foot-u.position;
    float desired=std::atan2(-direction.x,-direction.z),turn=std::remainder(desired-u.yaw,float(2*M_PI));
    float amount=profile.turn_speed*float(dt);u.yaw+=std::clamp(turn,-amount,amount);
    bool facing=std::abs(turn)<.35f;float distance=std::hypot(direction.x,direction.z);
    if(facing&&distance<=72*data_.dark_lumina[22]*data_.enemy_size&&std::abs(direction.y)<6&&crowd.terrain.ray_clear(u.position+Vec3{0,float(data_.dark_lumina[14]),0},foot+Vec3{0,1,0},u.external_kind==2?u.external_target:-1)){
        int choice=u.combo_serial++%4;
        int phase=choice==3?LUMINA_SPIN:choice==1?RELOAD:choice==2?MELEE_A:FIRE;
        float reach=choice==3?float(4.8*data_.dark_lumina[16]*data_.dark_lumina[22]*data_.enemy_size):float(profile.range);
        if(choice>=2&&distance>reach){crowd.set_goal(u.handle,u.target_goal,profile.speed);--u.combo_serial;return;}
        u.landing_goal=foot;lumina_begin(u,phase);return;
    }
    crowd.set_goal(u.handle,u.target_goal,profile.speed);
}
void Combat::lumina_advance(Crowd& crowd,Unit& u,double dt){
    const auto& d=data_.dark_lumina;const auto& profile=soldiers_[17];
    if(u.soldier_phase==RELOAD&&u.phase_tick>=38&&u.air_phase)return;
    if(u.soldier_phase==RELOAD&&u.just_landed){u.phase_tick=std::max(u.phase_tick,d[6]-1);u.just_landed=false;}
    double tempo=(u.soldier_phase==MELEE_A||u.soldier_phase==MELEE_B||(u.soldier_phase==PREPARE&&u.primary_hit))?d[17]:u.soldier_phase==FIRE?d[21]:1;
    double before=u.phase_tick;u.phase_tick+=dt*30*tempo;u.action_time=u.phase_tick/30;
    auto crossed=[&](double tick){return before<tick&&u.phase_tick>=tick;};
    int phase=u.soldier_phase;
    if(phase==LUMINA_SPIN){
        int old_frame=std::clamp(int(before+1e-6),0,27),frame=std::clamp(int(u.phase_tick+1e-6),0,27);
        u.yaw+=(data_.dark_lumina_spin[frame*3+2]-data_.dark_lumina_spin[old_frame*3+2])*u.chain_count;
        if(crossed(7))boss_area(crowd,u,u.position,float(4.8*d[16]*d[22]),profile.damage,float(M_PI));
        if(u.phase_tick>=27){lumina_begin(u,PREPARE);return;}
        return;
    }
    if(phase==MELEE_A&&crossed(d[0])){
        if(melee_contact(crowd,u)){
            deliver(crowd,u,profile.damage*.25,false,u.position);
            if(auto victim=crowd.unit(u.target_handle))victim->stun=std::max(victim->stun,.15);
            lumina_begin(u,MELEE_B);return;
        }
    }
    if(phase==MELEE_B){
        if(u.phase_tick<d[5]){
            if(auto victim=crowd.unit(u.target_handle))victim->stun=std::max(victim->stun,.15);
            else if(u.external_kind==0){Event e;e.kind=STATUS_EVENT;e.unit_kind=17;e.source_id=u.logical_id;e.target_id=u.external_target;e.action_index=210;e.amount=.15;emit(e);}
        }
        for(int i=0;i<2;++i)if(crossed(d[4+i])){
            Vec3 foot;if(target(crowd,u,foot)&&length(foot-u.position)<=profile.range+3){
                deliver(crowd,u,profile.damage*(i?.75:.25),false,u.position);
                if(auto victim=crowd.unit(u.target_handle)){victim->stun=0;victim->knockback=normalized(foot-u.position)*(i?12.f:0.f);}
            }
            lumina_event(u,i?5:4);
        }
    }
    if(phase==FIRE){
        if(crossed(35)){Vec3 foot;if(target(crowd,u,foot))u.landing_goal=foot;}
        for(int i=0;i<int(d[3]);++i)if(crossed(d[1]+i*d[2])){
            Vec3 mouth=u.position+rotated_y(Vec3{float(d[13]),float(d[14]),float(d[15])}*data_.enemy_size,u.yaw);
            for(int side:{-1,1}){
                Projectile p;p.id=next_projectile_++;p.source_id=u.logical_id;p.owner_kind=17;p.source_team=0;p.position=mouth;p.origin=u.landing_goal+Vec3{0,1,0};
                p.direction=rotated_y(normalized(p.origin-mouth),float(side*d[10]));p.speed=float(d[7]);p.life=d[8];p.radius=float(d[9])*data_.enemy_size;p.tail=p.radius;p.damage=profile.damage*.5*u.enemy_damage_scale;p.scale=data_.enemy_size;p.target_kind=u.external_kind;p.target_id=u.external_target;p.target_handle=u.target_handle;
                projectiles_.push_back(p);
            }
            lumina_event(u,7);
        }
    }
    if(phase==RELOAD){
        for(int i=0;i<2;++i)if(crossed(d[6]+i*d[12]*30)){
            boss_area(crowd,u,u.position,float(d[11]*(i?1:.7)),profile.damage,float(M_PI),false,true);lumina_event(u,8+i);
        }
    }
    if(u.phase_tick>=profile.kit[phase]){
        if(phase!=PREPARE){lumina_begin(u,PREPARE);return;}
        u.action_active=false;u.action=data_.actions[0];u.action_time=0;u.phase_tick=0;u.recovery_left=.5/tempo;
    }
}
}
