#include "kits.h"
#include <algorithm>
namespace army {
bool valid_kit_data(const KitData& d){
    if(d.cursed_guardian<0||d.cursed_guardian>6)return false;
    if(!d.snow_patrol_skins.empty()&&(d.snow_patrol_skins.size()!=2||d.snow_patrol_skins[0]==d.snow_patrol_skins[1]||
        std::any_of(d.snow_patrol_skins.begin(),d.snow_patrol_skins.end(),[](int skin){return skin<0||skin>=HOUND_SKINS;})||
        std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),HOUND_KIND)==d.soldier_kinds.end()))return false;
    if(!d.pet_geometry.empty()){
        if(d.pet_geometry.size()!=(HOUND_SKINS+SLIME_SKINS+5)*7)return false;
        for(float v:d.pet_geometry)if(!std::isfinite(v))return false;
        for(size_t i=0;i<d.pet_geometry.size();i+=7){
            for(int axis=0;axis<3;++axis)if(d.pet_geometry[i+axis]>=d.pet_geometry[i+3+axis])return false;
            if(d.pet_geometry[i+6]<=0||d.pet_geometry[i+6]>4)return false;
        }
    }
    if(!std::isfinite(d.map_enemy_scale)||d.map_enemy_scale<=0)return false;
    if(!std::isfinite(d.enemy_size)||d.enemy_size<.25f||d.enemy_size>3*d.map_enemy_scale+.0001f)return false;
    if(!std::isfinite(d.hound_move_scale)||d.hound_move_scale<=0)return false;
    for(float value:{d.hound_hp,d.hound_damage,d.bear_damage,d.pet_mana,d.pet_mana_regen})if(!std::isfinite(value)||value<0)return false;
    if(!d.pet_skill_costs.empty()&&d.pet_skill_costs.size()!=PET_SKILL_COUNT)return false;
    if(!std::isfinite(d.pet_ranged_reach)||d.pet_ranged_reach<=0)return false;
    for(float cost:d.pet_skill_costs)if(!std::isfinite(cost)||cost<0||cost>1000000)return false;
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
            if(k[25]!=-1&&(k[25]<0||k[25]>=ENEMY_KIND_COUNT||pet_skin_count(int(k[25]))!=0||k[25]!=int(k[25])||std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),int(k[25]))==d.soldier_kinds.end()||k[25]==d.soldier_kinds[i/26]))return false;
        }
    }
    for(int kind:{HOUND_KIND,SLIME_KIND,BEAR_KIND}){
      const auto& attacks=kind==HOUND_KIND?d.hound_attacks:kind==BEAR_KIND?d.bear_attacks:d.slime_attacks;
      const bool enabled=std::find(d.soldier_kinds.begin(),d.soldier_kinds.end(),kind)!=d.soldier_kinds.end();
      if(attacks.size()!=(enabled?pet_skin_count(kind)*8*HOUND_TIMELINE_STRIDE:0))return false;
      for(size_t row=0;row<attacks.size();row+=HOUND_TIMELINE_STRIDE){
        const auto* attack=attacks.data()+row;
        if(!std::isfinite(attack[0])||attack[0]<=0||!std::isfinite(attack[1])||attack[1]<1||attack[1]>(HOUND_TIMELINE_STRIDE-2)/2||attack[1]!=int(attack[1]))return false;
        float previous=-1;
        for(int i=0;i<int(attack[1]);++i){
            float tick=attack[2+i*2],cue=attack[3+i*2];
            if(!std::isfinite(cue)||cue<0||cue>=30000||cue!=std::floor(cue))return false;
            int code=int(cue),sound=code%10000;
            bool tagged=(code/10000==1||code/10000==2)&&
                (sound==0||sound==162||sound==173||sound==282||sound==288||sound==290||sound==301||sound==316||sound==318||sound==319||sound==321||sound==332||sound==114||sound==116||sound==159||sound==164||sound==165||sound==171||sound==175||sound==182||sound==190||sound==214||sound==254||sound==255||sound==296||sound==314||sound==429||sound==101||sound==102||sound==103||sound==104||sound==105||sound==106||sound==107||sound==108||sound==109||sound==110||sound==112||sound==115||sound==117||sound==131||sound==132||sound==133||sound==134||sound==135||sound==136||sound==137||sound==138||sound==139||sound==140||sound==152||sound==153||sound==157||sound==166||sound==168||sound==172||sound==174||sound==176||sound==180||sound==181||sound==183||sound==184||sound==185||sound==186||sound==187||sound==191||sound==192||sound==262||sound==263||sound==264||sound==265||sound==266||sound==267||sound==268||sound==269||sound==303||sound==304||sound==463||sound==207);
            bool known=tagged||(kind!=HOUND_KIND?(cue==106||cue==112||cue==131||cue==135||cue==138||cue==157||cue==164||cue==165):
                (cue==117||cue==143||cue==161||cue==103||cue==105||cue==107||cue==110||cue==138||cue==191||cue==133||cue==135||cue==137||cue==101||cue==131||cue==132||cue==176||cue==264||cue==267||cue==288||cue==289||cue==290));
            if(!std::isfinite(tick)||tick<0||tick>=attack[0]||tick<=previous||!std::isfinite(cue)||cue!=code||!known)return false;
            previous=tick;
        }
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
    for(auto kind:d.soldier_kinds)if(kind<0||kind>=ENEMY_KIND_COUNT||kind==4)return false;
    return finite(d.melee_from)&&finite(d.melee_to)&&finite(d.muzzle)&&d.bullet_speed>0&&d.bullet_life>0&&d.bullet_radius>0&&d.damage_taken_multiplier>=0;
}
}
