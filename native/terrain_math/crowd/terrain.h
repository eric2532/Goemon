#pragma once
#include "math_types.h"
#include <cstdint>
#include <array>
#include <memory>
#include <unordered_map>
#include <vector>
namespace army {
struct NavigationData {
    int width=0;
    float spacing=3;
    Vec3 origin{-240,0,-240};
    Vec3 bounds_min{-1e8f,0,-1e8f},bounds_max{1e8f,0,1e8f};
    std::vector<float> heights,pieces;
    std::vector<uint8_t> covered;
    std::vector<Vec3> obstacle_min,obstacle_max,layer_min,layer_max;
    bool friendly_navigation=false;
    std::vector<Vec3> friendly_obstacle_min,friendly_obstacle_max;
    std::vector<Vec3> ray_min,ray_max;
    std::vector<int64_t> ray_owner;
    // Actual static collision faces, independent of 2D navigation footprints.
    std::vector<Vec3> air_faces;
    std::vector<int64_t> air_owner;
};
struct AirMove {Vec3 position,normal;bool floor=false;};
struct AirQueryWork {bool enabled=false;uint64_t considered=0,kept=0,capsule_tests=0;};
struct NavigationWork {bool enabled=false;uint64_t route_hits=0,waypoints=0,flow_builds=0,topology_builds=0,segments=0,heights=0;double route_ms=0,flow_ms=0,topology_ms=0;};
class Terrain {
    friend struct NavigationCacheTest;
public:
    void configure(NavigationData data);
    mutable AirQueryWork air_profile;
    mutable NavigationWork navigation_profile;
    Vec3 move(Vec3 from,Vec3 goal,float speed,float delta,float radius,int& layer,bool& routing,Vec3 avoidance={});
    double height(float x,float z,int layer=0) const;
    bool clear(Vec3 point,float radius,int layer) const;
    bool reachable(Vec3 from,Vec3 goal,float radius,int layer);
    bool segment(Vec3 from,Vec3 to,float radius,int layer) const;
    int choose_layer(Vec3 point) const;
    bool ray_clear(Vec3 from,Vec3 to,int64_t ignore=-1) const;
    Vec3 direct_move(Vec3 from,Vec3 motion,float radius,int& layer) const;
    AirMove air_move(Vec3 from,Vec3 motion,float radius,float body_height,float center) const;
    Vec3 landing(Vec3 aim,float top,bool& valid) const;
    float projectile_fraction(Vec3 from,Vec3 to,float width,int64_t ignore=-1) const;
private:
    struct Topology {
        int nx=0,nz=0,layer=0;float radius=0;
        std::vector<float> heights;
        std::vector<uint8_t> edges,open;
    };
    struct Flow {int64_t topology=0;int goal=0;std::vector<float> cost;uint64_t used=0;};
    struct RouteCertificate {std::array<uint32_t,6> key{};Vec3 point{};bool valid=false;};
    std::vector<RouteCertificate> route_certificates_;
    NavigationData data_;
    Vec3 minimum_,maximum_;
    bool ready_=false;
    std::unordered_map<uint64_t,std::vector<int>> obstacle_grid_;
    std::unordered_map<int64_t,Topology> topologies_;
    std::vector<Flow> flows_;
    uint64_t clock_=0;
    mutable uint32_t obstacle_visit_=0;
    mutable std::vector<uint32_t> obstacle_visited_;
    std::vector<Vec3> air_faces_,air_minimum_,air_maximum_;
    std::vector<int64_t> air_owner_;
    std::unordered_map<uint64_t,std::vector<int>> air_grid_;
    struct AirNode {Vec3 low,high;int left=-1,right=-1,first=0,count=0;};
    std::vector<int> air_order_;
    std::vector<AirNode> air_nodes_;
    int build_air_node(int first,int end);
    void build_air();
    std::vector<int> air_candidates(Vec3 low,Vec3 high,bool bounded=false) const;
    bool air_ray_clear(Vec3 from,Vec3 to,int64_t ignore) const;
    bool obstacles_clear(Vec3 point,float radius) const;
    bool swept_obstacles_clear(Vec3 from,Vec3 to,float radius) const;
    Topology& topology(float radius,int layer);
    Vec3 waypoint(Vec3 from,Vec3 goal,float radius,int layer);
};
}
