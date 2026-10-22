#include "kits.h"
#include <algorithm>
namespace army {
bool valid_kit_data(const KitData& d){
    if(d.soldier_profiles.size()!=d.soldier_kinds.size()*6||d.actions.size()!=17||d.status_bits.size()!=7||d.phase_ticks.size()!=5||d.contact_ticks.size()!=4)return false;
    if(!d.soldier_pose_meta.empty()&&d.soldier_pose_meta.size()!=d.soldier_kinds.size()*16)return false;
    for(size_t i=0;i<d.soldier_pose_meta.size();i+=2)if(d.soldier_pose_meta[i]<0||d.soldier_pose_meta[i+1]<=0||size_t(d.soldier_pose_meta[i])+size_t(d.soldier_pose_meta[i+1])>d.soldier_pose_rows.size())return false;
    for(auto row:d.soldier_pose_rows)if(row<0)return false;
    if(d.ally_profiles.size()!=d.ally_kinds.size()*5||d.ally_primaries.size()!=d.ally_kinds.size()*42)return false;
    if(!d.walk_cadence.empty()&&d.walk_cadence.size()!=d.ally_kinds.size()*161)return false;
    for(auto v:d.walk_cadence)if(!std::isfinite(v)||v<0)return false;
    for(auto k:d.ally_kinds)if(k!=11&&k!=5&&k!=7&&k!=8&&k!=10)return false;
    if(!d.bunker.empty()&&d.bunker.size()!=5)return false;
    for(auto v:d.bunker)if(!std::isfinite(v)||v<=0)return false;
    bool ninja_enabled=std::find(d.ally_kinds.begin(),d.ally_kinds.end(),5)!=d.ally_kinds.end();
    if((ninja_enabled||!d.ninja.empty())&&d.ninja.size()!=12)return false;
    if(!d.ninja.empty()&&(d.ninja[0]<=0||d.ninja[1]<=0||d.ninja[10]<=0||d.ninja[11]>1))return false;
    for(auto v:d.ninja)if(!std::isfinite(v)||v<0)return false;
    bool dragoon_enabled=std::find(d.ally_kinds.begin(),d.ally_kinds.end(),8)!=d.ally_kinds.end();
    if((dragoon_enabled||!d.dragoon.empty())&&d.dragoon.size()!=D_COUNT)return false;
    for(auto v:d.dragoon)if(!std::isfinite(v)||v<=0)return false;
    if(!d.dragoon.empty()&&(d.dragoon[D_HEIGHT]<2*d.dragoon[D_RADIUS]||d.dragoon[D_SWEEP_CONTACT]+2*d.dragoon[D_SWEEP_INTERVAL]>d.dragoon[D_SWEEP_TIME]))return false;
    bool ranger_enabled=std::find(d.ally_kinds.begin(),d.ally_kinds.end(),10)!=d.ally_kinds.end();
    if((ranger_enabled||!d.ranger.empty())&&(d.ranger.size()!=R_COUNT||d.ranger_muzzles.size()!=6*33))return false;
    for(auto v:d.ranger)if(!std::isfinite(v)||v<0)return false;
    for(auto v:d.ranger_muzzles)if(!finite(v))return false;
    if(!d.ranger_motion_muzzles.empty()&&d.ranger_motion_muzzles.size()!=2*6*33)return false;
    for(auto v:d.ranger_motion_muzzles)if(!finite(v))return false;
    bool knight_enabled=std::find(d.ally_kinds.begin(),d.ally_kinds.end(),7)!=d.ally_kinds.end();
    if((knight_enabled||!d.knight.empty())&&d.knight.size()!=K_COUNT)return false;
    for(auto v:d.knight)if(!std::isfinite(v)||v<=0)return false;
    if(!d.ranger.empty()&&(d.ranger[R_RANGE]<=0||d.ranger[R_GROWTH]<=0||d.ranger[R_PRIMARY_SPEED]<=0||d.ranger[R_FAN_SPEED]<=0||d.ranger[R_RANGE_METRES]<=0||d.ranger[R_CURVED]>1))return false;
    for(auto v:d.ally_profiles)if(!std::isfinite(v)||v<0)return false;
    for(auto v:d.ally_primaries)if(!std::isfinite(v))return false;
    for(size_t i=0;i<d.ally_primaries.size();i+=7)if(d.ally_primaries[i]<=0||d.ally_primaries[i+1]<0||d.ally_primaries[i+1]>d.ally_primaries[i]||d.ally_primaries[i+2]<0||d.ally_primaries[i+3]<=0)return false;
    for(auto value:d.soldier_profiles)if(!std::isfinite(value)||value<0)return false;
    for(auto value:d.phase_ticks)if(!std::isfinite(value)||value<=0)return false;
    for(auto value:d.contact_ticks)if(!std::isfinite(value)||value<=0)return false;
    for(float v:{d.bullet_speed,d.bullet_life,d.bullet_tail,d.bullet_radius,d.damage_taken_multiplier})if(!std::isfinite(v)||v<0)return false;
    for(auto kind:d.soldier_kinds)if(kind!=0&&kind!=1&&kind!=3)return false;
    return finite(d.melee_from)&&finite(d.melee_to)&&finite(d.muzzle)&&d.bullet_speed>0&&d.bullet_life>0&&d.bullet_radius>0&&d.damage_taken_multiplier>=0;
}
}
