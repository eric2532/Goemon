#include "core.h"
#include <cassert>
#include <iostream>
#include <set>
#include "pet_skills_fixture.h"
namespace army {
struct PetSkillSelectionTest {
    static void run(){
        int checks=0;
        auto foe=[](Crowd& c){return c.query({-1,-1,-3},{1,3,-1},0)[0];};
        auto begin=[](Crowd& c,Handle h){
            auto& u=*c.unit(h);auto* enemy=c.unit(u.target_handle);
            int slots=c.combat.pet_ranged_slots(u);
            if(!enemy||!c.combat.pet_ranged_contact(c,u,*enemy))slots=0;
            return c.combat.pet_begin(c,u,slots);
        };
        for(int hz:{20,30,60})for(int skin:{0,21,41,61,82}){
            Crowd c;auto h=setup(c,skin);auto target=foe(c);auto* u=c.unit(h);
            auto d=kits();d.pet_mana=50;d.pet_skill_costs.assign(PET_SKILL_COUNT,8);
            assert(c.combat.configure(d)&&c.set_pet_skills(h,{1,9,3}));
            assert(c.set_pet_mana(h,50));
            c.unit(target)->hp=60;
            for(int frame=0;frame<hz/2;++frame)c.step(1.0/hz);
            for(const auto& event:c.combat.events())assert(event.kind!=PET_SKILL_STARTED);
            assert(!c.unit(target)&&u->pet_mana==50&&u->pet_skill_bag==0);
            checks+=2;
        }
        {
            Crowd c;auto h=setup(c);auto target=foe(c);auto* u=c.unit(h);
            auto d=kits();d.hound_hp=3000;d.hound_damage=60;
            assert(c.combat.configure(d)&&c.set_pet_skills(h,{1,9,3}));
            assert(c.set_pet_growth(h,0,40));u->target_handle=target;c.unit(target)->hp=100;
            assert(begin(c,h)&&u->pet_skill==0);++checks;
            c.unit(target)->blocking=true;u->action_active=false;
            assert(begin(c,h)&&u->pet_skill!=0);++checks;
        }
        {
            Crowd c;auto h=setup(c);auto target=foe(c);auto* u=c.unit(h);
            assert(c.set_pet_skills(h,{1,9,3})&&c.set_pet_skill_groups(h,2));u->target_handle=target;
            auto extra=c.spawn(2,0,12,{8,0,-3},100000,.5);
            auto queries=c.query_calls[0],sorted=c.query_sorted_items[0];
            assert(begin(c,h)&&u->pet_skill==9&&u->target_handle==target);
            assert(c.query_calls[0]==queries+1&&c.query_sorted_items[0]==sorted);checks+=2;
            // A level-one elemental spell has only one eligible victim, so it gets no group preference.
            assert(c.set_pet_skill_groups(h,0));u->pet_skill_bag=0;
            std::set<int> choices;
            for(int i=0;i<3;++i){u->pet_skill=0;u->pet_cooldowns.fill(0);assert(begin(c,h));choices.insert(u->pet_skill);}
            assert(choices==std::set<int>({1,3,9}));++checks;
            // A second target behind cover, outside range or inside shelter cannot improve an area cast.
            assert(c.set_pet_skill_groups(h,2));
            NavigationData nav;nav.origin={-30,0,-30};nav.width=21;nav.spacing=3;
            nav.heights.assign(441,0);nav.covered.assign(441,1);
            nav.ray_min={{-8,-1,-7}};nav.ray_max={{8,8,-6}};
            for(int situation=0;situation<3;++situation){
                c.set_navigation(situation==0?nav:NavigationData{});
                c.set_pose(extra,situation==0?Vec3{0,0,-12}:situation==1?Vec3{20,0,0}:Vec3{8,0,-3},0);
                c.unit(extra)->shelter_mode=situation==2?2:0;
                u->pet_skill=0;u->pet_cooldowns.fill(0);u->pet_skill_bag=0;
                assert(begin(c,h));auto remaining=u->pet_skill_bag;
                assert(remaining&&(remaining&(remaining-1)));++checks;
            }
            c.set_navigation({});c.unit(extra)->shelter_mode=0;c.set_pose(extra,{8,0,-3},0);
            // Cooldown, mana, silence and prepared readiness still gate the preferred area skill.
            for(int gate=0;gate<4;++gate){
                auto d=kits();d.pet_mana=50;d.pet_skill_costs.assign(PET_SKILL_COUNT,0);d.pet_skill_costs[8]=8;
                assert(c.combat.configure(d));u->pet_mana=gate==1?0:50;
                u->pet_skill=0;u->pet_cooldowns.fill(0);u->pet_skill_bag=0;
                u->pet_cooldowns[8]=gate==0?1:0;u->afflictions[5]=gate==2?1:0;u->pet_ready_mask=gate==3?5:7;
                assert(begin(c,h)&&u->pet_skill!=9);++checks;
            }
        }
        {
            Crowd c;auto h=setup(c);auto target=foe(c);auto* u=c.unit(h);
            assert(c.set_pet_skills(h,{PET_BEE_FLURRY,3,9}));u->target_handle=target;
            c.set_pose(target,{0,0,-6},0);c.unit(target)->hp=1;
            assert(c.combat.pet_flurry_ready(c,*u));++checks;
            for(int i=0;i<8;++i){u->pet_skill=0;u->pet_cooldowns.fill(0);assert(begin(c,h));assert(u->pet_skill==3||u->pet_skill==9);++checks;}
            // With no legal shot, Hold still cannot blink or move to manufacture melee contact.
            u->hound_order=HOUND_HOLD;u->pet_skill=0;u->pet_cooldowns.fill(0);
            c.set_pose(target,{0,0,-17},0);assert(!begin(c,h));++checks;
        }
        {
            Crowd c;auto h=setup(c);auto target=foe(c);auto* u=c.unit(h);
            c.step(1.0/60);u->action_active=false;
            assert(c.set_pet_skills(h,{2,9,3})&&c.set_pet_skill_groups(h,2));
            u->target_handle=target;u->pet_skill_bag=uint64_t(1)<<2;
            assert(begin(c,h)&&u->pet_skill==2);auto serial=u->pet_cast_serial;
            auto mana=u->pet_mana;auto cooldowns=u->pet_cooldowns;
            c.unit(target)->hp=1;c.spawn(2,0,12,{8,0,-3},100000,.5);
            u->action_active=false;auto queries=c.query_calls[0];
            assert(begin(c,h)&&u->pet_skill==2&&u->pet_cast_serial==serial);
            assert(u->pet_mana==mana&&u->pet_cooldowns==cooldowns&&c.query_calls[0]==queries);checks+=2;
        }
        {
            Crowd c;auto h=setup(c);auto* u=c.unit(h);auto target=foe(c);u->target_handle=target;
            assert(c.set_pet_skills(h,{1,9,3})&&c.set_pet_skill_groups(h,2));
            assert(!c.set_pet_skill_groups(h,-1)&&!c.set_pet_skill_groups(h,8)&&!c.set_pet_skill_groups(target,1));++checks;
            assert(begin(c,h));auto bag=u->pet_skill_bag;
            c.rest_allies();assert(u->pet_group_mask==2&&u->pet_skill_bag==bag);++checks;
            assert(c.set_pet_skills(h,{3,9,1})&&u->pet_group_mask==0&&u->pet_skill_bag==0);++checks;
            assert(c.set_pet_skill_groups(h,2));c.despawn(h);
            auto reused=c.spawn(-1,1,HOUND_KIND,{0,0,0},3000,.5);
            assert(reused!=h&&c.unit(reused)->pet_group_mask==0&&c.unit(reused)->pet_skill_bag==0);++checks;
        }
        std::cout<<"PET_SKILL_SELECTION_RESULT checks="<<checks<<" failures=0\n";
    }
};
}
int main(){army::PetSkillSelectionTest::run();}
