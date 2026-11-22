#include "core.h"
#include <cassert>
#include <iostream>
#include <limits>
using namespace army;

static KitData kits(){
    KitData d;d.soldier_kinds={SLIME_KIND};d.soldier_profiles={200000,3,12,3.25f,5,1.75f};
    d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
    d.phase_ticks={36,10,36,30,30};d.contact_ticks={18,18,18,18};
    d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
    d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
    d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
    for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=36;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=18;d.slime_attacks[i+3]=135;}
    return d;
}
static void steps(Crowd& c,int count){for(int i=0;i<count;++i)c.step(1.0/60);}
static void patrol_counters(){
 for(int hz:{20,30,60}){
    Crowd c;c.configure(16,16);c.set_navigation({});assert(c.combat.configure(kits()));
    auto h=c.spawn(10,0,SLIME_KIND,{0,0,0},200000,.5f);
    assert(!c.set_patrol_counter(0));
    auto ally=c.spawn(-1,1,HOUND_KIND,{15,0,15},1000,.5f);c.set_guard(ally,{15,0,15},14);
    assert(!c.set_patrol_counter(ally));c.despawn(ally);
    assert(!c.set_patrol_counter(h));c.set_guard(h,{0,0,0},14);assert(c.set_patrol_counter(h));
    auto u=c.unit(h);assert(u->dodge_chance==0&&u->counter_chance==.2);
    Hit hit;hit.amount=1;hit.direction={0,0,1};
    for(int bag=0;bag<20;++bag){
        int successes=0;
        for(int draw=0;draw<5;++draw){
            u->counter_pending=false;u->stun=0;
            const auto hp=u->hp;assert(c.combat.hit(c,h,hit).hp==hp-1&&u->dodge_left==0);
            successes+=u->counter_pending;
        }
        assert(successes==1);
    }
    for(int response=0;response<4;++response){
        u->action_active=u->counter_active=u->counter_pending=false;
        u->stun=u->frozen=u->patrol_counter_cooldown=0;u->position={0,0,0};u->knockback={};
        ExternalTarget hero;hero.kind=0;hero.hp=100000;hero.foot={0,0,-1.6f};c.combat.set_targets({hero});
        for(int i=0;i<10&&!u->counter_pending;++i)c.combat.hit(c,h,hit);
        bool started=false,warned=false;int contacts=0;
        c.combat.clear_events();
        for(int tick=0;tick<hz*2;++tick){
            c.step(1.0/hz);
            if(u->counter_active&&!started){
                started=true;assert(u->patrol_counter_cooldown>2.9);
                const auto bag=u->patrol_counter_bag;
                for(int i=0;i<5;++i)c.combat.hit(c,h,hit);
                assert(!u->counter_pending&&u->patrol_counter_bag==bag);
                if(response==1){hero.foot={12,0,-1.6f};c.combat.set_targets({hero});}
                if(response==2){Hit freeze;freeze.effect=1;freeze.status_seconds=3;c.combat.hit(c,h,freeze);}
                if(response==3){Hit stun;stun.effect=4;stun.status_seconds=3;c.combat.hit(c,h,stun);}
            }
            warned|=c.combat.hero_dodge_threat().seconds>0;
            for(const auto& event:c.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.action_index==718){++contacts;assert(event.amount==12);}
            c.combat.clear_events();
        }
        std::cout<<"PATROL_COUNTER hz="<<hz<<" response="<<response<<" started="<<started<<" contacts="<<contacts<<std::endl;
        assert(started&&contacts==(response==0?1:0));
        if(response==0)assert(warned);
        u->counter_pending=false;Hit counter=hit;counter.counter=true;
        c.combat.hit(c,h,counter);assert(!u->counter_pending);
    }
    c.despawn(h);auto reused=c.spawn(11,0,SLIME_KIND,{0,0,0},100,.5f);
    assert(!c.valid(h)&&!c.unit(reused)->patrol_counter&&c.unit(reused)->patrol_counter_bag==0&&c.unit(reused)->patrol_counter_cooldown==0);
 }
 std::cout<<"PATROL_COUNTER_RESULT shuffle_bags=60 dodge=0 contact_escape_freeze_stun_reuse=passed\n";
}
int main(){
    patrol_counters();
    Crowd c;c.configure(8,8);c.set_navigation(NavigationData{});assert(c.combat.configure(kits()));
    auto boss=c.spawn(1,0,SLIME_KIND,{0,0,0},200000,1);
    auto regular=c.spawn(2,0,SLIME_KIND,{10,0,0},200000,1);
    auto ally=c.spawn(3,1,SLIME_KIND,{0,0,-2},200000,1);
    assert(!c.set_boss_reactions(ally,.05,.75));
    assert(!c.set_boss_reactions(boss,-1,.75)&&!c.set_boss_reactions(boss,.05,2));
    assert(!c.set_boss_reactions(boss,std::numeric_limits<double>::quiet_NaN(),.75));
    Hit hit;hit.amount=.01;hit.direction={0,0,1};
    for(int i=0;i<10000;++i){auto result=c.combat.hit(c,regular,hit);assert(result.accepted);assert(!c.unit(regular)->counter_pending&&c.unit(regular)->dodge_left==0);}
    assert(c.set_boss_reactions(boss,.05,0));int dodges=0;
    for(int i=0;i<10000;++i){
        auto u=c.unit(boss);u->stun=0;u->action_active=false;u->dodge_left=u->dodge_cooldown=0;
        if(!c.combat.hit(c,boss,hit).accepted)++dodges;
    }
    assert(dodges>400&&dodges<600);
    c.despawn(ally);
    assert(c.set_boss_reactions(boss,1,0));auto u=c.unit(boss);u->stun=0;u->dodge_left=u->dodge_cooldown=0;u->knockback={};u->velocity={};u->has_goal=false;
    auto home=u->position;auto hp=u->hp;assert(!c.combat.hit(c,boss,hit).accepted);
    assert(u->hp==hp&&u->dodge_left>0&&length(u->dodge_offset())==0);
    steps(c,13);assert(u->position.x==home.x&&u->position.z==home.z&&length(u->dodge_offset())>.79f);
    steps(c,27);assert(length(u->dodge_offset())<1e-5f);
    assert(c.combat.hit(c,boss,hit).accepted); // Cooldown leaves the boss punishable.
    u->stun=0;u->dodge_cooldown=0;u->action_active=true;
    assert(c.combat.hit(c,boss,hit).accepted&&u->dodge_left==0); // Committed attacks cannot dodge.
    assert(c.set_boss_reactions(boss,0,.75));int counters=0;
    for(int i=0;i<10000;++i){u->counter_pending=false;assert(c.combat.hit(c,boss,hit).accepted);if(u->counter_pending)++counters;}
    assert(counters>7300&&counters<7700);
    assert(c.set_boss_reactions(boss,0,1));u->counter_pending=false;hit.counter=true;
    c.combat.hit(c,boss,hit);assert(!u->counter_pending);hit.counter=false;
    c.despawn(ally);c.combat.set_targets({ExternalTarget{0,0,{0,0,-1.6f},100000,true}});
    u->action_active=false;u->counter_active=false;u->stun=0;u->frozen=0;u->position={0,0,0};
    assert(c.combat.hit(c,boss,hit).accepted&&u->counter_pending);
    c.combat.clear_events();steps(c,120);int contacts=0;
    for(const auto& event:c.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.action_index==718){++contacts;assert(event.amount==12&&event.target_id==0);}
    assert(contacts==1&&!u->counter_pending&&!u->counter_active);
    u->counter_active=u->action_active=true;u->counter_pending=false;u->stun=0;u->action_time=.1;
    Hit reply=hit;reply.counter=true;
    assert(c.combat.hit(c,boss,reply).accepted&&u->counter_active&&u->action_time==.1&&!u->counter_pending);
    Hit control;control.effect=4;control.status_seconds=.5;
    c.combat.hit(c,boss,control);assert(!u->counter_active&&!u->action_active);
    u->counter_pending=false;hit.amount=1000000;assert(c.combat.hit(c,boss,hit).dead);
    auto replacement=c.spawn(4,0,SLIME_KIND,{0,0,0},100,1);
    assert(c.unit(replacement)->dodge_chance==0&&c.unit(replacement)->counter_chance==0&&!c.unit(replacement)->counter_pending);
    std::cout<<"BOSS_REACTIONS_RESULT regular_hits=10000 dodge_trials=10000 dodges="<<dodges<<" counter_trials=10000 counters="<<counters<<" failures=0\n";
}
