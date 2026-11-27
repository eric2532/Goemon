#pragma once
#include <algorithm>
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
    Handle escort_leader=0;
    int escort_slot=-1;
    double escort_refresh=0;
    bool combined_attached=false;
    Vec3 target_goal;
    Vec3 approach_minimum,approach_maximum;
    int64_t approach_target=0;
    bool approach_ready=false,base_marching=false;
    float guard_radius=0;
    int shelter_mode=0;int64_t shelter_id=-1;Vec3 shelter_exit;double shelter_retry=0;
    double bunker_shot=0,bunker_age=0;int64_t bunker_damage=0;bool bunker_pending=false;int bunker_stage=0;Vec3 bunker_launch,bunker_aim;
    float move_speed=0;
    int support_layer=-1;
    bool has_goal=false,routing=false;
    double hp=0,max_hp=0;
    void set_max_hp(double maximum){
        hp=std::clamp(hp+(maximum-max_hp),std::min(1.,maximum),maximum);
        max_hp=maximum;
    }
    std::array<int64_t,10> joint_sources{};
    int joint_count=0;
    bool joint_player=false;
    double joint_until=0,joint_base=0,joint_paid=0;
    double enemy_health_scale=1,enemy_damage_scale=1;
    float body_scale=1;
    mutable std::array<float,7> scaled_geometry{};
    std::array<double,2> ruby_ward_left{};
    std::array<int,2> ruby_ward{},ruby_ward_hits{};
    double ruby_holy_left=0,recover_left=0,recover_tick=0,recover_ratio=0,confusion_left=0;
    int ruby_support=0,ruby_offense=0,ruby_casts=0,ruby_phase_casts=0;
    bool ruby_enraged=false;
    int guardian_tech=0,guardian_hits=0,guardian_combo=1;uint8_t afflicted=0;uint16_t guardian_eligible=0;std::vector<int> guardian_draws;
    std::array<double,6> afflictions{};double poison_tick=0,guardian_counter_left=0,guardian_magic_guard=0;
    uint64_t guardian_status_draws=0,guardian_death_draws=0,guardian_accuracy_draws=0,guardian_combo_draws=0,guardian_ward_draws=0;
    uint64_t falken_draws=0,falken_eligible=0;
    uint64_t falken_death_draws=0,falken_family_draws=0;
    std::array<uint8_t,100> evasion_bag{};
    int evasion_draw=100;
    double dodge_chance=0,dodge_left=0,dodge_cooldown=0;
    Vec3 dodge_direction;
    double counter_chance=0,counter_contact=0,counter_duration=0;
    bool patrol_counter=false;
    uint64_t patrol_counter_bag=0,attack_serial=0;
    double patrol_counter_cooldown=0;
    bool counter_pending=false,counter_active=false,counter_hit=false;
    int64_t counter_source=0;
    Vec3 dodge_offset() const {
        if(dodge_left<=0)return {};
        double tick=(40.0/60-dodge_left)*60;
        double steps=std::min(tick,13.0)-std::max(0.0,tick-28);
        return dodge_direction*float(steps/13*std::clamp(radius*.45f,.8f,3.f));
    }
    float radius=0,yaw=0;
    double action_time=0,live_delta=0,think_left=0,frozen=0,slow_left=0,stun=0,invuln=0;
    double ice_chill=0,ice_thaw=0,ice_time=0;float ice_strength=0;
    float ice_visual() const {return frozen>0?1.f:ice_chill>0?.42f:ice_thaw>0?-float(ice_thaw/2)*ice_strength:0.f;}
    double pose_time=0,walk_phase=0;
    double habaru_pressure=0,habaru_gap=0,habaru_left=0,habaru_control_left=0;int habaru_phase=0;
    double retaliation=0;int64_t retaliation_source=0;float retaliation_range=28;
    double shot_left=0,recovery_left=0,landing_left=0,flash_left=0;
    int pose_row=-1,hound_attack_direction=-1;
    double hound_roam_left=0,hound_return_left=-1,pet_rush_left=0;
    bool hound_strolling=false,hound_focused=false;
    int beast_pet_attacks=-1;
    double beast_pet_seek_left=0;
    int64_t beast_pet_rush_target=0;
    std::array<int,3> pet_skills{};
    int pet_group_mask=0;
    uint64_t pet_skill_bag=0;
    double pet_mana=0;
    double pet_health_bonus=0,pet_damage_bonus=0;
    double pet_move_multiplier=1,pet_attack_multiplier=1,pet_mana_bonus=0;
    std::array<double,PET_SKILL_COUNT> pet_cooldowns{};
    Vec3 pet_flurry_origin,pet_flurry_side;
    double pet_flurry_charge=0;
    int pet_ready_mask=7,pet_skill=0,pet_combo_left=0,pet_combo_limit=8;
    uint64_t pet_cast_serial=0;
    uint64_t bodyguard_bag=0;
    int bodyguard_level=1;
    double bodyguard_left=0;
    bool bodyguard_followup=false;
    HoundOrder hound_order=HOUND_DEFEND;
    int64_t hound_order_serial=0;
    float slow_factor=1,attack_slow_factor=1;
    double attack_slow_left=0,avatar_left=0;
    Handle target_handle=0;
    int64_t external_target=0;
    mutable uint64_t external_revision=UINT64_MAX;
    mutable int external_row=-1;
    int external_kind=-1,soldier_phase=0,soldier_shots=0;
    double phase_tick=0,attack_tick=0;
    double crowd_attack_pressure=0,crowd_attack_wait=0;
    bool action_active=false,just_started=false;
    Vec3 knockback,motion_impulse;
    float knockback_decay=8;
    int combo_serial=0,chain_count=0;
    double chain_left=0,combo_left=0,hit_pause=0,attack_damage=0;
    bool primary_hit=false,cast_confirmed=false;
    uint64_t rng=0;
    double pending_drift=0,age=0,skill_left=0,utility_left=0,utility_wait=0,roll_left=0,buff_left=0,special_time=0;
    bool opening=true,ninja_opened=false,suppress_primary=false;
    int mirror_actions=0;
    double mirror_wait=0;
    float mirror_speed=0,mirror_reach=0,mirror_spell_reach=0;
    Vec3 mirror_approach;
    bool mirror_busy=false;
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
    int64_t guard_seen_attack=0;
    int64_t guard_seen_source=0;
    double guard_reaction=0,guard_left=0,guard_cooldown=0;
    double guard_pressure_until=0;
    uint8_t guard_pressure_hits=0;
    double enemy_charge_cooldown=0;
    uint64_t snow_guard_bag=0,snow_attack_bag=0,pet_guard_bag=0;
    double light_recoil_grace=0;
    bool light_stagger=false;
    bool alive=false;
};
struct StepTiming {
    bool enabled=false;uint64_t steps=0,facade_object_lookups=0,shared_enemy_updates=0,shared_ally_updates=0,movement_jobs=0,facade_field_reads=0,facade_health_writes=0;
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
    bool set_enemy_scaling(Handle handle,double health_scale,double damage_scale);
    bool set_body_scale(Handle handle,float scale);
    bool set_enemy_escort(Handle handle,Handle leader,int slot);
    bool set_boss_reactions(Handle handle,double dodge,double counter);
    bool set_patrol_counter(Handle handle);
    void despawn(Handle handle);
    bool valid(Handle handle) const;
    void clear();
    void rest_allies();
    void set_guard(Handle handle,Vec3 point,float radius);
    bool set_pet_skills(Handle handle,const std::vector<int32_t>& skills,int combo_limit=8);
    bool set_pet_bodyguard_level(Handle handle,int level);
    bool set_pet_skill_ready(Handle handle,int mask);
    bool set_pet_mana(Handle handle,double mana);
    bool set_pet_growth(Handle handle,double health_bonus,double damage_bonus);
    bool set_pet_training(Handle handle,double movement,double attack,double mana_bonus,bool heal);
    bool set_pet_skill_groups(Handle handle,int mask);
    bool set_mirror(Handle handle,int actions,float speed,float reach,Vec3 approach);
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
    std::unordered_map<uint64_t,std::array<std::vector<uint32_t>,2>> grid_;
    std::array<std::vector<uint32_t>,2> overflow_;
    Generation generation_;
    uint32_t visit_=0;
    int team_limit_=0;
    bool dirty_=true;
    uint64_t pose_revision_=0;
    void rebuild_grid();
    std::unique_ptr<CrowdWorker> worker_;
    std::unique_ptr<MovementWorker> movement_worker_;
    struct MovementNeighbor {Vec3 position;float radius;int64_t logical_id;int team;uint32_t slot;};
    struct MovementCell {std::array<std::vector<MovementNeighbor>,2> neighbors;std::array<bool,2> ready{};};
    std::unordered_map<uint64_t,MovementCell> movement_cells_;
};
}
