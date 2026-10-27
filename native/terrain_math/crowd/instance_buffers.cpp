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
 if(row.team==0)return {float(row.pose_row),row.status&1?1.0f:0.0f,0,row.flash};
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
  bool soldier=row.team==0&&row.kind!=4;
  auto profile=profiles.find(row.kind);
  if(!soldier&&profile==profiles.end())continue;
  if((row.status&64)&&row.kind!=8)continue;
  if(soldier&&row.pose_row<0){output.valid=false;return output;}
  auto key=std::make_tuple(row.kind,int(std::floor(row.position.x/INSTANCE_CELL)),int(std::floor(row.position.z/INSTANCE_CELL)));
  auto [found,inserted]=groups.emplace(key,output.batches.size());
  if(inserted){InstanceBatch batch;batch.kind=std::get<0>(key);batch.x=std::get<1>(key);batch.z=std::get<2>(key);output.batches.push_back(std::move(batch));}
  auto& batch=output.batches[found->second];
  batch.low={std::min(batch.low.x,row.position.x),std::min(batch.low.y,row.position.y),std::min(batch.low.z,row.position.z)};
  batch.high={std::max(batch.high.x,row.position.x),std::max(batch.high.y,row.position.y),std::max(batch.high.z,row.position.z)};
  auto color=soldier?std::array<float,4>{float(row.pose_row),row.status&1?1.0f:0.0f,0,row.flash}:pose(row,profile->second);
  if(row.team==0&&row.kind==18&&row.action>=300&&row.action<306){
   color[2]=float(row.action-299);if(row.action==300&&row.render_time*30>=40&&row.render_time*30<180)color[2]=7+.1f*std::clamp(float(std::min((row.render_time*30-40)/16,(180-row.render_time*30)/16)),0.f,1.f);
   if(row.action==305&&((row.render_time*30>=19&&row.render_time*30<51)||(row.render_time*30>=91&&row.render_time*30<251)))continue;
  }
  append(batch.buffer,row.position,row.yaw,color);++output.submitted;
  if(row.team==1)append(output.health,row.position+Vec3{0,3,0},0,{float(std::clamp(row.hp/row.max_hp,0.0,1.0)),1,0,0});
 }
 return output;
}
}
