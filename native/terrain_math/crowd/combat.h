#pragma once
#include "kits.h"
#include "terrain.h"
#include <array>
#include <cstdint>
#include <vector>
#include <memory>
#include <unordered_set>
#include <unordered_map>
namespace army {
inline bool magical_attack(int kind,int action,bool projectile){return kind==18||(kind==17&&projectile)||(kind==4&&(action==103||action==105));}
class Crowd;
struct Unit;
struct Hit {
    double amount=0,status_seconds=0;
    int64_t source_id=0,ticket_id=0;
    Vec3 direction,impulse;double flinch=0;bool add_impulse=false;
    bool projectile=false,heavy=false,critical=false,provoke=true,responsive_recoil=false;
    int effect=0;float slow_factor=1,attack_slow_factor=1;
    bool magical=false;
};
struct HitResult {bool accepted=false,dead=false;double hp=0;};
enum EventKind{MELEE,MUZZLE,BULLET,DONE,DAMAGE,DEATH,EXTERNAL_DAMAGE,PROJECTILE_IMPACT,STATUS_EVENT,LANDING_PULSE,SHIELD_COUNTER,ATTACK_STARTED};
struct Event {
    uint64_t serial=0;
    EventKind kind=MELEE;
    int64_t source_id=0,target_id=0,ticket_id=0,projectile_id=0;
    Vec3 position,direction;
    double amount=0,source_tick=0,hp=0;
    bool projectile=false,heavy=false,critical=false;
    int unit_kind=0,team=0,external_kind=-1,action_index=0;
};
struct ProjectileCast {bool confirmed=false;int64_t owner=0;uint64_t rng=1;double critical=0;};
struct Projectile {
    int64_t id=0,source_id=0;
    Vec3 position,direction;
    double age=0,life=0,damage=0;
    float speed=0,tail=0,radius=0,vertical_speed=0;
    std::shared_ptr<ProjectileCast> cast;
    int owner_kind=0,effect_kind=0;
    int source_team=0,target_kind=-1;int64_t target_id=0,target_handle=0,ignore_building=-1;
    bool ranger=false,curved=false,power=false,heavy=false;
    Vec3 origin,curve,flight_direction;
    float distance=0,range=0,scale=1,yaw_offset=0;
    double dash_left=0;
    std::vector<int64_t> hits;
};
struct LandingPulse {double left=0,damage=0;Vec3 position;float radius=0;int index=0;int64_t source_id=0;std::shared_ptr<ProjectileCast> cast;};
struct ShieldCounter {double age=0,damage=0;Vec3 position;float yaw=0,scale=1;int64_t source_id=0;std::shared_ptr<ProjectileCast> cast;std::array<double,3> last{};std::array<bool,3> started{};std::array<std::vector<int64_t>,3> hits;};
struct ShelterTarget {int64_t id=0;Vec3 entrance,center;int64_t damage_serial=0;};
struct ExternalTarget {int64_t id=0;int kind=0;Vec3 foot;double hp=0;bool targetable=true,taunting=false;Vec3 minimum,maximum;int64_t ignore_building=-1;
    int assault_priority=0;
    bool body_bounds() const{return kind==0&&maximum.x>minimum.x&&maximum.y>minimum.y&&maximum.z>minimum.z;}
};
class Combat {
public:
    bool configure(KitData data);
    void spawned(Unit& unit);
    void retired(int64_t handle){skullpions_.erase(handle);}
    void clear();
    void before_move(Crowd& crowd,double delta);
    void after_move(Crowd& crowd,double delta);
    bool move_special(Crowd& crowd,Unit& unit,double delta,Vec3& next);
    void animation_step(Crowd& crowd,double delta);
    HitResult hit(Crowd& crowd,int64_t handle,const Hit& hit);
    const std::vector<Event>& events() const{return events_;}
    const std::vector<Projectile>& active_projectiles() const{return projectiles_;}
    const std::vector<ShieldCounter>& active_counters() const{return counters_;}
    const std::vector<double>& counter_tuning() const{return data_.knight;}
    void set_shelters(std::vector<ShelterTarget> shelters){shelters_=std::move(shelters);}
    void rest_tick(Crowd& crowd,double delta);
    void clear_events(){events_.clear();}
    void set_targets(std::vector<ExternalTarget> targets);
private:
    friend struct NearestQueryTest;
    friend struct TargetDecisionTest;
    friend struct SkullpionTest;
    friend struct DarkLuminaTest;
    struct Skullpion {double time=0,wait=1,armor=0,seek_left=0;int serial=0,marker=0;float jump_velocity=0;bool followup=false,castle_found=false;Vec3 origin,aim,castle_goal;ClimbSurface climb;};
    std::unordered_map<int64_t,Skullpion> skullpions_;
    const float* finale_frame(const Unit& unit) const;
    void finale_decide(Crowd& crowd,Unit& unit,double dt);
    void finale_advance(Crowd& crowd,Unit& unit,double dt);
    void finale_cue(const Unit& unit,int cue,Vec3 point,int source_tick=-1);
    void blademaster_spin(Crowd& crowd,Unit& unit,double dt);
    void mirror_decide(Crowd& crowd,Unit& unit,double dt);
    void lumina_begin(Unit& unit,int phase);
    void lumina_decide(Crowd& crowd,Unit& unit,double dt);
    void lumina_advance(Crowd& crowd,Unit& unit,double dt);
    void lumina_event(const Unit& unit,int cue);
    void boss_enter(Unit& unit,int move,Vec3 aim);
    void boss_decide(Crowd& crowd,Unit& unit,double dt);
    bool boss_move(Crowd& crowd,Unit& unit,double dt,Vec3& next);
    void boss_advance(Crowd& crowd,Unit& unit);
    void boss_sand(Crowd& crowd,Unit& unit);
    void boss_area(Crowd& crowd,Unit& unit,Vec3 center,float reach,double damage,float arc,bool poison=false,bool low=false,bool wind=false,std::vector<Vec3>* wind_targets=nullptr);
    uint64_t nearest_contact_tests_=0,nearest_position_reads_=0;
    struct NearestNode {Vec3 low,high;double magnitude=10;int left=-1,right=-1,first=0,count=0;};
    struct NearestEntry {int64_t handle;Vec3 position;};
    std::vector<NearestEntry> nearest_entries_;
    std::vector<NearestNode> nearest_nodes_;
    uint64_t nearest_revision_=UINT64_MAX;
    bool nearest_fallback_=false;
    double nearest_radius_=1.289,nearest_height_=2.016;
    void rebuild_nearest(Crowd& crowd);
    int build_nearest_node(Crowd& crowd,int first,int end);
    bool enabled_=false;
    KitData data_;
    std::array<KitProfile,19> soldiers_{};
    std::array<AllyProfile,32> allies_{};
    std::vector<Projectile> projectiles_;
    std::vector<LandingPulse> pulses_;
    std::vector<ShieldCounter> counters_;
    std::unordered_set<int64_t> threats_;
    std::vector<int64_t> mirror_targets_;
    int64_t first_taunt_=0,latest_taunt_=0;
    std::vector<Event> events_;
    std::vector<ExternalTarget> targets_;
    std::array<std::vector<size_t>,4> target_groups_;
    int hero_row_=-1,taunt_row_=-1;
    uint64_t target_revision_=0;
    const ExternalTarget* external_target(const Unit& unit) const;
    std::vector<ShelterTarget> shelters_;
    int64_t nearest_enemy(Crowd& crowd,Vec3 origin);
    int64_t guard_enemy(Crowd& crowd,const Unit& unit);
    bool shelter(Crowd& crowd,Unit& unit,double delta,bool active=true);
    Vec3 bunker_face(const Crowd& crowd,const ShelterTarget& bunker,Vec3 target) const;
    Unit* bunker_target(Crowd& crowd,const ShelterTarget& bunker,float reach);
    void bunker_enter(Crowd& crowd,Unit& unit,const ShelterTarget& bunker);
    void bunker_tick(Crowd& crowd,Unit& unit,const ShelterTarget& bunker,double dt);
    bool bunker_move(Crowd& crowd,Unit& unit,double dt,Vec3& next);
    void bunker_finish(Unit& unit,const ShelterTarget* bunker);
    void cancel_owned(const Unit& unit);
    uint64_t serial_=0;
    int64_t next_projectile_=1;
    void emit(Event event);
    void attack_started(const Unit& unit);
    void choose_target(Crowd& crowd,Unit& unit);
    void march_on_base(Crowd& crowd,Unit& unit);
    bool target_approach(Crowd& crowd,const Unit& unit,Vec3& goal);
    struct TargetCandidate {int row=-1;int64_t handle=0;float distance=0;int priority=0;};
    std::vector<TargetCandidate> target_candidates_;
    bool target(Crowd& crowd,const Unit& unit,Vec3& foot) const;
    bool melee_contact(Crowd& crowd,const Unit& unit) const;
    bool gun_contact(Crowd& crowd,const Unit& unit) const;
    void begin(Unit& unit);
    void ally_decide(Crowd& crowd,Unit& unit,double delta);
    void ninja_stars(Crowd& crowd,Unit& unit,Vec3 aim);
    double ally_tempo(const Unit& unit) const;
    void ranger_fire(Crowd& crowd,Unit& unit,Vec3 aim,bool fan);
    void pose_frame(Unit& unit);
    void refresh_status(Unit& unit) const;
    void ninja_begin(Unit& unit,Vec3 aim);
    void ninja_resolve(Crowd& crowd,Unit& unit);
    void dragoon_begin(Crowd& crowd,Unit& unit,Vec3 aim);
    void dragoon_sweep(Unit& unit);
    void dragoon_advance(Crowd& crowd,Unit& unit,double dt);
    void dragoon_land(Crowd& crowd,Unit& unit);
    void landing_pulse(Crowd& crowd,const LandingPulse& pulse);
    void pulses(Crowd& crowd,double delta);
    void knight_code(Unit& unit,double dt);
    void knight_counter(Unit& unit);
    void counters(Crowd& crowd,double delta);
    void ninja_damage_segment(Crowd& crowd,Unit& unit,Vec3 from,Vec3 to,float radius,bool finish);
    float enemy_segment(const Unit& victim,Vec3 from,Vec3 to,float radius) const;
    double random(Unit& unit);
    void ally_start(Crowd& crowd,Unit& unit);
    void ally_advance(Crowd& crowd,Unit& unit,double delta);
    bool ally_primary(Crowd& crowd,Unit& unit);
    Vec3 enemy_contact(const Unit& victim,Vec3 from) const;
    void advance(Crowd& crowd,Unit& unit,double delta);
    void deliver(Crowd& crowd,const Unit& unit,double amount,bool projectile,Vec3 origin);
    void projectiles(Crowd& crowd,double delta,size_t start=0);
    void dragon_flight(Crowd& crowd,Projectile& shot,double delta);
};
}
