#include "core.h"
#include <cassert>
#include <iostream>
#include <map>
using namespace army;
static KitData kits(){
    KitData d;d.soldier_kinds={HOUND_KIND};d.soldier_profiles={3000,4.5f,60,3.4f,8,2.7f};
    d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
    d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};
    d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};
    d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
    d.hound_hp=150;d.hound_damage=d.pet_mana=50;d.pet_mana_regen=1;
    d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
    for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){
        d.hound_attacks[i]=30;d.hound_attacks[i+1]=2;
        d.hound_attacks[i+2]=10;d.hound_attacks[i+3]=131;
        d.hound_attacks[i+4]=20;d.hound_attacks[i+5]=131;
    }
    return d;
}
int main(){
    int checks=0;
    for(int hz:{20,30,60}){
        Crowd c;c.configure(128,128);c.set_navigation({});assert(c.combat.configure(kits()));
        ExternalTarget hero;hero.id=0;hero.hp=10000;hero.pet_formation_facing={0,0,-1};
        hero.pet_formation_ids={-1,-2,-3,-4,-5};
        std::vector<Handle> pets;
        for(int i=0;i<5;++i){auto h=c.spawn(-i-1,1,HOUND_KIND,{float(10+i*3),0,10},150,.5);c.set_guard(h,{},18);c.unit(h)->pose_row=i*20;pets.push_back(h);}
        float speed=0;int order=HOUND_COMBINED,serial=1;
        auto sync=[&]{c.combat.set_targets({hero},0,speed,order,serial);};
        auto steps=[&](int count){for(int i=0;i<count;++i)c.step(1.0/hz);};
        auto formation=[&]{
            for(int i=0;i<5;++i)if(c.valid(pets[i])){
                auto p=COMBINED_FORMATION_POSTS[i];Vec3 expected=hero.foot+Vec3{p.x,0,-p.z};
                assert(length(c.unit(pets[i])->position-expected)<.001f);++checks;
            }
        };
        sync();steps(1);formation();
        for(float velocity:{3.f,12.f,18.f}){
            speed=velocity;
            for(int i=0;i<hz;++i){hero.foot.x+=velocity/hz;sync();steps(1);formation();}
        }
        hero.foot={};speed=0;sync();steps(1);
        auto enemy=c.spawn(100,0,12,{0,0,-4},1000000,.5);
        double hp=c.unit(enemy)->hp;steps(hz);assert(c.unit(enemy)->hp==hp);++checks;
        hero.combined_player_attacking=true;sync();c.unit(pets[2])->pet_attack_multiplier=.5;
        assert(c.combat.begin_combined_power(c,enemy,.25));++checks;
        std::vector<Vec3> attacks;
        for(int i=0;i<5;++i){
            auto* u=c.unit(pets[i]);auto center=c.unit(enemy)->position;attacks.push_back(u->position);
            assert(u->action_active&&u->action_time==0&&u->phase_tick==0&&u->attack_serial==1);++checks;
            if(i==2)assert(u->position.z<center.z&&std::abs(u->position.x-center.x)<.01f);
            else assert(((i==0||i==3)?u->position.x<center.x:u->position.x>center.x)&&((i<2)==(u->position.z>center.z)));
            ++checks;
        }
        steps(hz);assert(c.unit(enemy)->hp==hp&&!c.combat.combined_power_ready(c));++checks;
        for(auto h:pets){assert(c.unit(h)->phase_tick<10&&c.unit(h)->action_active);++checks;}
        Hit player;player.amount=100;player.joint_attack=true;player.direction={0,0,-1};c.combat.hit(c,enemy,player);
        assert(c.combat.strike_combined_power(c)==5);++checks;
        std::map<int64_t,int> contacts;
        for(const auto& event:c.combat.events())if(event.kind==DAMAGE&&event.target_id==100&&event.source_id<0)++contacts[event.source_id];
        for(int id=-1;id>=-5;--id){assert(contacts[id]==2);++checks;}
        hp=c.unit(enemy)->hp;assert(c.combat.strike_combined_power(c)==0&&c.unit(enemy)->hp==hp);++checks;
        hero.combined_player_attacking=false;sync();steps(hz);
        assert(!c.combat.combined_power_ready(c)&&c.unit(pets[2])->action_active);++checks;
        for(int i:{0,1,3,4}){assert(!c.unit(pets[i])->action_active&&length(c.unit(pets[i])->position-attacks[i])<.001f);++checks;}
        // A queued group stroke replaces old recovery without waiting for the slow pet.
        c.set_pose(enemy,{0,0,-4},0);c.unit(enemy)->knockback={};
        assert(c.combat.begin_combined_power(c,enemy,.1));++checks;
        for(auto h:pets){assert(c.unit(h)->action_active&&c.unit(h)->phase_tick==0&&c.unit(h)->attack_serial==2);++checks;}
        steps(1);assert(c.unit(enemy)->hp==hp);++checks;
        assert(c.combat.strike_combined_power(c)==5);++checks;
        // Movement cancellation returns the whole group and removes every remaining damage callback.
        c.combat.end_combined_power(c);formation();hp=c.unit(enemy)->hp;steps(hz*3);
        assert(c.unit(enemy)->hp==hp&&c.combat.strike_combined_power(c)==0);++checks;
        // Standing still still permits a complete source recovery, including the slowest pet.
        c.set_pose(enemy,{0,0,-4},0);c.unit(enemy)->knockback={};
        assert(c.combat.begin_combined_power(c,enemy,.2));++checks;
        assert(c.combat.strike_combined_power(c)==5);++checks;
        steps(hz*2);assert(c.combat.combined_power_ready(c));++checks;
        c.combat.end_combined_power(c);formation();
        // Killed targets, empty swings and recycled members do not create delayed contacts.
        assert(c.combat.begin_combined_power(c,enemy,.2));++checks;
        Hit lethal;lethal.amount=10000000;c.combat.hit(c,enemy,lethal);
        assert(c.combat.strike_combined_power(c)==0);++checks;
        steps(hz*2);assert(c.combat.combined_power_ready(c));++checks;
        c.combat.end_combined_power(c);formation();
        assert(c.combat.begin_combined_power(c,0,.2));++checks;
        auto old=pets[0];c.despawn(old);auto replacement=c.spawn(-99,1,HOUND_KIND,{20,0,20},150,.5);
        assert(replacement!=old&&!c.unit(replacement)->action_active);++checks;
        assert(c.combat.strike_combined_power(c)==0);++checks;
        steps(hz*2);assert(c.combat.combined_power_ready(c));++checks;
        c.combat.end_combined_power(c);
        assert(c.combat.begin_combined_power(c,0,.2));++checks;
        c.clear();assert(c.combat.combined_power_ready(c)&&c.combat.strike_combined_power(c)==0);++checks;
    }
    std::cout<<"COMBINED_COMBO checks="<<checks<<" PASS\n";
}
