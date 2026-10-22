#include "core.h"
#include <algorithm>
namespace army {
Vec3 Combat::bunker_face(const Crowd& crowd,const ShelterTarget& b,Vec3 target) const{
    Vec3 v=target-b.center;v.y=0;Vec3 p=b.center+v*float(data_.bunker[0]/std::max(.01f,std::max(std::abs(v.x),std::abs(v.z))));
    p.y=float(crowd.allied_terrain.height(p.x,p.z));return p;
}
Unit* Combat::bunker_target(Crowd& crowd,const ShelterTarget& b,float reach){
    Vec3 pad{reach+14,reach+14,reach+14};Unit* best=nullptr;float distance=INFINITY;
    for(auto h:crowd.query(b.center-pad,b.center+pad,0)){
        auto e=crowd.unit(h);if(!e)continue;
        Vec3 origin=bunker_face(crowd,b,e->position)+Vec3{0,1.2f,0},aim=enemy_contact(*e,origin);float gap=length(aim-origin);
        if(gap>reach||gap>=distance||!crowd.terrain.ray_clear(origin,aim))continue;
        distance=gap;best=e;
    }
    return best;
}
void Combat::bunker_enter(Crowd& crowd,Unit& u,const ShelterTarget& b){
    u.bunker_damage=b.damage_serial;u.bunker_pending=false;u.bunker_stage=0;
    if(u.kind!=8||data_.bunker.empty())return;
    int occupied=0;for(const auto& other:crowd.units_)if(other.alive&&other.handle!=u.handle&&other.kind==8&&other.shelter_mode==2&&other.shelter_id==b.id)++occupied;
    u.position=b.center+Vec3{float((occupied%3-1)*4),float(data_.bunker[1]),float((occupied/3%3-1)*4)};
}
void Combat::bunker_tick(Crowd& crowd,Unit& u,const ShelterTarget& b,double dt){
    if(!u.action_active||!u.cast_confirmed)u.chain_left=std::max(0.0,u.chain_left-dt);
    if(u.chain_left<=0)u.chain_count=0;
    u.bunker_shot=std::max(0.0,u.bunker_shot-dt);u.roll_left=std::max(0.0,u.roll_left-dt);u.skill_left=std::max(0.0,u.skill_left-dt);u.buff_left=std::max(0.0,u.buff_left-dt);
    if(u.bunker_damage!=b.damage_serial){u.bunker_pending=true;u.bunker_damage=b.damage_serial;}
    auto aim_at=[&](Unit& e){u.target_handle=e.handle;u.position=bunker_face(crowd,b,e.position);Vec3 aim=enemy_contact(e,u.position+Vec3{0,1.2f,0});u.yaw=std::atan2(aim.x-u.position.x,aim.z-u.position.z);return aim;};
    Vec3 saved=u.position;
    if(u.kind==8&&u.bunker_shot<=0&&u.skill_left<=0){
        if(auto e=bunker_target(crowd,b,22)){
            u.bunker_aim=enemy_contact(*e,b.center+Vec3{0,1,0});Vec3 v=u.bunker_aim-b.center;v.y=0;
            u.bunker_launch=b.center+v*(6/std::max(.01f,std::max(std::abs(v.x),std::abs(v.z))));u.bunker_launch.y=b.center.y+float(data_.bunker[1]);
            u.target_handle=e->handle;u.shelter_mode=4;u.bunker_stage=1;u.bunker_age=0;u.has_goal=false;
        }
    }else if((u.kind==10||u.kind==5)&&u.bunker_shot<=0){
        if(auto e=bunker_target(crowd,b,u.kind==10?20:28)){
            Vec3 aim=aim_at(*e);
            if(u.kind==10){
                const auto& attack=allies_[10].primary[0];u.combo_serial=0;u.ranger_power=u.ranger_shots%3==2;u.action_time=attack.contact;u.attack_damage=attack.damage*allies_[10].damage*std::min(1.5,1.0+.05*u.chain_count);
                ranger_fire(crowd,u,aim,false);u.bunker_shot=data_.bunker[3]/std::max(.01,ally_tempo(u));
            }else{ninja_stars(crowd,u,aim);u.bunker_shot=data_.ninja[7];}
            u.motion_impulse={};
        }
    }else if(u.kind==11&&u.bunker_pending&&!u.action_active){
        u.bunker_pending=false;
        if(auto e=bunker_target(crowd,b,float(data_.bunker[4]))){
            aim_at(*e);const auto& attack=allies_[11].primary[u.combo_serial%6];u.action=data_.actions[8];u.action_active=true;u.action_time=0;u.primary_hit=false;u.cast_confirmed=false;u.attack_damage=attack.damage*allies_[11].damage*std::min(1.5,1.0+.05*u.chain_count);
            u.bunker_launch=u.position;
        }
    }
    if(u.kind==11&&u.action_active){
        u.position=u.bunker_launch;
        if(u.hit_pause>0)u.hit_pause=std::max(0.0,u.hit_pause-dt);else ally_advance(crowd,u,dt);
    }
    if(u.shelter_mode==2)u.position=saved;
}
bool Combat::bunker_move(Crowd& crowd,Unit& u,double dt,Vec3& next){
    const auto& d=data_.dragoon;
    if(u.bunker_stage==1){
        Vec3 v=u.bunker_launch-u.position;v.y=0;float gap=length(v);
        if(gap<=.5f){u.bunker_stage=2;u.velocity.y=float(d[D_JUMP]);u.air_phase=5;u.action=data_.actions[10];u.action_time=0;}
        else{auto move=crowd.allied_terrain.air_move(u.position,normalized(v)*std::min(gap,float(allies_[8].speed*dt)),float(d[D_RADIUS]),float(d[D_HEIGHT]),float(d[D_CENTER]));next=move.position;return true;}
    }
    u.action_time+=dt;
    Vec3 v=u.bunker_aim-u.position;v.y=0;float vertical=u.velocity.y-float(d[D_GRAVITY]*dt);
    auto move=crowd.allied_terrain.air_move(u.position,normalized(v)*float(allies_[8].speed*dt)+Vec3{0,vertical*float(dt),0},float(d[D_RADIUS]),float(d[D_HEIGHT]),float(d[D_CENTER]));next=move.position;
    const ShelterTarget* b=nullptr;for(const auto& row:shelters_)if(row.id==u.shelter_id){b=&row;break;}
    if(b&&std::max(std::abs(next.x-b->center.x),std::abs(next.z-b->center.z))>data_.bunker[0]+.5&&next.y>b->center.y+float(data_.bunker[1])+.1f){
        u.bunker_stage=3;dragoon_begin(crowd,u,u.bunker_aim);
    }
    return true;
}
void Combat::bunker_finish(Unit& u,const ShelterTarget* b){
    u.bunker_shot=3;u.bunker_stage=0;u.action_active=false;u.has_goal=false;u.motion_impulse={};u.routing=false;
    if(b&&std::max(std::abs(u.position.x-b->center.x),std::abs(u.position.z-b->center.z))<data_.bunker[0]&&u.position.y>b->center.y+data_.bunker[2]){
        u.shelter_mode=2;u.air_phase=0;u.velocity={};u.position.y=b->center.y+float(data_.bunker[1]);
    }else if(b){u.shelter_mode=1;u.air_phase=0;}else{u.shelter_mode=3;u.shelter_id=-1;u.shelter_retry=0;}
}
}
