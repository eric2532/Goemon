#pragma once
#include "math_types.h"
#include <array>
#include <map>
#include <vector>
namespace army {
// These indices match army_renderer.gd's immutable source clip table.
enum ClipKey {IDLE,WALK,BACK,PRIMARY0,PRIMARY_WALK0=9,PRIMARY_BACK0=15,SHADOW=21,JUMP,FALL,LEAP,LANDING,SWEEP,GUARD,GUARD_WALK,GUARD_BACK,SHOT,SHOT_WALK,SHOT_BACK,FAN,FAN_WALK,FAN_BACK,HURT,CLIP_COUNT};
struct ClipSample {double start=0,count=1,duration=1;bool loop=false,exists=false;};
struct InstanceProfile {double speed=1,cadence=1;std::array<ClipSample,CLIP_COUNT> clips;};
struct InstanceRow {int kind=0,team=0,status=0,action=0,index=0,air_phase=0,pose_row=-1;Vec3 position,velocity;float yaw=0,render_time=0,pose_time=0,walk_phase=0,flash=0;double hp=0,max_hp=1;};
struct InstanceBatch {int kind=0,x=0,z=0;float low=INFINITY,high=-INFINITY;std::vector<float> buffer;};
struct InstanceBuffers {bool valid=true;int submitted=0;std::vector<InstanceBatch> batches;std::vector<float> health;};
InstanceBuffers instance_buffers(const std::vector<InstanceRow>& rows,const std::map<int,InstanceProfile>& profiles);
}
