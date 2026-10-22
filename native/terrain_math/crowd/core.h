#pragma once
#include <array>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <vector>
#include "terrain.h"
#include "combat.h"

namespace army {
using Handle=int64_t;
class CrowdWorker;
class MovementWorker;
struct Generation {
    uint32_t next=1;
    uint32_t take(){return next<=0x7fffffffu?next++:0;}
};
struct Unit {
    Handle handle=0;
    int64_t logical_id=0;
    int team=0,kind=0,action=0,status=0;
    Vec3 position,velocity;
    Vec3 pose_velocity;
    Vec3 goal,guard_post;
    float guard_radius=0;
    int shelter_mode=0;int64_t shelter_id=-1;Vec3 shelter_exit;double shelter_retry=0;
    double bunker_shot=0,bunker_age=0;int64_t bunker_damage=0;bool bunker_pending=false;int bunker_stage=0;Vec3 bunker_launch,bunker_aim;
    float move_speed=0;
    int support_layer=-1;
    bool has_goal=false,routing=false;
    double hp=0,max_hp=0;
    float radius=0,yaw=0;
    double action_time=0,live_delta=0,think_left=0,frozen=0,slow_left=0,stun=0,invuln=0;
    double pose_time=0,walk_phase=0;
    double retaliation=0;int64_t retaliation_source=0;
    double shot_left=0,recovery_left=0,landing_left=0,flash_left=0;
    int pose_row=-1;
    float slow_factor=1;
    Handle target_handle=0;
    int64_t external_target=0;
    int external_kind=-1,soldier_phase=0,soldier_shots=0;
    double phase_tick=0,attack_tick=0;
    bool action_active=false,just_started=false;
    Vec3 knockback,motion_impulse;
    int combo_serial=0,chain_count=0;
    double chain_left=0,combo_left=0,hit_pause=0,attack_damage=0;
    bool primary_hit=false,cast_confirmed=false;
    uint64_t rng=0;
    double pending_drift=0,age=0,skill_left=0,utility_left=0,utility_wait=0,roll_left=0,buff_left=0,special_time=0;
    bool opening=true,ninja_opened=false,suppress_primary=false;
    bool appearance_started=false;double appearance_left=0;
    Vec3 dash_previous,dash_direction;
    std::vector<Handle> action_hits;
    int air_phase=0,sweep_marker=0;
    bool dragoon_opened=false,just_landed=false,landing_attack=false;
    Vec3 landing_goal;
    double air_stalled=0,leap_left=0;
    int ranger_shots=0,ranger_serial=0;
    bool ranger_power=false;
    double frame_tempo=1;
    int frame_chain=0;
    bool knight_opened=false,blocking=false,riposte=false,riposte_attack=false;
    bool alive=false;
};
struct StepTiming {
    bool enabled=false;uint64_t steps=0,facade_object_lookups=0,shared_enemy_updates=0,shared_ally_updates=0,movement_jobs=0,facade_field_reads=0;
    double total=0,grid=0,decisions=0,movement=0,combat=0,animation=0;
    double facade_total=0,facade_unpack=0,facade_rows=0,facade_lookup=0,facade_pose=0,facade_fields=0,facade_callbacks=0;
};
class Crowd {
public:
    Crowd();
    ~Crowd();
    bool begin_step(double delta);
    void finish_step();
    void configure(int capacity,int team_limit);
    Handle spawn(int64_t logical_id,int team,int kind,Vec3 position,double hp,double radius);
    void despawn(Handle handle);
    bool valid(Handle handle) const;
    void clear();
    void rest_allies();
    void set_guard(Handle handle,Vec3 point,float radius);
    std::vector<Unit> snapshot() const;
    const std::vector<Unit>& packed_source() const{return units_;}
    std::vector<Handle> query(Vec3 minimum,Vec3 maximum,int team,bool ordered=true);
    Unit* unit(Handle handle);
    const Unit* unit(Handle handle) const;
    void set_navigation(NavigationData data);
    void set_goal(Handle handle,Vec3 goal,float speed);
    void step(double delta);
    void set_pose(Handle handle,Vec3 position,float yaw);
    Terrain terrain,allied_terrain;
    Combat combat;
    StepTiming timing;
    bool parallel_movement_enabled=true;
    std::array<uint64_t,2> query_candidates{},query_calls{},query_sorted_items{};
private:
    friend class Combat;
    std::vector<Unit> units_;
    std::vector<uint32_t> free_,visited_;
    std::array<int,2> counts_{};
    std::unordered_map<int64_t,uint32_t> ids_;
    std::unordered_map<uint64_t,std::vector<uint32_t>> grid_;
    std::vector<uint32_t> overflow_;
    Generation generation_;
    uint32_t visit_=0;
    int team_limit_=0;
    bool dirty_=true;
    uint64_t pose_revision_=0;
    void rebuild_grid();
    std::unique_ptr<CrowdWorker> worker_;
    std::unique_ptr<MovementWorker> movement_worker_;
    std::array<std::vector<uint32_t>,2> movement_visited_;
    std::array<uint32_t,2> movement_visit_{};
};
}
