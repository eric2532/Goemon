#pragma once
#include "core.h"
#include <cassert>
using namespace army;
static KitData kits(){
 KitData d;d.soldier_kinds={HOUND_KIND};d.soldier_profiles={3000,4.5f,60,3.4f,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.hound_attacks[i]=30;d.hound_attacks[i+1]=2;d.hound_attacks[i+2]=10;d.hound_attacks[i+3]=131;d.hound_attacks[i+4]=20;d.hound_attacks[i+5]=132;}
 return d;
}
static Handle setup(Crowd& c,int skin=0){
 c.configure(256,256);c.set_navigation({});assert(c.combat.configure(kits()));
 ExternalTarget hero;hero.id=7;hero.hp=10000;c.combat.set_targets({hero});
 auto h=c.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);c.unit(h)->pose_row=skin;c.set_guard(h,{0,0,0},18);
 c.spawn(1,0,12,{0,0,-2},100000,.5);return h;
}
