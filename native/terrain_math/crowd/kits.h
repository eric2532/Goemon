#pragma once
#include "math_types.h"
#include <array>
#include <cstdint>
#include <vector>
namespace army {
struct KitProfile {bool active=false;float hp=0,speed=0,damage=0,range=0,turn_speed=0,stride=1;std::array<int,16> poses{};};
struct PrimaryProfile{double duration=0,contact=0,damage=0,reach=0,arc=0,stop=0,side=1;};
struct AllyProfile{bool active=false;double hp=0,speed=0,damage=1,rate=1,critical=0;std::array<PrimaryProfile,6> primary;std::array<double,161> cadence{};};
struct KitData {
    std::vector<int32_t> soldier_kinds,actions,status_bits,ally_kinds;
    std::vector<int32_t> soldier_pose_meta,soldier_pose_rows;
    std::vector<double> ally_profiles,ally_primaries,walk_cadence,ninja,dragoon,ranger,knight,bunker;
    std::vector<Vec3> ranger_muzzles,ranger_motion_muzzles;
    std::vector<float> soldier_profiles,phase_ticks,contact_ticks;
    Vec3 melee_from,melee_to,muzzle;
    float bullet_speed=0,bullet_life=0,bullet_tail=0,bullet_radius=0,damage_taken_multiplier=1;
};
enum SoldierPhase{MELEE_A,PREPARE,MELEE_B,FIRE,RELOAD};
enum DragoonTune {D_AIM_SPEED,D_FALL_MIN,D_FALL_MAX,D_GRAVITY,D_MAX_RANGE,D_LEAP_CD,D_SKILL_CD,D_BUFF_CD,D_BUFF_TIME,D_RANGE,D_JUMP,D_RADIUS,D_HEIGHT,D_CENTER,D_SWEEP_TIME,D_SWEEP_CONTACT,D_SWEEP_INTERVAL,D_SWEEP_DAMAGE,D_SWEEP_REACH,D_SWEEP_ARC,D_SWEEP_STOP,D_PULSE_DAMAGE,D_PULSE_INTERVAL,D_PULSE_RADIUS0,D_PULSE_RADIUS1,D_PULSE_RADIUS2,D_COUNT};
enum RangerTune {R_BUFF_CD,R_BUFF_TIME,R_SKILL_CD,R_BUFF_SKILL_CD,R_RANGE,R_PRIMARY_RANGE_SCALE,R_GROWTH,R_PRIMARY_SPEED,R_FAN_SPEED,R_RANGE_METRES,R_WIDTH,R_FAN_STEP,R_NORMAL_YAW,R_NORMAL_PITCH,R_POWER_YAW,R_POWER_PITCH,R_POWER_DAMAGE,R_FAN_DAMAGE,R_FAN_POWER_DAMAGE,R_FAR,R_STANDOFF,R_NEAR,R_RETREAT,R_PRIMARY_REACH,R_HEIGHT,R_CURVE_SIDE,R_CURVE_UP,R_CURVED,R_COUNT};
enum KnightTune {K_BUFF_CD,K_BUFF_TIME,K_RIPOSTE,K_COUNTER_DAMAGE,K_INTERVAL,K_TRAVEL,K_TAIL,K_START,K_DISTANCE,K_THICKNESS,K_WIDTH,K_HEIGHT,K_RANGE,K_COUNT};
bool valid_kit_data(const KitData& data);
}
