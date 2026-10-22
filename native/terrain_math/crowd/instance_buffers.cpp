#include "instance_buffers.h"
#include <algorithm>
#include <tuple>
namespace army {
namespace {
float clip_row(const ClipSample& clip,double time){
 double sample;
 if(clip.loop){sample=std::fmod(time,clip.duration);if(sample<0)sample+=clip.duration;sample*=60;}
 else sample=std::clamp(time*60,0.0,std::max(0.0,clip.count-1));
 return float(clip.start+sample);
}
std::array<float,4> pose(const InstanceRow& row,const InstanceProfile& profile){
 if(row.team==0)return {float(row.pose_row),row.status&1?1.0f:0.0f,0,0};
 int key=IDLE,moving=IDLE;double time=row.pose_time,motion_time=time;
 float sine=float(std::sin(double(row.yaw))),cosine=float(std::cos(double(row.yaw)));
 float speed=std::sqrt(row.velocity.x*row.velocity.x+row.velocity.z*row.velocity.z);
 bool forward=row.velocity.x*sine+row.velocity.z*cosine>=0;
 double strength=std::clamp(double(speed)/std::max(.001,profile.speed),0.0,1.0);
 switch(row.action){
  case 8:key=PRIMARY0+row.index;moving=(forward?PRIMARY_WALK0:PRIMARY_BACK0)+row.index;time=motion_time=row.render_time;break;
  case 9:key=moving=SHADOW;time=motion_time=row.render_time;strength=0;break;
  case 10:key=moving=(row.air_phase==3||row.air_phase==5)?JUMP:(row.air_phase==4?FALL:LEAP);time=motion_time=row.render_time;strength=0;break;
  case 11:key=LANDING;moving=forward?WALK:BACK;time=row.render_time;motion_time=double(row.walk_phase)/(2*M_PI)/profile.cadence;break;
  case 16:key=moving=SWEEP;time=motion_time=row.render_time;strength=0;break;
  case 13:key=GUARD;moving=forward?GUARD_WALK:GUARD_BACK;break;
  case 12:key=row.kind==5?SHOT:FAN;moving=key+(forward?1:2);time=motion_time=row.render_time;break;
  case 6:key=moving=HURT;time=motion_time=row.render_time;strength=0;break;
  default:moving=forward?WALK:BACK;motion_time=double(row.walk_phase)/(2*M_PI)/profile.cadence;break;
 }
 if(key<0||key>=CLIP_COUNT||!profile.clips[key].exists)key=IDLE;
 if(moving<0||moving>=CLIP_COUNT||!profile.clips[moving].exists){moving=key;strength=0;}
 return {clip_row(profile.clips[key],time),clip_row(profile.clips[moving],motion_time),float(strength+(row.status&1?2.0:0.0)),row.flash};
}
void append(std::vector<float>& buffer,Vec3 position,float yaw,std::array<float,4> color){
 float sine=float(std::sin(double(yaw))),cosine=float(std::cos(double(yaw)));
 const float values[]={cosine,0,sine,position.x,0,1,0,position.y,-sine,0,cosine,position.z,color[0],color[1],color[2],color[3]};
 buffer.insert(buffer.end(),std::begin(values),std::end(values));
}
}
InstanceBuffers instance_buffers(const std::vector<InstanceRow>& rows,const std::map<int,InstanceProfile>& profiles){
 InstanceBuffers output;std::map<std::tuple<int,int,int>,size_t> groups;
 for(const auto& row:rows){
  bool soldier=row.kind==0||row.kind==1||row.kind==3;
  auto profile=profiles.find(row.kind);
  if(!soldier&&profile==profiles.end())continue;
  if((row.status&64)&&row.kind!=8)continue;
  if(soldier&&row.pose_row<0){output.valid=false;return output;}
  auto key=std::make_tuple(row.kind,int(std::floor(row.position.x/32)),int(std::floor(row.position.z/32)));
  auto [found,inserted]=groups.emplace(key,output.batches.size());
  if(inserted){InstanceBatch batch;batch.kind=std::get<0>(key);batch.x=std::get<1>(key);batch.z=std::get<2>(key);output.batches.push_back(std::move(batch));}
  auto& batch=output.batches[found->second];batch.low=std::min(batch.low,row.position.y);batch.high=std::max(batch.high,row.position.y);
  auto color=soldier?std::array<float,4>{float(row.pose_row),row.status&1?1.0f:0.0f,0,0}:pose(row,profile->second);
  append(batch.buffer,row.position,row.yaw,color);++output.submitted;
  if(row.team==1)append(output.health,row.position+Vec3{0,3,0},0,{float(std::clamp(row.hp/row.max_hp,0.0,1.0)),1,0,0});
 }
 return output;
}
}
