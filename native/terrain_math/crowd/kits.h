#pragma once
#include "math_types.h"
#include <array>
#include <cstdint>
#include <vector>
namespace army {
// Historical hound owner shares one prepared bank with all selectable companions.
inline bool companion_contact_cue(int cue){return cue<20000&&(cue>=10000||cue==143||cue==138||cue==133||cue==135||cue==137||cue==131||cue==132||cue==264||cue==267||cue==290);}
constexpr int HOUND_KIND=19, SLIME_KIND=20, BEAR_KIND=21, ENEMY_KIND_COUNT=22, HOUND_SKINS=617, HOUND_TIMELINE_STRIDE=42, HOUND_BLINK_CUE=499, HOUND_CUE_BASE=500;
// Retired NPC-teaching codes 12–21 stay unused; shared Bodyguard retains its wire ID.
constexpr int PET_BEE_FLURRY=11,PET_BODYGUARD=22,PET_SKILL_COUNT=22;
constexpr int BODYGUARD_START=6010,BODYGUARD_PUSH=6011;
inline constexpr bool pet_ranged_skill(int skill){return skill>=3&&skill<PET_BEE_FLURRY;}
constexpr double BEE_FLURRY_RATE=1.5;
inline constexpr Vec3 PARTY_FORMATION_POSTS[]={{-7,0,3.5f},{7,0,3.5f},{0,0,-7},{-7,0,-3.5f},{7,0,-3.5f}};
struct KitProfile {bool active=false;float hp=0,speed=0,damage=0,range=0,turn_speed=0,stride=1;std::array<int,16> poses{};std::array<float,26> kit{};float contact_end=0;};
struct PrimaryProfile{double duration=0,contact=0,damage=0,reach=0,arc=0,stop=0,side=1;};
struct AllyProfile{bool active=false;double hp=0,speed=0,damage=1,rate=1,critical=0;std::array<PrimaryProfile,6> primary;std::array<double,161> cadence{};};
constexpr int SLIME_SKINS=29;
constexpr int ZOMBIE_DRAIN=700,ZOMBIE_CHARGE=701,ZOMBIE_HEAL=702,ZOMBIE_BLAST=703;
constexpr int GRAVE_EARTH_WARNING=704,GRAVE_EARTH_IMPACT=705,GRAVE_MAGIC_SEAL=706;
constexpr int RUBY_MEND=707,RUBY_FROST=708,RUBY_FROST_IMPACT=709;
constexpr int RUBY_HEAL=750,RUBY_RECOVER=751,RUBY_GROUP_RECOVER=752,RUBY_HOLY_SHIELD=753;
constexpr int RUBY_PHYSICAL_ABSORB=754,RUBY_MAGIC_ABSORB=755,RUBY_PHYSICAL_REFLECT=756,RUBY_MAGIC_REFLECT=757;
constexpr int RUBY_PHYSICAL_NULL=758,RUBY_MAGIC_NULL=759,RUBY_METEOR=760,RUBY_METEOR_IMPACT=761;
constexpr int RUBY_CONFUSION=762,RUBY_CONFUSED=763,RUBY_PHYSICAL_RETURN=764,RUBY_MAGIC_RETURN=765;
constexpr int RUBY_WARD_BLOCK=766,RUBY_RECOVER_TICK=767,RUBY_WARD_ACTIVE=768,RUBY_HEAL_EFFECT=769;
constexpr int GUARDIAN_CAST=780,GUARDIAN_IMPACT=781,GUARDIAN_SUMMON=782,GUARDIAN_FATAL=783,GUARDIAN_ARRIVAL=784,GUARDIAN_AFFLICTION=790;
constexpr int FALKEN_DRAIN=770,FALKEN_DEATH=771,FALKEN_SUMMON=772,FALKEN_DRAIN_EFFECT=773,FALKEN_DEATH_EFFECT=774,FALKEN_SUMMON_EFFECT=775;
inline bool ruby_spell_action(int action){return action==RUBY_MEND||action==RUBY_FROST||
    (action>=RUBY_HEAL&&action<=RUBY_METEOR)||action==RUBY_CONFUSION||(action>=FALKEN_DRAIN&&action<=FALKEN_SUMMON);}
inline bool ruby_magic_attack(int action){return action==RUBY_FROST||action==RUBY_METEOR||action==RUBY_CONFUSION||action==RUBY_MAGIC_RETURN;}
constexpr int HABARU_DOUBLE_EDGE=710,UNDERSEA_QIGONG=711;
constexpr int HABARU_BRACE=715,HABARU_COUNTER=716,HABARU_RESET=717;
constexpr int ENEMY_CHARGE_WINDUP=719,ENEMY_CHARGE_RUSH=720,ENEMY_CHARGE_RECOVERY=721;
constexpr int GUARD_BREAK_HIT=722,ENEMY_GUARD_BREAK_WINDUP=723,ENEMY_GUARD_RAISED=724;
inline constexpr bool enemy_charge_action(int action){return action>=ENEMY_CHARGE_WINDUP&&action<=ENEMY_CHARGE_RECOVERY;}
constexpr int UNDERSEA_MEDITATION=712,UNDERSEA_HAZE=713,UNDERSEA_EVADE=714;
inline constexpr bool escort_kind(int kind){return kind==HOUND_KIND||kind==BEAR_KIND;}
inline constexpr int pet_skin_count(int kind){return kind==HOUND_KIND?HOUND_SKINS:kind==SLIME_KIND?SLIME_SKINS:kind==BEAR_KIND?5:0;}
struct KitData {
    std::vector<int32_t> soldier_kinds,actions,status_bits,ally_kinds;
    std::vector<int32_t> soldier_pose_meta,soldier_pose_rows,finale_meta,snow_patrol_skins;
    std::vector<double> ally_profiles,ally_primaries,walk_cadence,blademaster,ninja,dragoon,ranger,knight,bunker,skullpion,dark_lumina,finale_shots,finale_ranges;
    std::vector<Vec3> ranger_muzzles,ranger_motion_muzzles;
    std::vector<float> soldier_profiles,phase_ticks,contact_ticks,enemy_kits,enemy_contact_ends,finale_frames,dark_lumina_spin,hound_attacks,slime_attacks,bear_attacks;
    Vec3 melee_from,melee_to,muzzle;
    std::vector<float> pet_geometry; // Per skin: fitted min/max and visual/melee scale; empty preserves ordinary mode.
    std::vector<float> pet_skill_costs;
    float enemy_size=1,hound_move_scale=1,map_enemy_scale=1;
    float hound_hp=0,hound_damage=0,bear_damage=0,pet_mana=0,pet_mana_regen=0;
    float pet_ranged_reach=16;
    float finale_scale=1;
    int cursed_guardian=0;
    bool zombie_boss=false;
    bool grave_boss=false;
    bool ruby_boss=false;
    bool falken_boss=false;
    bool habaru_bears=false;
    bool undersea_boss=false;
    bool slime_approach_boost=false;
    bool slime_guard=false;
    bool enemy_charge=false;
    float bullet_speed=0,bullet_life=0,bullet_tail=0,bullet_radius=0,damage_taken_multiplier=1;
};
enum SoldierPhase{MELEE_A,PREPARE,MELEE_B,FIRE,RELOAD};
constexpr int LUMINA_SPIN=5,LUMINA_SPIN_ACTION=217;
enum DragoonTune {D_AIM_SPEED,D_FALL_MIN,D_FALL_MAX,D_GRAVITY,D_MAX_RANGE,D_LEAP_CD,D_SKILL_CD,D_BUFF_CD,D_BUFF_TIME,D_RANGE,D_JUMP,D_RADIUS,D_HEIGHT,D_CENTER,D_SWEEP_TIME,D_SWEEP_CONTACT,D_SWEEP_INTERVAL,D_SWEEP_DAMAGE,D_SWEEP_REACH,D_SWEEP_ARC,D_SWEEP_STOP,D_PULSE_DAMAGE,D_PULSE_INTERVAL,D_PULSE_RADIUS0,D_PULSE_RADIUS1,D_PULSE_RADIUS2,D_HUNT_TIME,D_HUNT_SPEED,D_HUNT_DAMAGE,D_HUNT_WIDTH,D_HUNT_SEEK,D_HUNT_DASH,D_HUNT_SCALE,D_COUNT};
enum RangerTune {R_BUFF_CD,R_BUFF_TIME,R_SKILL_CD,R_BUFF_SKILL_CD,R_RANGE,R_PRIMARY_RANGE_SCALE,R_GROWTH,R_PRIMARY_SPEED,R_FAN_SPEED,R_RANGE_METRES,R_WIDTH,R_FAN_STEP,R_NORMAL_YAW,R_NORMAL_PITCH,R_POWER_YAW,R_POWER_PITCH,R_POWER_DAMAGE,R_FAN_DAMAGE,R_FAN_POWER_DAMAGE,R_FAR,R_STANDOFF,R_NEAR,R_RETREAT,R_PRIMARY_REACH,R_HEIGHT,R_CURVE_SIDE,R_CURVE_UP,R_CURVED,R_COUNT};
enum KnightTune {K_BUFF_CD,K_BUFF_TIME,K_RIPOSTE,K_COUNTER_DAMAGE,K_INTERVAL,K_TRAVEL,K_TAIL,K_START,K_DISTANCE,K_THICKNESS,K_WIDTH,K_HEIGHT,K_RANGE,K_COUNT};
bool valid_kit_data(const KitData& data);
}
