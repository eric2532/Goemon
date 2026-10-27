#include "kits.h"
#include <algorithm>
namespace army {
bool valid_kit_data(const KitData& d){
    if(!std::isfinite(d.enemy_size)||d.enemy_size<.25f||d.enemy_size>3)return false;
    if(d.soldier_profiles.size()!=d.soldier_kinds.size()*6||d.actions.size()!=17||d.status_bits.size()!=7||d.phase_ticks.size()!=5||d.contact_ticks.size()!=4)return false;
    if(!d.enemy_kits.empty()){
        if(d.enemy_kits.size()!=d.soldier_kinds.size()*26)return false;
        for(auto v:d.enemy_kits)if(!std::isfinite(v))return false;
        for(size_t i=0;i<d.enemy_kits.size();i+=26){
            const float* k=d.enemy_kits.data()+i;
            for(int p=0;p<5;++p)if(k[p]<=0)return false;
            for(int p=5;p<9;++p)if(k[p]<=0)return false;
            if(k[15]<=0||k[16]<0||(k[17]!=0&&k[17]!=3)||(k[18]!=0&&k[18]!=1))return false;
            if(k[5]>k[0]||k[6]>k[2]||k[7]>k[3]||k[8]>k[3])return false;
            for(int axis=0;axis<3;++axis)if(k[19+axis]>=k[22+axis])return false;
            if(k[25]!=-1&&(k[25]<0||k[25]>=19||k[25]!=int(k[25])||std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),int(k[25]))==d.soldier_kinds.end()||k[25]==d.soldier_kinds[i/26]))return false;
        }
    }
    if(!d.soldier_pose_meta.empty()&&d.soldier_pose_meta.size()!=d.soldier_kinds.size()*16)return false;
    if(!d.enemy_contact_ends.empty()){
        if(d.enemy_contact_ends.size()!=d.soldier_kinds.size()||d.enemy_kits.empty())return false;
        for(size_t i=0;i<d.enemy_contact_ends.size();++i){
            float end=d.enemy_contact_ends[i];
            if(!std::isfinite(end)||end<0||(end>0&&(end<=d.enemy_kits[i*26+5]||end>d.enemy_kits[i*26])))return false;
        }
    }
    for(size_t i=0;i<d.soldier_pose_meta.size();i+=2)if(d.soldier_pose_meta[i]<0||d.soldier_pose_meta[i+1]<=0||size_t(d.soldier_pose_meta[i])+size_t(d.soldier_pose_meta[i+1])>d.soldier_pose_rows.size())return false;
    for(auto row:d.soldier_pose_rows)if(row<0)return false;
    if(d.ally_profiles.size()!=d.ally_kinds.size()*5||d.ally_primaries.size()!=d.ally_kinds.size()*42)return false;
    if(!d.walk_cadence.empty()&&d.walk_cadence.size()!=d.ally_kinds.size()*161)return false;
    for(auto v:d.walk_cadence)if(!std::isfinite(v)||v<0)return false;
    for(auto k:d.ally_kinds)if(k!=11&&k!=5&&k!=7&&k!=8&&k!=10&&k!=31)return false;
    if(!d.finale_meta.empty()){
        if(!std::isfinite(d.finale_scale)||d.finale_scale<=0||d.finale_scale>10)return false;
        if(d.finale_meta.size()!=12||d.finale_frames.size()%5||d.finale_shots.size()!=24||d.finale_ranges.size()!=4)return false;
        for(auto v:d.finale_frames)if(!std::isfinite(v))return false;
        for(auto v:d.finale_shots)if(!std::isfinite(v)||v<0)return false;
        for(auto v:d.finale_ranges)if(!std::isfinite(v)||v<=0)return false;
        for(size_t i=0;i<12;i+=2)if(d.finale_meta[i]<0||d.finale_meta[i+1]<=0||(size_t(d.finale_meta[i])+d.finale_meta[i+1])*5>d.finale_frames.size())return false;
        for(size_t i=0;i<d.finale_frames.size();i+=5)if(d.finale_frames[i]<0||d.finale_frames[i+1]<0||d.finale_frames[i+1]>7||d.finale_frames[i+3]<0||d.finale_frames[i+3]>1)return false;
    }else if(!d.finale_frames.empty()||!d.finale_shots.empty()||!d.finale_ranges.empty())return false;
    bool lumina_enabled=std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),17)!=d.soldier_kinds.end();
    if((lumina_enabled||!d.dark_lumina.empty())&&d.dark_lumina.size()!=23)return false;
    if(lumina_enabled||!d.dark_lumina_spin.empty()){
        if(d.dark_lumina_spin.size()!=28*3)return false;
        for(size_t i=0;i<d.dark_lumina_spin.size();++i){auto v=d.dark_lumina_spin[i];if(!std::isfinite(v)||(i%3!=2&&(v<0||v>=2147483648.0f||v!=std::floor(v))))return false;}
    }
    if(!d.dark_lumina.empty()){
        for(auto v:d.dark_lumina)if(!std::isfinite(v))return false;
        for(int i=0;i<13;++i)if(d.dark_lumina[i]<=0)return false;
        for(int i=16;i<23;++i)if(d.dark_lumina[i]<=0)return false;
        if(d.dark_lumina[3]>64||d.dark_lumina[3]!=std::floor(d.dark_lumina[3]))return false;
        if(lumina_enabled){
            size_t row=std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),17)-d.soldier_kinds.begin();
            if(d.enemy_kits.empty())return false;const float* k=d.enemy_kits.data()+row*26;
            if(d.dark_lumina[0]>k[0]||d.dark_lumina[1]+(d.dark_lumina[3]-1)*d.dark_lumina[2]>k[3]||d.dark_lumina[5]>k[2]||d.dark_lumina[6]+30*d.dark_lumina[12]>k[4])return false;
        }
    }
    if(!d.skullpion.empty()&&d.skullpion.size()!=2)return false;
    for(auto v:d.skullpion)if(!std::isfinite(v)||v<=0)return false;
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
    bool blademaster_enabled=std::find(d.ally_kinds.begin(),d.ally_kinds.end(),31)!=d.ally_kinds.end();
    if(blademaster_enabled){
        if(d.blademaster.size()!=4)return false;
        for(auto value:d.blademaster)if(!std::isfinite(value)||value<=0)return false;
        if(d.blademaster[1]>d.blademaster[0])return false;
    }
    for(auto v:d.ally_primaries)if(!std::isfinite(v))return false;
    for(size_t i=0;i<d.ally_primaries.size();i+=7)if(d.ally_primaries[i]<=0||d.ally_primaries[i+1]<0||d.ally_primaries[i+1]>d.ally_primaries[i]||d.ally_primaries[i+2]<0||d.ally_primaries[i+3]<=0)return false;
    for(auto value:d.soldier_profiles)if(!std::isfinite(value)||value<0)return false;
    for(auto value:d.phase_ticks)if(!std::isfinite(value)||value<=0)return false;
    for(auto value:d.contact_ticks)if(!std::isfinite(value)||value<=0)return false;
    for(float v:{d.bullet_speed,d.bullet_life,d.bullet_tail,d.bullet_radius,d.damage_taken_multiplier})if(!std::isfinite(v)||v<0)return false;
    for(auto kind:d.soldier_kinds)if(kind<0||kind>=19||kind==4)return false;
    return finite(d.melee_from)&&finite(d.melee_to)&&finite(d.muzzle)&&d.bullet_speed>0&&d.bullet_life>0&&d.bullet_radius>0&&d.damage_taken_multiplier>=0;
}
}
