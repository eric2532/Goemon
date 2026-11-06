// Crowd C ABI bridge; the simulation owns no Godot scene objects.
#include "gdextension_interface.h"
#include "crowd/core.h"
#include "crowd/instance_buffers.h"
#include <algorithm>
#include <chrono>
#include <cassert>
#include <cstring>
#include <string>
#include <unordered_set>

namespace army_binding {
using VT=GDExtensionVariantType;
constexpr VT NIL=GDEXTENSION_VARIANT_TYPE_NIL, BOOL=GDEXTENSION_VARIANT_TYPE_BOOL,
 INT=GDEXTENSION_VARIANT_TYPE_INT,FLOAT=GDEXTENSION_VARIANT_TYPE_FLOAT,
 STR=GDEXTENSION_VARIANT_TYPE_STRING,VEC3=GDEXTENSION_VARIANT_TYPE_VECTOR3,
 AABB=GDEXTENSION_VARIANT_TYPE_AABB,DICT=GDEXTENSION_VARIANT_TYPE_DICTIONARY,ARRAY=GDEXTENSION_VARIANT_TYPE_ARRAY,
 BYTES=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,I32=GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,
 I64=GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,F32=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
 V3S=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,F64=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
struct alignas(8) Blob{unsigned char data[16];};
struct alignas(8) Variant{unsigned char data[24];};
struct Bounds{army::Vec3 position,size;};
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceVariantGetPtrConstructor constructor;
GDExtensionInterfaceVariantGetPtrDestructor destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin;
GDExtensionPtrOperatorEvaluator multiply_basis;
GDExtensionPtrBuiltInMethod scale_basis,normalize_vector;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantNewNil nil_new;
GDExtensionInterfaceVariantDestroy variant_destroy;
GDExtensionInterfaceClassdbConstructObject2 construct_object;
GDExtensionInterfaceObjectSetInstance set_instance;
GDExtensionInterfaceClassdbRegisterExtensionClass5 register_class;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceDictionaryOperatorIndex dictionary_index;
GDExtensionInterfaceDictionaryOperatorIndexConst dictionary_read;
GDExtensionInterfaceVariantGetType variant_type;
GDExtensionInterfaceVariantHasKey variant_has_key;
GDExtensionInterfaceVariantCall variant_call;
GDExtensionInterfaceVariantGetObjectInstanceId object_id;
GDExtensionInterfaceObjectGetInstanceFromId object_from_id;
GDExtensionInterfaceObjectCallScriptMethod script_call;
GDExtensionInterfaceObjectHasScriptMethod has_script_method;
GDExtensionInterfaceVariantGetNamed get_named;
GDExtensionInterfaceVariantSetNamed set_named;
GDExtensionInterfaceClassdbGetMethodBind get_bind;
GDExtensionInterfaceObjectMethodBindPtrcall engine_call;
GDExtensionInterfaceClassdbGetClassTag get_tag;
GDExtensionInterfaceObjectCastTo cast_object;
GDExtensionMethodBindPtr set_position_bind,set_global_bind,get_position_bind,get_global_bind,get_rotation_bind,set_rotation_bind,set_velocity_bind,queued_bind;
void* node3d_tag=nullptr;void* characterbody3d_tag=nullptr;
GDExtensionInterfacePackedByteArrayOperatorIndexConst byte_read;
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst float_read;
GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst double_read;
GDExtensionInterfacePackedInt32ArrayOperatorIndexConst int_read;
GDExtensionInterfacePackedInt64ArrayOperatorIndexConst long_read;
GDExtensionInterfacePackedVector3ArrayOperatorIndexConst vec_read;
GDExtensionInterfaceArrayOperatorIndex array_index;
GDExtensionInterfaceStringToUtf8Chars string_utf8;
GDExtensionInterfacePackedByteArrayOperatorIndex byte_write;
GDExtensionInterfacePackedInt32ArrayOperatorIndex int_write;
GDExtensionInterfacePackedInt64ArrayOperatorIndex long_write;
GDExtensionInterfacePackedFloat32ArrayOperatorIndex float_write;
GDExtensionInterfacePackedFloat64ArrayOperatorIndex double_write;
GDExtensionInterfacePackedVector3ArrayOperatorIndex vec_write;
Blob class_name,parent_name,sync_snapshot_name,sync_native_snapshot_name,sync_native_metadata_name,shared_snapshot_name,plain_snapshot_name,lazy_snapshot_name,event_health_name,hp_name,max_hp_name,velocity_name;
GDExtensionPtrBuiltInMethod resize_method[40]{};
GDExtensionPtrBuiltInMethod size_method[40]{};
Blob name(const char* text){Blob n;name_new(&n,text);return n;}
void release_name(Blob& n){destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&n);}
void put(void* dict,const char* key,VT type,const void* data){
    Blob text;string_new(&text,key);Variant k;from_type(STR)(&k,&text);
    auto slot=dictionary_index(dict,&k);variant_destroy(slot);from_type(type)(slot,const_cast<void*>(data));
    variant_destroy(&k);destructor(STR)(&text);
}
GDExtensionVariantPtr get(void* dict,const char* key){
    Blob text;string_new(&text,key);Variant k;from_type(STR)(&k,&text);
    Variant owner;from_type(DICT)(&owner,dict);GDExtensionBool valid=false;
    bool present=variant_has_key(&owner,&k,&valid);variant_destroy(&owner);
    auto result=present&&valid?dictionary_read(dict,&k):nullptr;
    variant_destroy(&k);destructor(STR)(&text);return result;
}
template<class T> T scalar(void* dict,const char* key,VT type,T fallback){
    auto value=get(dict,key);if(!value||variant_type(value)==NIL)return fallback;
    T result{};to_type(type)(&result,value);return result;
}
template<class T> std::vector<T> unpack(const void* packed,VT type){
    int64_t count=0;size_method[type](const_cast<void*>(packed),nullptr,&count,0);
    std::vector<T> result(count);if(!count)return result;const void* source=nullptr;
    switch(type){case BYTES:source=byte_read(packed,0);break;case F32:source=float_read(packed,0);break;case F64:source=double_read(packed,0);break;case I32:source=int_read(packed,0);break;case I64:source=long_read(packed,0);break;case V3S:source=vec_read(packed,0);break;default:break;}
    if(source)std::memcpy(result.data(),source,count*sizeof(T));return result;
}
template<class T> std::vector<T> vector(void* dict,const char* key,VT type){
    auto value=get(dict,key);if(!value||variant_type(value)!=type)return {};
    Blob packed;to_type(type)(&packed,value);auto result=unpack<T>(&packed,type);destructor(type)(&packed);return result;
}
// Retain the captured packed buffer; Godot copy-on-write protects it even when
// a synchronous facade callback replaces or edits the source dictionary.
template<class T> class PackedRead {
    Blob packed_;VT type_;const T* data_=nullptr;int64_t count_=0;
public:
    PackedRead(void* dict,const char* key,VT type):type_(type){
        auto value=get(dict,key);
        if(value&&variant_type(value)==type)to_type(type)(&packed_,value);
        else constructor(type,0)(&packed_,nullptr);
        size_method[type](&packed_,nullptr,&count_,0);
        if(count_)switch(type){case BYTES:data_=reinterpret_cast<const T*>(byte_read(&packed_,0));break;case F32:data_=reinterpret_cast<const T*>(float_read(&packed_,0));break;case F64:data_=reinterpret_cast<const T*>(double_read(&packed_,0));break;case I32:data_=reinterpret_cast<const T*>(int_read(&packed_,0));break;case I64:data_=reinterpret_cast<const T*>(long_read(&packed_,0));break;case V3S:data_=reinterpret_cast<const T*>(vec_read(&packed_,0));break;default:break;}
    }
    PackedRead(const PackedRead&)=delete;
    ~PackedRead(){destructor(type_)(&packed_);}
    size_t size()const{return count_;}
    const T& operator[](size_t i)const{return data_[i];}
    const T* begin()const{return data_;}
    const T* end()const{return count_?data_+count_:data_;}
};
bool equals(void* dict,const char* key,const char* expected){
    auto value=get(dict,key);if(!value||variant_type(value)!=STR)return false;
    Blob text;to_type(STR)(&text,value);char bytes[64]{};int64_t length=string_utf8(&text,bytes,63);destructor(STR)(&text);
    return length==int64_t(std::strlen(expected))&&length<64&&std::memcmp(bytes,expected,size_t(length))==0;
}
void put_int(void* dict,const char* key,int64_t value){put(dict,key,INT,&value);}
void put_bool(void* dict,const char* key,bool value){GDExtensionBool b=value;put(dict,key,BOOL,&b);}
void put_text(void* dict,const char* key,const char* value){Blob text;string_new(&text,value);put(dict,key,STR,&text);destructor(STR)(&text);}
void write_events(army::Combat& combat,void* result,bool compact=false){
    const auto& events=combat.events();int64_t count=events.size(),error=0;const void* args[]={&count};resize_method[ARRAY](result,args,&error,1);
    if(!count)return;
    // Intern each transfer key once per drain, rather than once per event field.
    // These own their engine values only inside this main-thread API call.
    enum Field{SERIAL,KIND,SOURCE,TARGET,TICKET,PROJECTILE_ID,POSITION,DIRECTION,HP,AMOUNT,SOURCE_TICK,PROJECTILE,HEAVY,CRITICAL,ACTION_INDEX,UNIT_KIND,TEAM,EXTERNAL_KIND,FIELDS};
    const char* texts[]={"serial","kind","source_id","target_id","ticket_id","projectile_id","position","direction","hp","amount","source_tick","projectile","heavy","critical","action_index","unit_kind","team","external_kind"};
    Variant keys[FIELDS];
    for(int i=0;i<FIELDS;++i){Blob text;string_new(&text,texts[i]);from_type(STR)(&keys[i],&text);destructor(STR)(&text);}
    const char* names[]={"melee","muzzle","bullet","done","damage","death","external_damage","projectile_impact","status","landing_pulse","shield_counter","attack_started"};
    Blob names_text[12];for(int i=0;i<12;++i)string_new(&names_text[i],names[i]);
    auto store=[&](void* dict,Field key,VT type,const void* value){auto slot=dictionary_index(dict,&keys[key]);variant_destroy(slot);from_type(type)(slot,const_cast<void*>(value));};
    auto integer=[&](void* dict,Field key,int64_t value){store(dict,key,INT,&value);};
    auto boolean=[&](void* dict,Field key,bool value){GDExtensionBool flag=value;store(dict,key,BOOL,&flag);};
    for(int64_t i=0;i<count;++i){
        const auto& event=events[i];Blob dict;constructor(DICT,0)(&dict,nullptr);
        integer(&dict,SERIAL,event.serial);store(&dict,KIND,STR,&names_text[event.kind]);
        bool gameplay=event.kind==army::DAMAGE||event.kind==army::DEATH||event.kind==army::EXTERNAL_DAMAGE||(event.kind==army::STATUS_EVENT&&event.unit_kind>=101&&event.action_index>=400);
        if(!compact||gameplay){
            integer(&dict,SOURCE,event.source_id);integer(&dict,TARGET,event.target_id);integer(&dict,TICKET,event.ticket_id);integer(&dict,PROJECTILE_ID,event.projectile_id);
            store(&dict,POSITION,VEC3,&event.position);store(&dict,DIRECTION,VEC3,&event.direction);store(&dict,HP,FLOAT,&event.hp);store(&dict,AMOUNT,FLOAT,&event.amount);store(&dict,SOURCE_TICK,FLOAT,&event.source_tick);
            boolean(&dict,PROJECTILE,event.projectile);boolean(&dict,HEAVY,event.heavy);if(event.kind==army::DAMAGE)boolean(&dict,CRITICAL,event.critical);integer(&dict,ACTION_INDEX,event.action_index);integer(&dict,UNIT_KIND,event.unit_kind);integer(&dict,TEAM,event.team);integer(&dict,EXTERNAL_KIND,event.external_kind);
        }else{
            if(event.kind==army::ATTACK_STARTED)integer(&dict,SOURCE,event.source_id);
            if(event.kind==army::MUZZLE||event.kind==army::BULLET||event.kind==army::PROJECTILE_IMPACT||event.kind==army::STATUS_EVENT||event.kind==army::LANDING_PULSE)store(&dict,POSITION,VEC3,&event.position);
            if(event.kind==army::BULLET){integer(&dict,TEAM,event.team);integer(&dict,UNIT_KIND,event.unit_kind);}
            if(event.kind==army::STATUS_EVENT||event.kind==army::LANDING_PULSE)integer(&dict,ACTION_INDEX,event.action_index);
            if((event.kind==army::STATUS_EVENT||event.kind==army::PROJECTILE_IMPACT)&&event.unit_kind==4){integer(&dict,SOURCE,event.source_id);integer(&dict,UNIT_KIND,4);store(&dict,AMOUNT,FLOAT,&event.amount);store(&dict,DIRECTION,VEC3,&event.direction);}
        }
        auto slot=array_index(result,i);variant_destroy(slot);from_type(DICT)(slot,&dict);destructor(DICT)(&dict);
    }
    for(auto& key:keys)variant_destroy(&key);for(auto& text:names_text)destructor(STR)(&text);
    combat.clear_events();
}
template<class T> void field(void* dict,const char* key,VT type,const std::vector<T>& values){
    Blob packed;constructor(type,0)(&packed,nullptr);
    int64_t count=values.size(),error=0;const void* args[]={&count};resize_method[type](&packed,args,&error,1);
    if(count){
        void* target=nullptr;
        switch(type){
            case BYTES:target=byte_write(&packed,0);break;
            case I32:target=int_write(&packed,0);break;
            case I64:target=long_write(&packed,0);break;
            case F32:target=float_write(&packed,0);break;case F64:target=double_write(&packed,0);break;
            case V3S:target=vec_write(&packed,0);break;
            default:break;
        }
        if(target)std::memcpy(target,values.data(),count*sizeof(T));
    }
    put(dict,key,type,&packed);destructor(type)(&packed);
}
// Fill each new snapshot buffer once. Published snapshots keep their own COW
// storage, so retaining an older Snapshot never observes a later simulation tick.
template<class T> class PackedField {
    Blob packed_;VT type_;T* data_=nullptr;int64_t count_=0,capacity_;
public:
    PackedField(VT type,int64_t capacity):type_(type),capacity_(capacity){
        constructor(type,0)(&packed_,nullptr);int64_t error=0;const void* args[]={&capacity};resize_method[type](&packed_,args,&error,1);
        if(capacity)switch(type){case BYTES:data_=reinterpret_cast<T*>(byte_write(&packed_,0));break;case F32:data_=reinterpret_cast<T*>(float_write(&packed_,0));break;case F64:data_=reinterpret_cast<T*>(double_write(&packed_,0));break;case I32:data_=reinterpret_cast<T*>(int_write(&packed_,0));break;case I64:data_=reinterpret_cast<T*>(long_write(&packed_,0));break;case V3S:data_=reinterpret_cast<T*>(vec_write(&packed_,0));break;default:break;}
    }
    PackedField(const PackedField&)=delete;
    ~PackedField(){destructor(type_)(&packed_);}
    void push_back(const T& value){assert(count_<capacity_);data_[count_++]=value;}
    size_t size()const{return count_;}
    T& operator[](size_t i){return data_[i];}
    void publish(void* dict,const char* key){
        if(count_!=capacity_){int64_t error=0;const void* args[]={&count_};resize_method[type_](&packed_,args,&error,1);}
        put(dict,key,type_,&packed_);
    }
};
template<class T> void field(void* dict,const char* key,VT,PackedField<T>& values){values.publish(dict,key);}
void snapshot(army::Crowd& crowd,void* dict){
    const auto& units=crowd.packed_source();
    const auto count=std::count_if(units.begin(),units.end(),[](const auto& u){return u.alive;});
    PackedField<int32_t> rows_by_slot(I32,units.size());
    for(size_t i=0;i<units.size();++i)rows_by_slot.push_back(-1);
    PackedField<int64_t> handles(I64,count),ids(I64,count);PackedField<uint8_t> teams(BYTES,count);
    PackedField<int32_t> kinds(I32,count),actions(I32,count),status(I32,count);PackedField<army::Vec3> positions(V3S,count),velocities(V3S,count),pose_velocities(V3S,count);
    PackedField<float> yaw(F32,count),time(F32,count),pose(F32,count),phase(F32,count),buff(F32,count),render_time(F32,count),stun(F32,count),flash(F32,count);PackedField<int32_t> indices(I32,count),render_actions(I32,count),air_phase(I32,count),pose_rows(I32,count);PackedField<double> hp(F64,count),max_hp(F64,count),ages(F64,count);PackedField<int32_t> shelter_modes(I32,count);
    for(const auto& u:units){
        if(!u.alive)continue;
        rows_by_slot[uint32_t(u.handle)]=int32_t(ids.size());
        int render=u.blocking?13:u.action;double clock=u.action_time;
        if(u.team==1){
            if(u.air_phase){render=10;clock=u.action_time;}
            else if(render==0||render==12){
                if(u.recovery_left>0){render=9;clock=.14+.16-u.recovery_left;}
                else if(u.landing_left>0){render=11;clock=.8-u.landing_left;}
                else if(u.shot_left>0){render=12;clock=.2-u.shot_left;}
            }
        }
        ages.push_back(u.age);shelter_modes.push_back(u.shelter_mode);
        pose_rows.push_back(u.pose_row);render_actions.push_back(render);render_time.push_back(float(clock));stun.push_back(float(u.stun));flash.push_back(float(u.flash_left));air_phase.push_back(u.air_phase);
        pose.push_back(float(u.pose_time));phase.push_back(float(u.walk_phase));buff.push_back(float(u.buff_left));indices.push_back(u.combo_serial%6);
        handles.push_back(u.handle);ids.push_back(u.logical_id);teams.push_back(uint8_t(u.team));
        kinds.push_back(u.kind);positions.push_back(u.position);velocities.push_back(u.velocity);pose_velocities.push_back(u.pose_velocity);
        yaw.push_back(u.yaw);hp.push_back(u.hp);max_hp.push_back(u.max_hp);
        actions.push_back(u.action);time.push_back(u.action_time);status.push_back(u.status);
    }
    field(dict,"rows_by_slot",I32,rows_by_slot);field(dict,"handles",I64,handles);field(dict,"logical_ids",I64,ids);field(dict,"teams",BYTES,teams);
    field(dict,"kinds",I32,kinds);field(dict,"positions",V3S,positions);field(dict,"velocities",V3S,velocities);field(dict,"pose_velocities",V3S,pose_velocities);
    field(dict,"yaw",F32,yaw);field(dict,"hp",F64,hp);field(dict,"max_hp",F64,max_hp);field(dict,"ages",F64,ages);field(dict,"shelter_modes",I32,shelter_modes);
    field(dict,"actions",I32,actions);field(dict,"action_time",F32,time);field(dict,"status",I32,status);field(dict,"pose_time",F32,pose);field(dict,"walk_phase",F32,phase);field(dict,"buff_left",F32,buff);field(dict,"action_indices",I32,indices);field(dict,"render_actions",I32,render_actions);field(dict,"render_time",F32,render_time);field(dict,"stun_left",F32,stun);field(dict,"flash_left",F32,flash);field(dict,"air_phase",I32,air_phase);field(dict,"pose_rows",I32,pose_rows);
    const auto projectile_count=crowd.combat.active_projectiles().size();
    PackedField<int64_t> projectile_ids(I64,projectile_count),projectile_sources(I64,projectile_count);PackedField<int32_t> projectile_kinds(I32,projectile_count),projectile_effects(I32,projectile_count);PackedField<uint8_t> projectile_teams(BYTES,projectile_count),projectile_power(BYTES,projectile_count);
    PackedField<army::Vec3> projectile_positions(V3S,projectile_count),projectile_directions(V3S,projectile_count);PackedField<float> projectile_scales(F32,projectile_count),projectile_yaw_offset(F32,projectile_count),projectile_age(F32,projectile_count);
    for(const auto& p:crowd.combat.active_projectiles()){
        projectile_ids.push_back(p.id);projectile_sources.push_back(p.source_id);projectile_kinds.push_back(p.owner_kind);projectile_effects.push_back(p.effect_kind);projectile_teams.push_back(uint8_t(p.source_team));projectile_power.push_back(uint8_t(p.power));
        projectile_yaw_offset.push_back(p.yaw_offset);projectile_age.push_back(float(p.age));projectile_positions.push_back(p.position);projectile_directions.push_back(army::length(p.flight_direction)>0?p.flight_direction:p.direction);projectile_scales.push_back(p.scale*(p.ranger?2.4f*(p.power?1.35f:1.0f):1.0f));
    }
    field(dict,"projectile_yaw_offset",F32,projectile_yaw_offset);field(dict,"projectile_ids",I64,projectile_ids);field(dict,"projectile_sources",I64,projectile_sources);field(dict,"projectile_kinds",I32,projectile_kinds);field(dict,"projectile_effects",I32,projectile_effects);field(dict,"projectile_teams",BYTES,projectile_teams);field(dict,"projectile_power",BYTES,projectile_power);
    field(dict,"projectile_positions",V3S,projectile_positions);field(dict,"projectile_directions",V3S,projectile_directions);field(dict,"projectile_scales",F32,projectile_scales);field(dict,"projectile_age",F32,projectile_age);
    const auto shield_capacity=crowd.combat.active_counters().size()*3;
    PackedField<army::Vec3> shield_positions(V3S,shield_capacity);PackedField<float> shield_yaw(F32,shield_capacity),shield_age(F32,shield_capacity),shield_scales(F32,shield_capacity);
    const auto& shield_tune=crowd.combat.counter_tuning();
    for(const auto& c:crowd.combat.active_counters())for(int i=0;i<3;++i){
        double age=c.age-i*shield_tune[army::K_INTERVAL];if(age<0||age>=shield_tune[army::K_TRAVEL]+shield_tune[army::K_TAIL])continue;
        army::Vec3 direction{std::sin(c.yaw),0,std::cos(c.yaw)};
        shield_positions.push_back(c.position+(army::Vec3{0,float(shield_tune[army::K_HEIGHT]*.5),0}+direction*float(shield_tune[army::K_START]+shield_tune[army::K_DISTANCE]*std::clamp(age/shield_tune[army::K_TRAVEL],0.0,1.0)))*c.scale);
        shield_yaw.push_back(c.yaw);shield_age.push_back(float(age));shield_scales.push_back(c.scale);
    }
    field(dict,"shield_positions",V3S,shield_positions);field(dict,"shield_yaw",F32,shield_yaw);field(dict,"shield_age",F32,shield_age);field(dict,"shield_scales",F32,shield_scales);
}
// Main-thread-only links, registered once when an owned NPC facade is created.
// No raw Object pointer survives a call. Generation handles reject recycled slots.
struct RegisteredFacade {
    int64_t handle=0;GDObjectInstanceID object=0;Blob row;bool lazy_fields=false,event_health=false;
    RegisteredFacade(int64_t h,GDObjectInstanceID id,const void* source):handle(h),object(id){const void* args[]={source};constructor(DICT,1)(&row,args);}
    ~RegisteredFacade(){destructor(DICT)(&row);}
};
// State reads are frequent during hit dispatch; keep their dictionary keys
// alive with the runtime instead of allocating every key for every hit.
struct UnitStateKeys {
    static constexpr const char* texts[]={"shelter_mode","age","logical_id","team","kind","position","velocity","pose_velocity","walk_phase","pose_time","stun","pose_row","yaw","hp","max_hp","frozen","slow_factor","buff_left","chain_count","action_index","action","action_time","status","blocking","riposte","target_id","external_target","external_kind"};
    Variant values[sizeof(texts)/sizeof(texts[0])];
    UnitStateKeys(){for(size_t i=0;i<sizeof(texts)/sizeof(texts[0]);++i){Blob text;string_new(&text,texts[i]);from_type(STR)(&values[i],&text);destructor(STR)(&text);}}
    ~UnitStateKeys(){for(auto& value:values)variant_destroy(&value);}
};
struct MirrorKeys {
    Variant values[5];
    MirrorKeys(){const char* texts[]={"hp","pos","velocity","facing","army_pose_row"};for(int j=0;j<5;++j){Blob text=name(texts[j]);from_type(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&values[j],&text);release_name(text);}}
    ~MirrorKeys(){for(auto& key:values)variant_destroy(&key);}
};
void store_model_fields(void* row,double hp,army::Vec3 position,army::Vec3 velocity,double facing,int64_t pose,Variant* keys){
    const void* source[]={&hp,&position,&velocity,&facing,&pose};VT kinds[]={FLOAT,VEC3,VEC3,FLOAT,INT};
    for(int j=0;j<5;++j){auto slot=dictionary_index(row,&keys[j]);variant_destroy(slot);from_type(kinds[j])(slot,const_cast<void*>(source[j]));}
}
struct Instance {army::Crowd crowd;UnitStateKeys state_keys;MirrorKeys mirror_keys;std::vector<std::unique_ptr<RegisteredFacade>> facades=std::vector<std::unique_ptr<RegisteredFacade>>(4000);};
bool register_facade(Instance& instance,int64_t handle,const void* row,GDExtensionObjectPtr actor){
    auto unit=instance.crowd.unit(handle);
    if(!unit||!actor||!cast_object(actor,unit->team==0?characterbody3d_tag:node3d_tag)||!has_script_method(actor,&sync_native_metadata_name)||!has_script_method(actor,&shared_snapshot_name)||!has_script_method(actor,&plain_snapshot_name))return false;
    Variant receiver;from_type(GDEXTENSION_VARIANT_TYPE_OBJECT)(&receiver,&actor);auto id=object_id(&receiver);variant_destroy(&receiver);
    instance.facades[uint32_t(handle)]=std::make_unique<RegisteredFacade>(handle,id,row);
    instance.facades[uint32_t(handle)]->lazy_fields=unit->team==1&&has_script_method(actor,&lazy_snapshot_name);
    instance.facades[uint32_t(handle)]->event_health=unit->team==0&&has_script_method(actor,&event_health_name);return true;
}
int64_t sync_registered_facades(Instance& instance,void* data){
    using Clock=std::chrono::steady_clock;
    bool measured=instance.crowd.timing.enabled&&scalar<GDExtensionBool>(data,"profile_registered",BOOL,false);
    auto start=measured?Clock::now():Clock::time_point{},previous=start;
    auto mark=[&](double& total){if(measured){auto now=Clock::now();total+=std::chrono::duration<double,std::milli>(now-previous).count();previous=now;}};
    auto& timing=instance.crowd.timing;
    for(auto& link:instance.facades)if(link&&!instance.crowd.valid(link->handle))link.reset();
    auto handles=PackedRead<int64_t>(data,"handles",I64);size_t n=handles.size();if(!n)return 0;
    if(!scalar<GDExtensionBool>(data,"shared_facades",BOOL,false))return -1;
    auto hp=PackedRead<double>(data,"hp",F64),maximum=PackedRead<double>(data,"max_hp",F64);
    auto positions=PackedRead<army::Vec3>(data,"positions",V3S),velocities=PackedRead<army::Vec3>(data,"velocities",V3S);
    auto yaw=PackedRead<float>(data,"yaw",F32);auto poses=PackedRead<int32_t>(data,"pose_rows",I32);auto teams=PackedRead<uint8_t>(data,"teams",BYTES);
    if(hp.size()!=n||maximum.size()!=n||positions.size()!=n||velocities.size()!=n||yaw.size()!=n||poses.size()!=n||teams.size()!=n)return -1;
    // Validate the whole transfer before any writes. Generic/custom adapters fall
    // back to sync_facades; partial registration must never partly commit state.
    for(auto h:handles)if(h<=0||uint32_t(h)>=instance.facades.size()||!instance.facades[uint32_t(h)]||instance.facades[uint32_t(h)]->handle!=h)return -1;
    for(size_t i=0;i<n;++i)if(instance.crowd.unit(handles[i])->team!=teams[i])return -1;
    bool defer_rows=scalar<GDExtensionBool>(data,"defer_model_rows",BOOL,false);
    bool lazy=scalar<GDExtensionBool>(data,"lazy_ally_fields",BOOL,false);
    bool event_health=scalar<GDExtensionBool>(data,"event_enemy_health",BOOL,false);
    bool guard=scalar<GDExtensionBool>(data,"guard_poses",BOOL,true);int64_t count=0;
    mark(timing.facade_unpack);
    for(size_t i=0;i<n;++i){
        auto& link=*instance.facades[uint32_t(handles[i])];double facing=yaw[i];int64_t pose=poses[i];
        if(teams[i]==0&&!defer_rows)store_model_fields(&link.row,hp[i],positions[i],velocities[i],facing,pose,instance.mirror_keys.values);
        mark(timing.facade_rows);
        auto object=object_from_id(link.object);if(instance.crowd.timing.enabled)++instance.crowd.timing.facade_object_lookups;if(!object)continue;
        mark(timing.facade_lookup);
        army::Vec3 current;
        if(guard)engine_call(teams[i]==0?get_global_bind:get_position_bind,object,nullptr,&current);
        const void* point[]={&positions[i]};if(!guard||std::memcmp(&current,&positions[i],sizeof(current))!=0)engine_call(teams[i]==0?set_global_bind:set_position_bind,object,point,nullptr);
        army::Vec3 rotation;engine_call(get_rotation_bind,object,nullptr,&rotation);bool turn=std::memcmp(&rotation.y,&yaw[i],sizeof(float))!=0;rotation.y=yaw[i];
        const void* angle[]={&rotation};if(!guard||turn)engine_call(set_rotation_bind,object,angle,nullptr);
        mark(timing.facade_pose);
        // The coordinator has published a generation-checked shared view already.
        if(lazy&&link.lazy_fields){if(timing.enabled)++timing.shared_ally_updates;mark(timing.facade_fields);++count;continue;}
        if(!event_health||!link.event_health){
            Variant receiver,value;from_type(GDEXTENSION_VARIANT_TYPE_OBJECT)(&receiver,&object);GDExtensionBool valid=false;
            from_type(FLOAT)(&value,const_cast<void*>(static_cast<const void*>(&hp[i])));set_named(&receiver,&hp_name,&value,&valid);variant_destroy(&value);
            from_type(FLOAT)(&value,const_cast<void*>(static_cast<const void*>(&maximum[i])));set_named(&receiver,&max_hp_name,&value,&valid);variant_destroy(&value);
            if(timing.enabled)timing.facade_health_writes+=2;
            if(teams[i]==1){from_type(VEC3)(&value,const_cast<void*>(static_cast<const void*>(&velocities[i])));set_named(&receiver,&velocity_name,&value,&valid);variant_destroy(&value);if(timing.enabled)++timing.shared_ally_updates;}
            variant_destroy(&receiver);
        }
        if(teams[i]==0){const void* motion[]={&velocities[i]};engine_call(set_velocity_bind,object,motion,nullptr);if(timing.enabled)++timing.shared_enemy_updates;}
        ++count;mark(timing.facade_fields);
    }
    if(measured)timing.facade_total+=std::chrono::duration<double,std::milli>(Clock::now()-start).count();
    return count;
}
// Model readers synchronize once on demand; physics/contact facades stay at 60Hz.
int64_t sync_model_row(Instance& instance,const army::Unit* u){
    if(!u||u->team!=0)return 0;
    auto& link=instance.facades[uint32_t(u->handle)];if(!link||link->handle!=u->handle)return 0;
    store_model_fields(&link->row,u->hp,u->position,u->velocity,u->yaw,u->pose_row,instance.mirror_keys.values);return 1;
}
int64_t sync_model_rows(Instance& instance){
    int64_t count=0;for(const auto& u:instance.crowd.packed_source())if(u.alive)count+=sync_model_row(instance,&u);return count;
}
// Main-thread compatibility transfer. Scene objects stay outside the simulation;
// callbacks retain the same shared snapshot and source ordering as the GDScript loop.
int64_t sync_facades(army::Crowd& crowd,void* data,void* rows,void* enemies,void* allies,GDExtensionObjectPtr view){
    using Clock=std::chrono::steady_clock;
    const bool facade_timing=crowd.timing.enabled&&scalar<GDExtensionBool>(data,"profile_facades",BOOL,false);
    auto started=facade_timing?Clock::now():Clock::time_point{};auto previous=started;
    auto mark=[&](double& phase){if(facade_timing){auto now=Clock::now();phase+=std::chrono::duration<double,std::milli>(now-previous).count();previous=now;}};
    auto ids=PackedRead<int64_t>(data,"logical_ids",I64);auto teams=PackedRead<uint8_t>(data,"teams",BYTES);
    auto hp=PackedRead<double>(data,"hp",F64);auto positions=PackedRead<army::Vec3>(data,"positions",V3S),velocities=PackedRead<army::Vec3>(data,"velocities",V3S);
    auto yaw=PackedRead<float>(data,"yaw",F32);auto poses=PackedRead<int32_t>(data,"pose_rows",I32);size_t n=ids.size();
    auto maximum=PackedRead<double>(data,"max_hp",F64),ages=PackedRead<double>(data,"ages",F64);
    auto status=PackedRead<int32_t>(data,"status",I32),modes=PackedRead<int32_t>(data,"shelter_modes",I32);
    bool direct_values=maximum.size()==n&&ages.size()==n&&status.size()==n&&modes.size()==n;
    if(teams.size()!=n||hp.size()!=n||positions.size()!=n||velocities.size()!=n||yaw.size()!=n||poses.size()!=n)return 0;
    const char* texts[]={"hp","pos","velocity","facing","army_pose_row"};Variant keys[5];
    for(int i=0;i<5;++i){Blob text;string_new(&text,texts[i]);from_type(STR)(&keys[i],&text);destructor(STR)(&text);}
    Variant snapshot,row_owner,enemy_owner,ally_owner;from_type(GDEXTENSION_VARIANT_TYPE_OBJECT)(&snapshot,&view);from_type(DICT)(&row_owner,rows);from_type(DICT)(&enemy_owner,enemies);from_type(DICT)(&ally_owner,allies);int64_t count=0;
    auto lookup=[](void* dict,Variant& owner,Variant& key){GDExtensionBool valid=false;return variant_has_key(&owner,&key,&valid)&&valid?dictionary_read(dict,&key):nullptr;};
    bool guard_poses=scalar<GDExtensionBool>(data,"guard_poses",BOOL,true);
    bool shared=scalar<GDExtensionBool>(data,"shared_facades",BOOL,false);
    bool plain_fields=scalar<GDExtensionBool>(data,"plain_fields",BOOL,true);
    auto resolve=[&](const void* actor){if(crowd.timing.enabled)++crowd.timing.facade_object_lookups;return object_from_id(object_id(actor));};
    mark(crowd.timing.facade_unpack);
    for(size_t i=0;i<n;++i){
        Variant id;from_type(INT)(&id,const_cast<void*>(static_cast<const void*>(&ids[i])));
        if(teams[i]==0){
            auto value=lookup(rows,row_owner,id);
            if(value&&variant_type(value)==DICT){
                Blob row;to_type(DICT)(&row,value);double facing=yaw[i];int64_t pose=poses[i];
                const void* values[]={&hp[i],&positions[i],&velocities[i],&facing,&pose};VT kinds[]={FLOAT,VEC3,VEC3,FLOAT,INT};
                for(int j=0;j<5;++j){auto slot=dictionary_index(&row,&keys[j]);variant_destroy(slot);from_type(kinds[j])(slot,const_cast<void*>(values[j]));}
                destructor(DICT)(&row);
            }
        }
        mark(crowd.timing.facade_rows);
        auto actor=teams[i]==0?lookup(enemies,enemy_owner,id):lookup(allies,ally_owner,id);
        if(actor&&variant_type(actor)==GDEXTENSION_VARIANT_TYPE_OBJECT){
            // Resolve before invoking script: callbacks may mutate either map.
            auto object=resolve(actor);
            if(object){
                Variant index,result;int64_t at=i;from_type(INT)(&index,&at);
                GDExtensionCallError error{};
                bool metadata=direct_values&&has_script_method(object,&sync_native_metadata_name)&&cast_object(object,node3d_tag);
                mark(crowd.timing.facade_lookup);
                if(direct_values&&(metadata||has_script_method(object,&sync_native_snapshot_name))){
                    // Numeric and Vector3 Variants are inline. Avoid repeated
                    // GDScript object-property and packed-array reads per unit.
                    Variant values[8];double facing=yaw[i];int64_t flags=status[i],mode=modes[i];
                    const void* source[]={&hp[i],&maximum[i],&positions[i],&velocities[i],&facing,&ages[i],&flags,&mode};
                    VT types[]={FLOAT,FLOAT,VEC3,VEC3,FLOAT,FLOAT,INT,INT};
                    const void* args[]={&snapshot,&index,&values[0],&values[1],&values[2],&values[3],&values[4],&values[5],&values[6],&values[7]};
                    for(int j=0;j<8;++j)from_type(types[j])(&values[j],const_cast<void*>(source[j]));
                    if(metadata){
                        army::Vec3 current_position;
                        if(guard_poses)engine_call(teams[i]==0?get_global_bind:get_position_bind,object,nullptr,&current_position);
                        const void* position_args[]={&positions[i]};if(!guard_poses||std::memcmp(&current_position,&positions[i],sizeof(army::Vec3))!=0)engine_call(teams[i]==0?set_global_bind:set_position_bind,object,position_args,nullptr);
                        army::Vec3 rotation;engine_call(get_rotation_bind,object,nullptr,&rotation);bool turn=std::memcmp(&rotation.y,&yaw[i],sizeof(float))!=0;rotation.y=yaw[i];
                        const void* rotation_args[]={&rotation};if(!guard_poses||turn)engine_call(set_rotation_bind,object,rotation_args,nullptr);
                        const void* state_args[]={&snapshot,&index,&values[0],&values[1],&values[3],&values[4],&values[5],&values[6],&values[7]};
                        mark(crowd.timing.facade_pose);
                        bool adopted=false;
                        if(shared&&has_script_method(object,&shared_snapshot_name)){
                            Variant receiver,current;from_type(GDEXTENSION_VARIANT_TYPE_OBJECT)(&receiver,&object);bool valid_health=true;
                            bool plain=plain_fields&&has_script_method(object,&plain_snapshot_name);
                            for(int j=0;j<2;++j){
                                const auto* property=j==0?&hp_name:&max_hp_name;GDExtensionBool valid=false;
                                if(plain){set_named(&receiver,property,&values[j],&valid);valid_health=valid_health&&valid;continue;}
                                if(crowd.timing.enabled)++crowd.timing.facade_field_reads;
                                get_named(&receiver,property,&current,&valid);
                                double previous=0;bool same=false;if(valid&&variant_type(&current)==FLOAT){to_type(FLOAT)(&previous,&current);same=previous==(j==0?hp[i]:maximum[i]);}
                                variant_destroy(&current);
                                if(!same){valid=false;set_named(&receiver,property,&values[j],&valid);}valid_health=valid_health&&valid;
                            }
                            if(valid_health&&teams[i]==0){const void* velocity_args[]={&velocities[i]};engine_call(set_velocity_bind,object,velocity_args,nullptr);adopted=true;if(crowd.timing.enabled)++crowd.timing.shared_enemy_updates;}
                            if(valid_health&&teams[i]==1){
                                GDExtensionBool valid=false;
                                if(plain)set_named(&receiver,&velocity_name,&values[3],&valid);
                                else{
                                if(crowd.timing.enabled)++crowd.timing.facade_field_reads;
                                get_named(&receiver,&velocity_name,&current,&valid);army::Vec3 previous{};bool same=false;
                                if(valid&&variant_type(&current)==VEC3){to_type(VEC3)(&previous,&current);same=previous.x==velocities[i].x&&previous.y==velocities[i].y&&previous.z==velocities[i].z;}
                                variant_destroy(&current);if(!same){valid=false;set_named(&receiver,&velocity_name,&values[3],&valid);}
                                }
                                if(valid){adopted=true;if(crowd.timing.enabled)++crowd.timing.shared_ally_updates;}
                            }
                            variant_destroy(&receiver);
                        }
                        mark(crowd.timing.facade_fields);
                        if(adopted)nil_new(&result);else script_call(object,&sync_native_metadata_name,state_args,9,&result,&error);
                    }else script_call(object,&sync_native_snapshot_name,args,10,&result,&error);
                    for(auto& value:values)variant_destroy(&value);
                }else{
                    const void* args[]={&snapshot,&index};script_call(object,&sync_snapshot_name,args,2,&result,&error);
                }
                variant_destroy(&result);variant_destroy(&index);
                if(error.error==GDEXTENSION_CALL_OK)++count;
            }
        }
        variant_destroy(&id);mark(crowd.timing.facade_callbacks);
    }
    if(facade_timing)crowd.timing.facade_total+=std::chrono::duration<double,std::milli>(Clock::now()-started).count();
    variant_destroy(&snapshot);variant_destroy(&row_owner);variant_destroy(&enemy_owner);variant_destroy(&ally_owner);for(auto& key:keys)variant_destroy(&key);return count;
}
// Mirrors for paid autonomous allies. guard_radius is the existing ownership
// marker; plain combat fixtures and external gate defenders are not paid hires.
struct HelperMirror {int64_t logical_id;army::Vec3 position,guard_post;double hp;int32_t status,shelter_mode;};
std::vector<HelperMirror> helper_rows(army::Crowd& crowd){
    std::vector<HelperMirror> rows;
    for(const auto& u:crowd.packed_source())if(u.alive&&u.team==1&&u.hp>0&&u.guard_radius>0)rows.push_back({u.logical_id,u.position,u.guard_post,u.hp,u.status,u.shelter_mode});
    return rows;
}
int64_t sync_helper_rows(const std::vector<HelperMirror>& source,void* rows,void* posts){
    std::vector<const HelperMirror*> live;
    for(const auto& u:source)live.push_back(&u);
    // Paid IDs decrease monotonically at pool creation. Slot reuse must not
    // reorder source targeting ties or the UI's placement list.
    std::sort(live.begin(),live.end(),[](auto a,auto b){return a->logical_id>b->logical_id;});
    Variant owner,post_owner,result;from_type(DICT)(&owner,rows);from_type(DICT)(&post_owner,posts);
    Blob keys_name=name("keys"),clear_name=name("clear"),erase_name=name("erase");GDExtensionCallError error{};
    variant_call(&post_owner,&keys_name,nullptr,0,&result,&error);Blob previous;to_type(ARRAY)(&previous,&result);variant_destroy(&result);
    variant_call(&post_owner,&clear_name,nullptr,0,&result,&error);variant_destroy(&result);
    const char* texts[]={"id","pos","hp","targetable","taunting"};Variant keys[5];
    for(int i=0;i<5;++i){Blob text;string_new(&text,texts[i]);from_type(STR)(&keys[i],&text);destructor(STR)(&text);}
    for(const auto* u:live){
        Variant id;from_type(INT)(&id,const_cast<int64_t*>(&u->logical_id));auto slot=dictionary_index(posts,&id);variant_destroy(slot);from_type(VEC3)(slot,const_cast<army::Vec3*>(&u->guard_post));
        if(u->shelter_mode==2){const void* args[]={&id};variant_call(&owner,&erase_name,args,1,&result,&error);variant_destroy(&result);variant_destroy(&id);continue;}
        GDExtensionBool exists=false;auto value=variant_has_key(&owner,&id,&exists)&&exists?dictionary_read(rows,&id):nullptr;Blob row;
        if(value&&variant_type(value)==DICT)to_type(DICT)(&row,value);
        else{constructor(DICT,0)(&row,nullptr);slot=dictionary_index(rows,&id);variant_destroy(slot);from_type(DICT)(slot,&row);}
        GDExtensionBool targetable=(u->status&64)==0,taunting=(u->status&32)!=0;
        const void* values[]={&u->logical_id,&u->position,&u->hp,&targetable,&taunting};VT kinds[]={INT,VEC3,FLOAT,BOOL,BOOL};
        for(int j=0;j<5;++j){slot=dictionary_index(&row,&keys[j]);variant_destroy(slot);from_type(kinds[j])(slot,const_cast<void*>(values[j]));}
        destructor(DICT)(&row);variant_destroy(&id);
    }
    int64_t count=0;size_method[ARRAY](&previous,nullptr,&count,0);
    for(int64_t i=0;i<count;++i){auto id=array_index(&previous,i);GDExtensionBool valid=false;if(!variant_has_key(&post_owner,id,&valid)||!valid){const void* args[]={id};variant_call(&owner,&erase_name,args,1,&result,&error);variant_destroy(&result);}}
    destructor(ARRAY)(&previous);variant_destroy(&owner);variant_destroy(&post_owner);for(auto& key:keys)variant_destroy(&key);
    release_name(keys_name);release_name(clear_name);release_name(erase_name);return live.size();
}
int64_t sync_helper_mirrors(army::Crowd& crowd,void* rows,void* posts){return sync_helper_rows(helper_rows(crowd),rows,posts);}
void capture_helper_snapshot(army::Crowd& crowd,void* result){
    std::vector<int64_t> ids;std::vector<army::Vec3> positions,posts;std::vector<double> hp;std::vector<int32_t> status,modes;
    for(const auto& u:helper_rows(crowd)){ids.push_back(u.logical_id);positions.push_back(u.position);posts.push_back(u.guard_post);hp.push_back(u.hp);status.push_back(u.status);modes.push_back(u.shelter_mode);}
    field(result,"logical_ids",I64,ids);field(result,"positions",V3S,positions);field(result,"guard_posts",V3S,posts);field(result,"hp",F64,hp);field(result,"status",I32,status);field(result,"shelter_modes",I32,modes);put_bool(result,"valid",true);
}
int64_t sync_helper_snapshot(void* data,void* rows,void* posts){
    const char* keys[]={"logical_ids","positions","guard_posts","hp","status","shelter_modes"};VT types[]={I64,V3S,V3S,F64,I32,I32};
    if(!scalar<GDExtensionBool>(data,"valid",BOOL,false))return -1;
    for(int i=0;i<6;++i){auto value=get(data,keys[i]);if(!value||variant_type(value)!=types[i])return -1;}
    auto ids=vector<int64_t>(data,"logical_ids",I64);auto positions=vector<army::Vec3>(data,"positions",V3S),guards=vector<army::Vec3>(data,"guard_posts",V3S);auto hp=vector<double>(data,"hp",F64);auto status=vector<int32_t>(data,"status",I32),modes=vector<int32_t>(data,"shelter_modes",I32);
    size_t n=ids.size();if(n>2000||positions.size()!=n||guards.size()!=n||hp.size()!=n||status.size()!=n||modes.size()!=n)return -1;
    std::vector<HelperMirror> captured;std::unordered_set<int64_t> unique;
    for(size_t i=0;i<n;++i){
        if(!unique.insert(ids[i]).second||!army::finite(positions[i])||!army::finite(guards[i])||!std::isfinite(hp[i])||hp[i]<=0||modes[i]<0||modes[i]>4)return -1;
        captured.push_back({ids[i],positions[i],guards[i],hp[i],status[i],modes[i]});
    }
    return sync_helper_rows(captured,rows,posts);
}
// Capture the same public collector records without allocating an intermediate
// Dictionary per fighter, then normalize them in another GDScript loop.
void collector_snapshot(void* player,void* defenders,void* workers,double deck,double pickup,double radius,void* result){
    if(!std::isfinite(deck)||!std::isfinite(pickup)||!std::isfinite(radius)||radius<=0){put_bool(result,"valid",false);return;}
    std::vector<army::Vec3> points;std::vector<std::string> ids;Blob cells;constructor(DICT,0)(&cells,nullptr);bool valid=true;
    auto add=[&](const std::string& id,army::Vec3 foot){
        if(!army::finite(foot))return;foot.y+=float(pickup);if(!army::finite(foot)){valid=false;return;}
        double x=std::floor(double(foot.x)/radius),z=std::floor(double(foot.z)/radius);
        if(x<INT32_MIN||x>INT32_MAX||z<INT32_MIN||z>INT32_MAX){valid=false;return;}
        points.push_back(foot);ids.push_back(id);struct {int32_t x,z;} cell{int32_t(x),int32_t(z)};
        Variant key;from_type(GDEXTENSION_VARIANT_TYPE_VECTOR2I)(&key,&cell);auto slot=dictionary_index(&cells,&key);variant_destroy(slot);GDExtensionBool yes=true;from_type(BOOL)(slot,&yes);variant_destroy(&key);
    };
    if(scalar<double>(player,"hp",FLOAT,0)>0&&scalar<GDExtensionBool>(player,"active",BOOL,true))add("player",scalar<army::Vec3>(player,"pos",VEC3,{}));
    Blob keys_name=name("keys");
    for(int team=0;team<2;++team){
        void* table=team==0?defenders:workers;Variant owner,keys_result;from_type(DICT)(&owner,table);GDExtensionCallError error{};
        variant_call(&owner,&keys_name,nullptr,0,&keys_result,&error);Blob keys;to_type(ARRAY)(&keys,&keys_result);variant_destroy(&keys_result);
        int64_t n=0;size_method[ARRAY](&keys,nullptr,&n,0);
        for(int64_t i=0;i<n;++i){
            auto value=dictionary_read(table,array_index(&keys,i));if(!value||variant_type(value)!=DICT)continue;
            Blob row;to_type(DICT)(&row,value);
            if(scalar<double>(&row,"hp",FLOAT,0)>0&&!(team==1&&(get(&row,"sheltered_building")||equals(&row,"state","wounded")))){
                auto foot=scalar<army::Vec3>(&row,"pos",VEC3,{});int64_t id=scalar<int64_t>(&row,"id",INT,0);
                if(team==1)foot.y+=float(equals(&row,"state","garrison")?deck:scalar<double>(&row,"deck_height",FLOAT,0));
                add(std::string(team==0?"ally_":"worker_")+std::to_string(id),foot);
            }
            destructor(DICT)(&row);
        }
        destructor(ARRAY)(&keys);variant_destroy(&owner);
    }
    release_name(keys_name);field(result,"positions",V3S,points);put(result,"cells",DICT,&cells);destructor(DICT)(&cells);
    Blob labels;constructor(ARRAY,0)(&labels,nullptr);int64_t count=ids.size(),error=0;const void* resize_args[]={&count};resize_method[ARRAY](&labels,resize_args,&error,1);
    for(int64_t i=0;i<count;++i){Blob text;string_new(&text,ids[i].c_str());auto slot=array_index(&labels,i);variant_destroy(slot);from_type(STR)(slot,&text);destructor(STR)(&text);}
    put(result,"ids",ARRAY,&labels);destructor(ARRAY)(&labels);put_bool(result,"valid",valid);
}
// Index the caller's captured model order once. Queries still use the live
// native spatial grid; only this GDScript-to-native table build moves here.
void index_enemy_rows(void* rows,void* handles,void* supported,void* result){
    Blob indices;constructor(DICT,0)(&indices,nullptr);std::vector<int64_t> fallback;
    Variant handle_owner,supported_owner;from_type(DICT)(&handle_owner,handles);from_type(DICT)(&supported_owner,supported);
    const char* texts[]={"id","variant","hp"};Variant keys[3];
    for(int j=0;j<3;++j){Blob text;string_new(&text,texts[j]);from_type(STR)(&keys[j],&text);destructor(STR)(&text);}
    int64_t count=0;size_method[ARRAY](rows,nullptr,&count,0);bool valid=true;
    for(int64_t i=0;i<count;++i){
        auto row_value=array_index(rows,i);if(variant_type(row_value)!=DICT){valid=false;break;}
        Blob row;to_type(DICT)(&row,row_value);const void* values[3]{};
        for(int j=0;j<3;++j){GDExtensionBool found=false;
            if(variant_has_key(row_value,&keys[j],&found)&&found)values[j]=dictionary_read(&row,&keys[j]);
        }
        if(!values[0]||!values[1]||!values[2]||variant_type(values[0])!=INT||variant_type(values[1])!=INT||(variant_type(values[2])!=FLOAT&&variant_type(values[2])!=INT))valid=false;
        if(valid){
            double hp=0;if(variant_type(values[2])==FLOAT)to_type(FLOAT)(&hp,const_cast<void*>(values[2]));else{int64_t n=0;to_type(INT)(&n,const_cast<void*>(values[2]));hp=double(n);}
            if(!(hp<=0)){
                GDExtensionBool found=false;int64_t handle=0;
                if(variant_has_key(&handle_owner,values[0],&found)&&found){auto value=dictionary_read(handles,values[0]);if(variant_type(value)==INT)to_type(INT)(&handle,value);else valid=false;}
                found=false;bool known=variant_has_key(&supported_owner,values[1],&found)&&found;
                if(!handle||!known)fallback.push_back(i);
                else{Variant key;from_type(INT)(&key,&handle);auto slot=dictionary_index(&indices,&key);variant_destroy(slot);from_type(INT)(slot,&i);variant_destroy(&key);}
            }
        }
        destructor(DICT)(&row);if(!valid)break;
    }
    put_bool(result,"valid",valid);put(result,"handles",DICT,&indices);field(result,"fallback",I64,fallback);
    for(auto& key:keys)variant_destroy(&key);variant_destroy(&handle_owner);variant_destroy(&supported_owner);destructor(DICT)(&indices);
}
// Pure presentation packing: use the installed engine's basis/quaternion math.
// No simulation state or scene objects are read by this caller-owned transfer.
void projectile_buffers(void* snapshot,double bullet_scale,const int32_t* limits,void* result){
    auto ids=PackedRead<int64_t>(snapshot,"projectile_ids",I64);
    auto kinds=PackedRead<int32_t>(snapshot,"projectile_kinds",I32);
    auto effects=PackedRead<int32_t>(snapshot,"projectile_effects",I32);
    auto yaw_offset=PackedRead<float>(snapshot,"projectile_yaw_offset",F32);
    auto teams=PackedRead<uint8_t>(snapshot,"projectile_teams",BYTES),power=PackedRead<uint8_t>(snapshot,"projectile_power",BYTES);
    auto age=PackedRead<float>(snapshot,"projectile_age",F32),scales=PackedRead<float>(snapshot,"projectile_scales",F32);
    auto directions=PackedRead<army::Vec3>(snapshot,"projectile_directions",V3S),positions=PackedRead<army::Vec3>(snapshot,"projectile_positions",V3S);
    auto shield_positions=PackedRead<army::Vec3>(snapshot,"shield_positions",V3S);
    auto shield_yaw=PackedRead<float>(snapshot,"shield_yaw",F32),shield_age=PackedRead<float>(snapshot,"shield_age",F32),shield_scales=PackedRead<float>(snapshot,"shield_scales",F32);
    size_t n=ids.size(),shields=shield_positions.size();
    if((yaw_offset.size()!=0&&yaw_offset.size()!=n)||limits[0]<0||size_t(limits[0])>n||limits[1]<0||size_t(limits[1])>shields||!std::isfinite(bullet_scale)||bullet_scale<=0||kinds.size()!=n||teams.size()!=n||power.size()!=n||age.size()!=n||scales.size()!=n||directions.size()!=n||positions.size()!=n||shield_yaw.size()!=shields||shield_age.size()!=shields||shield_scales.size()!=shields){put_bool(result,"valid",false);return;}
    struct Basis {float rows[3][3];};
    const army::Vec3 up{0,1,0},back{0,0,1};
    auto scaled=[&](Basis basis,float factor){army::Vec3 scale{factor,factor,factor};const void* args[]={&scale};Basis out;scale_basis(&basis,args,&out,1);return out;};
    auto yaw_basis=[&](double yaw){Basis basis;const void* args[]={&up,&yaw};constructor(GDEXTENSION_VARIANT_TYPE_BASIS,3)(&basis,args);return basis;};
    auto append=[](std::vector<float>& buffer,const Basis& basis,army::Vec3 position,float age,float alpha){
        for(const auto& row:basis.rows)for(float value:row)if(!std::isfinite(value))return false;
        for(int row=0;row<3;++row){for(int col=0;col<3;++col)buffer.push_back(basis.rows[row][col]);buffer.push_back(row==0?position.x:(row==1?position.y:position.z));}
        buffer.insert(buffer.end(),{age,alpha,0,0});return true;
    };
    std::array<std::vector<float>,29> batches;std::vector<float> shield;
    for(int i=0;i<limits[0];++i){
        if(!army::finite(positions[i])||!army::finite(directions[i])||!std::isfinite(age[i])||!std::isfinite(scales[i])||(yaw_offset.size()&&!std::isfinite(yaw_offset[i]))){put_bool(result,"valid",false);return;}
        int key=kinds[i]==5?16:(power[i]?18:17);
        if(teams[i]==0){key=int(std::fmod(std::floor(double(age[i])*30),16));if(key<0)key+=16;}
        if(teams[i]==0&&kinds[i]==4)key=19;
        if(teams[i]==0&&kinds[i]==17)key=21;
        if(teams[i]==0&&kinds[i]==18){if(effects.size()!=n||effects[i]<0||effects[i]>5){put_bool(result,"valid",false);return;}key=effects[i]==0&&power[i]?28:22+effects[i];}
        if(teams[i]==1&&kinds[i]==8)key=20;
        Basis basis;constructor(GDEXTENSION_VARIANT_TYPE_BASIS,0)(&basis,nullptr);
        if(army::dot(directions[i],directions[i])>.00001f){
            army::Vec3 direction=directions[i];normalize_vector(&direction,nullptr,&direction,0);
            float quaternion[4];const void* arc[]={&back,&direction};constructor(GDEXTENSION_VARIANT_TYPE_QUATERNION,4)(quaternion,arc);
            const void* args[]={quaternion};constructor(GDEXTENSION_VARIANT_TYPE_BASIS,2)(&basis,args);
        }
        if(teams[i]==0&&kinds[i]==18&&effects[i]==0&&power[i]&&yaw_offset.size()){
            Basis offset;double angle=yaw_offset[i];const void* args[]={&up,&angle};constructor(GDEXTENSION_VARIANT_TYPE_BASIS,3)(&offset,args);Basis turned;multiply_basis(&basis,&offset,&turned);basis=turned;
        }
        if(teams[i]==0&&kinds[i]==18&&effects[i]==5)basis=yaw_basis(std::atan2(-directions[i].x,-directions[i].z));
        if(kinds[i]==5){auto spin=yaw_basis(double(age[i])*30);Basis turned;multiply_basis(&basis,&spin,&turned);basis=turned;}
        if(teams[i]==0&&kinds[i]!=4&&kinds[i]!=17&&kinds[i]!=18)basis=scaled(basis,float(bullet_scale));
        if(!append(batches[key],scaled(basis,scales[i]),positions[i],age[i],1)){put_bool(result,"valid",false);return;}
        if(teams[i]==0&&kinds[i]==18&&effects[i]==1){
            Basis mirrored=basis;for(int row=0;row<3;++row)mirrored.rows[row][0]*=-1;
            if(!append(batches[key],scaled(mirrored,scales[i]),positions[i],age[i],1)){put_bool(result,"valid",false);return;}
        }
        if(teams[i]==0&&kinds[i]==17)for(int trail=1;trail<=2;++trail)append(batches[key],scaled(basis,scales[i]*(trail==1?.7f:.45f)),positions[i]-directions[i]*(trail*.7f*scales[i]*3),std::max(0.f,age[i]-trail*.08f),1);
        if(teams[i]==0&&kinds[i]==18&&effects[i]==3&&!power[i])for(int trail=1;trail<=2;++trail)append(batches[key],scaled(basis,scales[i]*(trail==1?.7f:.45f)),positions[i]-directions[i]*(trail*7.5f*scales[i]),std::max(0.f,age[i]-trail*.06f),.25f/trail);
    }
    for(int i=0;i<limits[1];++i){
        if(!army::finite(shield_positions[i])||!std::isfinite(shield_yaw[i])||!std::isfinite(shield_age[i])||!std::isfinite(shield_scales[i])){put_bool(result,"valid",false);return;}
        float alpha=float(std::min(1.0,(1-double(shield_age[i])/.22)*3));
        if(!append(shield,scaled(yaw_basis(shield_yaw[i]),shield_scales[i]),shield_positions[i],shield_age[i],alpha)){put_bool(result,"valid",false);return;}
    }
    Blob output;constructor(DICT,0)(&output,nullptr);
    for(size_t i=0;i<batches.size();++i){auto key=i>=22?"finale-shot"+std::to_string(i-22):i<16?"bullet"+std::to_string(i):(i==16?std::string("star"):(i==17?std::string("ranger-arrow"):(i==18?std::string("ranger-power-arrow"):(i==19?std::string("skullpion-ball"):(i==20?std::string("dragon"):std::string("dark-lumina-ball"))))));field(&output,key.c_str(),F32,batches[i]);}
    put(result,"projectiles",DICT,&output);destructor(DICT)(&output);field(result,"shields",F32,shield);put_bool(result,"valid",true);
}
enum Method{CONFIGURE,SPAWN,DESPAWN,VALID,CLEAR,SNAPSHOT,QUERY,NAVIGATION,GOALS,STEP,KITS,HIT,EVENTS,TARGETS,STATE,POSE,RENDER,REST,GUARD,REST_TICK,FILTER_BOXES,INSTANCE_BUFFERS,NEARBY_POINTS,SYNC_FACADES,SYNC_HELPERS,QUERY_STATS,COLLECTORS,STEP_PROFILE,BEGIN_STEP,FINISH_STEP,CAPTURE_HELPERS,SNAPSHOT_HELPERS,PARALLEL_MOVEMENT,SCENE_EVENTS,REGISTER_FACADE,SYNC_REGISTERED,INDEX_ENEMIES,PROJECTILE_BUFFERS,SYNC_MODEL_ROWS,SYNC_MODEL_ROWS_FOR,QUERY_ACTORS,MIRROR,MIRROR_BUSY,ENEMY_SCALING,CAN_REACH,COUNT};
const VT types[COUNT][6]={{INT,INT},{INT,INT,INT,VEC3,FLOAT,FLOAT},{INT},{INT},{},{},{AABB,INT},{DICT},{I64,V3S,F32},{FLOAT},{DICT},{INT,DICT},{},{DICT},{INT},{INT,VEC3,FLOAT},{},{},{INT,VEC3,FLOAT},{FLOAT},{V3S,V3S,VEC3,VEC3},{DICT,DICT},{V3S,VEC3,FLOAT},{DICT,DICT,DICT,DICT,GDEXTENSION_VARIANT_TYPE_OBJECT},{DICT,DICT},{BOOL},{DICT,DICT,DICT,FLOAT,FLOAT,FLOAT},{BOOL},{FLOAT},{},{},{DICT,DICT,DICT},{BOOL},{},{INT,DICT,GDEXTENSION_VARIANT_TYPE_OBJECT},{DICT},{ARRAY,DICT,DICT},{DICT,FLOAT,GDEXTENSION_VARIANT_TYPE_VECTOR2I},{},{I64},{AABB,DICT,ARRAY,ARRAY},{INT,INT,FLOAT,FLOAT,VEC3},{INT,BOOL},{INT,FLOAT,FLOAT},{VEC3,VEC3,FLOAT}};
const VT outputs[COUNT]={NIL,INT,NIL,BOOL,NIL,DICT,I64,NIL,NIL,NIL,BOOL,DICT,ARRAY,NIL,DICT,NIL,DICT,NIL,NIL,NIL,I64,DICT,I64,INT,INT,DICT,DICT,DICT,BOOL,NIL,DICT,INT,NIL,ARRAY,BOOL,INT,DICT,DICT,INT,INT,ARRAY,BOOL,NIL,BOOL,BOOL};
const int counts[COUNT]={2,6,1,1,0,0,2,1,3,1,1,2,0,1,1,3,0,0,3,1,4,2,3,5,2,1,6,1,1,0,0,3,1,0,3,1,3,3,0,1,4,5,2,3,3};
void ptrcall(void* userdata,void* instance,const void* const* args,void* ret){
    auto& owner=*static_cast<Instance*>(instance);auto& crowd=owner.crowd;
    const auto method=intptr_t(userdata);
    // Only these coin/mirror helpers operate entirely on caller-owned input.
    // Every shared-state read/write joins first, including hits and retirement.
    if(method!=BEGIN_STEP&&method!=FINISH_STEP&&method!=COLLECTORS&&method!=NEARBY_POINTS&&method!=SNAPSHOT_HELPERS&&method!=INDEX_ENEMIES&&method!=PROJECTILE_BUFFERS)crowd.finish_step();
    switch(method){
        case CAN_REACH:*static_cast<GDExtensionBool*>(ret)=crowd.terrain.reachable(*static_cast<const army::Vec3*>(args[0]),*static_cast<const army::Vec3*>(args[1]),float(*static_cast<const double*>(args[2])),-1);break;
        case ENEMY_SCALING:*static_cast<GDExtensionBool*>(ret)=crowd.set_enemy_scaling(*static_cast<const int64_t*>(args[0]),*static_cast<const double*>(args[1]),*static_cast<const double*>(args[2]));break;
        case MIRROR:*static_cast<GDExtensionBool*>(ret)=crowd.set_mirror(*static_cast<const int64_t*>(args[0]),*static_cast<const int64_t*>(args[1]),*static_cast<const double*>(args[2]),*static_cast<const double*>(args[3]),*static_cast<const army::Vec3*>(args[4]));break;
        case MIRROR_BUSY:if(auto u=crowd.unit(*static_cast<const int64_t*>(args[0]));u&&u->mirror_actions>0){u->mirror_busy=*static_cast<const GDExtensionBool*>(args[1]);if(u->mirror_busy)u->has_goal=false;}break;
        case PROJECTILE_BUFFERS:projectile_buffers(const_cast<void*>(args[0]),*static_cast<const double*>(args[1]),static_cast<const int32_t*>(args[2]),ret);break;
        case INDEX_ENEMIES:index_enemy_rows(const_cast<void*>(args[0]),const_cast<void*>(args[1]),const_cast<void*>(args[2]),ret);break;
        case REGISTER_FACADE:*static_cast<GDExtensionBool*>(ret)=register_facade(owner,*static_cast<const int64_t*>(args[0]),args[1],*static_cast<GDExtensionObjectPtr const*>(args[2]));break;
        case SYNC_MODEL_ROWS_FOR:{
            int64_t n=0;size_method[I64](const_cast<void*>(args[0]),nullptr,&n,0);const auto* handles=n?long_read(args[0],0):nullptr;int64_t count=0;
            for(int64_t i=0;i<n;++i)count+=sync_model_row(owner,crowd.unit(handles[i]));*static_cast<int64_t*>(ret)=count;break;
        }
        case SYNC_MODEL_ROWS:*static_cast<int64_t*>(ret)=sync_model_rows(owner);break;
        case SYNC_REGISTERED:*static_cast<int64_t*>(ret)=sync_registered_facades(owner,const_cast<void*>(args[0]));break;
        case PARALLEL_MOVEMENT:crowd.parallel_movement_enabled=*static_cast<const GDExtensionBool*>(args[0]);break;
        case CAPTURE_HELPERS:capture_helper_snapshot(crowd,ret);break;
        case SNAPSHOT_HELPERS:*static_cast<int64_t*>(ret)=sync_helper_snapshot(const_cast<void*>(args[0]),const_cast<void*>(args[1]),const_cast<void*>(args[2]));break;
        case BEGIN_STEP:*static_cast<GDExtensionBool*>(ret)=crowd.begin_step(*static_cast<const double*>(args[0]));break;
        case FINISH_STEP:crowd.finish_step();break;
        case STEP_PROFILE:{
            auto& t=crowd.timing;put_bool(ret,"enabled",t.enabled);put_int(ret,"steps",t.steps);put_int(ret,"facade_object_lookups",t.facade_object_lookups);put_int(ret,"shared_enemy_updates",t.shared_enemy_updates);put_int(ret,"shared_ally_updates",t.shared_ally_updates);put_int(ret,"movement_jobs",t.movement_jobs);put_int(ret,"facade_field_reads",t.facade_field_reads);put_int(ret,"facade_health_writes",t.facade_health_writes);
            put(ret,"total_ms",FLOAT,&t.total);put(ret,"grid_ms",FLOAT,&t.grid);put(ret,"decisions_ms",FLOAT,&t.decisions);put(ret,"movement_ms",FLOAT,&t.movement);put(ret,"combat_ms",FLOAT,&t.combat);put(ret,"animation_ms",FLOAT,&t.animation);
            put(ret,"facade_total_ms",FLOAT,&t.facade_total);put(ret,"facade_unpack_ms",FLOAT,&t.facade_unpack);put(ret,"facade_rows_ms",FLOAT,&t.facade_rows);put(ret,"facade_lookup_ms",FLOAT,&t.facade_lookup);put(ret,"facade_pose_ms",FLOAT,&t.facade_pose);put(ret,"facade_fields_ms",FLOAT,&t.facade_fields);put(ret,"facade_callbacks_ms",FLOAT,&t.facade_callbacks);
            put_int(ret,"air_considered",crowd.terrain.air_profile.considered+crowd.allied_terrain.air_profile.considered);put_int(ret,"air_kept",crowd.terrain.air_profile.kept+crowd.allied_terrain.air_profile.kept);put_int(ret,"capsule_tests",crowd.terrain.air_profile.capsule_tests+crowd.allied_terrain.air_profile.capsule_tests);
            const auto& nav=crowd.terrain.navigation_profile;const auto& allied_nav=crowd.allied_terrain.navigation_profile;
            put_int(ret,"nav_route_hits",nav.route_hits+allied_nav.route_hits);put_int(ret,"nav_waypoints",nav.waypoints+allied_nav.waypoints);put_int(ret,"nav_flow_builds",nav.flow_builds+allied_nav.flow_builds);put_int(ret,"nav_topology_builds",nav.topology_builds+allied_nav.topology_builds);put_int(ret,"nav_segments",nav.segments+allied_nav.segments);put_int(ret,"nav_heights",nav.heights+allied_nav.heights);
            double route_ms=nav.route_ms+allied_nav.route_ms,flow_ms=nav.flow_ms+allied_nav.flow_ms,topology_ms=nav.topology_ms+allied_nav.topology_ms;
            put(ret,"nav_route_ms",FLOAT,&route_ms);put(ret,"nav_flow_ms",FLOAT,&flow_ms);put(ret,"nav_topology_ms",FLOAT,&topology_ms);
            if(*static_cast<const GDExtensionBool*>(args[0])){t={};t.enabled=true;crowd.terrain.navigation_profile={true};crowd.allied_terrain.navigation_profile={true};crowd.terrain.air_profile={true,0,0};crowd.allied_terrain.air_profile={true,0,0};}break;
        }
        case COLLECTORS:collector_snapshot(const_cast<void*>(args[0]),const_cast<void*>(args[1]),const_cast<void*>(args[2]),*static_cast<const double*>(args[3]),*static_cast<const double*>(args[4]),*static_cast<const double*>(args[5]),ret);break;
        case QUERY_STATS:
            put_int(ret,"enemy_sorted_items",crowd.query_sorted_items[0]);put_int(ret,"ally_sorted_items",crowd.query_sorted_items[1]);put_int(ret,"enemy_candidates",crowd.query_candidates[0]);put_int(ret,"ally_candidates",crowd.query_candidates[1]);put_int(ret,"enemy_queries",crowd.query_calls[0]);put_int(ret,"ally_queries",crowd.query_calls[1]);
            if(*static_cast<const GDExtensionBool*>(args[0])){crowd.query_candidates={};crowd.query_calls={};crowd.query_sorted_items={};}break;
        case SYNC_HELPERS:*static_cast<int64_t*>(ret)=sync_helper_mirrors(crowd,const_cast<void*>(args[0]),const_cast<void*>(args[1]));break;
        case SYNC_FACADES:*static_cast<int64_t*>(ret)=sync_facades(crowd,const_cast<void*>(args[0]),const_cast<void*>(args[1]),const_cast<void*>(args[2]),const_cast<void*>(args[3]),*static_cast<GDExtensionObjectPtr const*>(args[4]));break;
        case CONFIGURE:for(auto& link:owner.facades)link.reset();crowd.configure(int(*static_cast<const int64_t*>(args[0])),int(*static_cast<const int64_t*>(args[1])));break;
        case SPAWN:*static_cast<int64_t*>(ret)=crowd.spawn(*static_cast<const int64_t*>(args[0]),int(*static_cast<const int64_t*>(args[1])),int(*static_cast<const int64_t*>(args[2])),*static_cast<const army::Vec3*>(args[3]),*static_cast<const double*>(args[4]),*static_cast<const double*>(args[5]));break;
        case DESPAWN:crowd.despawn(*static_cast<const int64_t*>(args[0]));break;
        case VALID:*static_cast<GDExtensionBool*>(ret)=crowd.valid(*static_cast<const int64_t*>(args[0]));break;
        case CLEAR:for(auto& link:owner.facades)link.reset();crowd.clear();break;
        case REST:crowd.rest_allies();break;
        case REST_TICK:crowd.combat.rest_tick(crowd,*static_cast<const double*>(args[0]));break;
        case GUARD:crowd.set_guard(*static_cast<const int64_t*>(args[0]),*static_cast<const army::Vec3*>(args[1]),float(*static_cast<const double*>(args[2])));break;
        case SNAPSHOT:case RENDER:snapshot(crowd,ret);break;
        case QUERY:{
            const auto& b=*static_cast<const Bounds*>(args[0]);army::Vec3 end{b.position.x+b.size.x,b.position.y+b.size.y,b.position.z+b.size.z};
            const auto values=crowd.query(b.position,end,int(*static_cast<const int64_t*>(args[1])));
            int64_t n=values.size(),error=0;const void* resize_args[]={&n};resize_method[I64](ret,resize_args,&error,1);
            if(n)std::memcpy(long_write(ret,0),values.data(),n*sizeof(int64_t));break;
        }
        case QUERY_ACTORS:{
            const auto& bounds=*static_cast<const Bounds*>(args[0]);
            auto handles=crowd.query(bounds.position,bounds.position+bounds.size,0,false);
            std::unordered_set<GDObjectInstanceID> selected;
            Variant actors;from_type(DICT)(&actors,const_cast<void*>(args[1]));
            for(auto handle:handles){
                Variant key;from_type(INT)(&key,&handle);GDExtensionBool valid=false;
                if(variant_has_key(&actors,&key,&valid)&&valid){
                    auto value=dictionary_read(args[1],&key);auto id=variant_type(value)==GDEXTENSION_VARIANT_TYPE_OBJECT?object_id(value):0;auto actor=object_from_id(id);
                    if(actor){GDExtensionBool queued=false;engine_call(queued_bind,actor,nullptr,&queued);if(!queued)selected.insert(id);}
                }
                variant_destroy(&key);
            }
            variant_destroy(&actors);
            int64_t extra=0;size_method[ARRAY](const_cast<void*>(args[3]),nullptr,&extra,0);
            for(int64_t i=0;i<extra;++i){auto value=array_index(const_cast<void*>(args[3]),i);auto id=variant_type(value)==GDEXTENSION_VARIANT_TYPE_OBJECT?object_id(value):0;if(object_from_id(id))selected.insert(id);}
            // Project into the caller's live ordering; no cached poses or order can go stale.
            int64_t count=0;size_method[ARRAY](const_cast<void*>(args[2]),nullptr,&count,0);
            std::vector<GDExtensionObjectPtr> ordered;ordered.reserve(selected.size());
            for(int64_t i=0;i<count;++i){
                auto value=array_index(const_cast<void*>(args[2]),i);auto id=variant_type(value)==GDEXTENSION_VARIANT_TYPE_OBJECT?object_id(value):0;
                if(selected.count(id)){auto actor=object_from_id(id);if(actor)ordered.push_back(actor);}
            }
            int64_t n=ordered.size(),error=0;const void* resize_args[]={&n};resize_method[ARRAY](ret,resize_args,&error,1);
            for(int64_t i=0;i<n;++i){auto slot=array_index(ret,i);variant_destroy(slot);from_type(GDEXTENSION_VARIANT_TYPE_OBJECT)(slot,&ordered[i]);}
            break;
        }
        case NEARBY_POINTS:{
            int64_t n=0;size_method[V3S](const_cast<void*>(args[0]),nullptr,&n,0);
            const auto* points=n?reinterpret_cast<const army::Vec3*>(vec_read(args[0],0)):nullptr;
            const auto& origin=*static_cast<const army::Vec3*>(args[1]);double radius=*static_cast<const double*>(args[2]);
            struct Candidate {int64_t index;float distance;int x,z;};std::vector<Candidate> candidates;
            if(army::finite(origin)&&std::isfinite(radius)&&radius>0)for(int64_t i=0;i<n;++i){
                if(!army::finite(points[i]))continue;auto v=points[i]-origin;float distance=army::dot(v,v);
                if(distance<=radius*radius)candidates.push_back({i,distance,int(std::floor(points[i].x/radius)),int(std::floor(points[i].z/radius))});
            }
            std::sort(candidates.begin(),candidates.end(),[](const auto& a,const auto& b){
                if(a.distance!=b.distance)return a.distance<b.distance;
                if(a.x!=b.x)return a.x<b.x;if(a.z!=b.z)return a.z<b.z;return a.index<b.index;
            });
            int64_t count=candidates.size(),error=0;const void* resize_args[]={&count};resize_method[I64](ret,resize_args,&error,1);
            if(count){auto target=long_write(ret,0);for(int64_t i=0;i<count;++i)target[i]=candidates[i].index;}break;
        }
        case INSTANCE_BUFFERS:{
            void* snapshot=const_cast<void*>(args[0]);void* profiles=const_cast<void*>(args[1]);
            auto kinds=PackedRead<int32_t>(snapshot,"kinds",I32),actions=PackedRead<int32_t>(snapshot,"render_actions",I32),indices=PackedRead<int32_t>(snapshot,"action_indices",I32),phases=PackedRead<int32_t>(snapshot,"air_phase",I32),status=PackedRead<int32_t>(snapshot,"status",I32),poses=PackedRead<int32_t>(snapshot,"pose_rows",I32);
            auto teams=PackedRead<uint8_t>(snapshot,"teams",BYTES);auto positions=PackedRead<army::Vec3>(snapshot,"positions",V3S),velocities=PackedRead<army::Vec3>(snapshot,"pose_velocities",V3S);
            auto yaw=PackedRead<float>(snapshot,"yaw",F32),render_time=PackedRead<float>(snapshot,"render_time",F32),pose_time=PackedRead<float>(snapshot,"pose_time",F32),walk=PackedRead<float>(snapshot,"walk_phase",F32),flash=PackedRead<float>(snapshot,"flash_left",F32);
            auto hp=PackedRead<double>(snapshot,"hp",F64),max_hp=PackedRead<double>(snapshot,"max_hp",F64);size_t n=kinds.size();
            if(teams.size()!=n||actions.size()!=n||indices.size()!=n||phases.size()!=n||status.size()!=n||poses.size()!=n||positions.size()!=n||velocities.size()!=n||yaw.size()!=n||render_time.size()!=n||pose_time.size()!=n||walk.size()!=n||flash.size()!=n||hp.size()!=n||max_hp.size()!=n){put_bool(ret,"valid",false);break;}
            auto profile_kinds=PackedRead<int32_t>(profiles,"kinds",I32);auto values=PackedRead<double>(profiles,"values",F64);
            constexpr size_t stride=2+army::CLIP_COUNT*5;
            if(values.size()!=profile_kinds.size()*stride){put_bool(ret,"valid",false);break;}
            std::map<int,army::InstanceProfile> table;
            for(size_t i=0;i<profile_kinds.size();++i){auto& p=table[profile_kinds[i]];size_t at=i*stride;p.speed=values[at++];p.cadence=values[at++];
                if(!std::isfinite(p.speed)||!std::isfinite(p.cadence)||p.speed<=0||p.cadence<=0){put_bool(ret,"valid",false);return;}
                for(auto& c:p.clips){c.start=values[at++];c.count=values[at++];c.duration=values[at++];c.loop=values[at++]!=0;c.exists=values[at++]!=0;
                    if(!std::isfinite(c.start)||!std::isfinite(c.count)||!std::isfinite(c.duration)||c.count<1||c.duration<=0){put_bool(ret,"valid",false);return;}}
            }
            std::vector<army::InstanceRow> rows;rows.reserve(n);
            for(size_t i=0;i<n;++i){
                if(!army::finite(positions[i])||!army::finite(velocities[i])||!std::isfinite(yaw[i])||!std::isfinite(render_time[i])||!std::isfinite(pose_time[i])||!std::isfinite(walk[i])||!std::isfinite(flash[i])||!std::isfinite(hp[i])||!std::isfinite(max_hp[i])||max_hp[i]<=0||indices[i]<0||indices[i]>5){put_bool(ret,"valid",false);return;}
                rows.push_back({kinds[i],teams[i],status[i],actions[i],indices[i],phases[i],poses[i],positions[i],velocities[i],yaw[i],render_time[i],pose_time[i],walk[i],flash[i],hp[i],max_hp[i]});
            }
            auto packed=army::instance_buffers(rows,table);put_bool(ret,"valid",packed.valid);if(!packed.valid)break;
            put_int(ret,"submitted",packed.submitted);field(ret,"health",F32,packed.health);
            Blob batches;constructor(ARRAY,0)(&batches,nullptr);int64_t count=packed.batches.size(),error=0;const void* resize_args[]={&count};resize_method[ARRAY](&batches,resize_args,&error,1);
            for(int64_t i=0;i<count;++i){const auto& b=packed.batches[i];Blob dict;constructor(DICT,0)(&dict,nullptr);int32_t key[]={b.kind,b.x,b.z};
                put(&dict,"key",GDEXTENSION_VARIANT_TYPE_VECTOR3I,key);field(&dict,"buffer",F32,b.buffer);
                float extent=b.kind==17?36.f:12.f;
                Bounds bounds{b.low-army::Vec3{extent,4,extent},b.high-b.low+army::Vec3{extent*2,b.kind==17?72.f:20.f,extent*2}};put(&dict,"bounds",AABB,&bounds);
                auto slot=array_index(&batches,i);variant_destroy(slot);from_type(DICT)(slot,&dict);destructor(DICT)(&dict);
            }
            put(ret,"batches",ARRAY,&batches);destructor(ARRAY)(&batches);break;
        }
        case FILTER_BOXES:{
            int64_t count=0,other=0;size_method[V3S](const_cast<void*>(args[0]),nullptr,&count,0);size_method[V3S](const_cast<void*>(args[1]),nullptr,&other,0);
            const auto& a=*static_cast<const army::Vec3*>(args[2]);const auto& b=*static_cast<const army::Vec3*>(args[3]);
            const auto* lows=count?reinterpret_cast<const army::Vec3*>(vec_read(args[0],0)):nullptr;
            const auto* highs=other?reinterpret_cast<const army::Vec3*>(vec_read(args[1],0)):nullptr;
            std::vector<int64_t> hits;hits.reserve(count);
            for(int64_t i=0;i<count;++i){
                if(i>=other||!army::finite(lows[i])||!army::finite(highs[i])||!(highs[i].x<a.x||lows[i].x>b.x||highs[i].y<a.y||lows[i].y>b.y||highs[i].z<a.z||lows[i].z>b.z))hits.push_back(i);
            }
            int64_t n=hits.size(),error=0;const void* resize_args[]={&n};resize_method[I64](ret,resize_args,&error,1);
            if(n)std::memcpy(long_write(ret,0),hits.data(),n*sizeof(int64_t));break;
        }
        case NAVIGATION:{
            auto dict=const_cast<void*>(args[0]);army::NavigationData data;
            data.width=int(scalar<int64_t>(dict,"width",INT,0));data.spacing=float(scalar<double>(dict,"spacing",FLOAT,3));
            data.origin=scalar<army::Vec3>(dict,"origin",VEC3,{-240,0,-240});
            data.bounds_min=scalar<army::Vec3>(dict,"bounds_min",VEC3,{-1e8f,0,-1e8f});data.bounds_max=scalar<army::Vec3>(dict,"bounds_max",VEC3,{1e8f,0,1e8f});
            data.heights=vector<float>(dict,"heights",F32);data.covered=vector<uint8_t>(dict,"covered",BYTES);data.pieces=vector<float>(dict,"pieces",F32);
            data.friendly_navigation=scalar<GDExtensionBool>(dict,"friendly_navigation",BOOL,0);data.friendly_obstacle_min=vector<army::Vec3>(dict,"friendly_obstacle_min",V3S);data.friendly_obstacle_max=vector<army::Vec3>(dict,"friendly_obstacle_max",V3S);
            data.obstacle_min=vector<army::Vec3>(dict,"obstacle_min",V3S);data.obstacle_max=vector<army::Vec3>(dict,"obstacle_max",V3S);
            data.layer_min=vector<army::Vec3>(dict,"layer_min",V3S);data.layer_max=vector<army::Vec3>(dict,"layer_max",V3S);
            data.ray_min=vector<army::Vec3>(dict,"ray_min",V3S);data.ray_max=vector<army::Vec3>(dict,"ray_max",V3S);data.ray_owner=vector<int64_t>(dict,"ray_owner",I64);
            data.air_faces=vector<army::Vec3>(dict,"air_faces",V3S);
            data.air_owner=vector<int64_t>(dict,"air_owner",I64);
            crowd.set_navigation(std::move(data));break;
        }
        case GOALS:{
            auto handles=unpack<int64_t>(args[0],I64);auto goals=unpack<army::Vec3>(args[1],V3S);auto speeds=unpack<float>(args[2],F32);
            if(handles.size()!=goals.size()||handles.size()!=speeds.size())break;
            for(size_t i=0;i<handles.size();++i)crowd.set_goal(handles[i],goals[i],speeds[i]);break;
        }
        case STEP:crowd.step(*static_cast<const double*>(args[0]));break;
        case KITS:{
            void* dict=const_cast<void*>(args[0]);army::KitData data;
            data.enemy_size=float(scalar<double>(dict,"enemy_size",FLOAT,1));
            data.soldier_pose_meta=vector<int32_t>(dict,"soldier_pose_meta",I32);data.soldier_pose_rows=vector<int32_t>(dict,"soldier_pose_rows",I32);data.soldier_kinds=vector<int32_t>(dict,"soldier_kinds",I32);data.soldier_profiles=vector<float>(dict,"soldier_profiles",F32);
            data.enemy_kits=vector<float>(dict,"enemy_kits",F32);
            data.enemy_contact_ends=vector<float>(dict,"enemy_contact_ends",F32);
            data.ninja=vector<double>(dict,"ninja",F64);data.bunker=vector<double>(dict,"bunker",F64);
            data.dragoon=vector<double>(dict,"dragoon",F64);
            data.blademaster=vector<double>(dict,"blademaster",F64);data.knight=vector<double>(dict,"knight",F64);data.skullpion=vector<double>(dict,"skullpion",F64);data.dark_lumina=vector<double>(dict,"dark_lumina",F64);
            data.dark_lumina_spin=vector<float>(dict,"dark_lumina_spin",F32);
            data.finale_meta=vector<int32_t>(dict,"finale_meta",I32);data.finale_frames=vector<float>(dict,"finale_frames",F32);data.finale_shots=vector<double>(dict,"finale_shots",F64);data.finale_scale=float(scalar<double>(dict,"finale_scale",FLOAT,1));data.finale_ranges=vector<double>(dict,"finale_ranges",F64);
            data.ranger=vector<double>(dict,"ranger",F64);data.ranger_muzzles=vector<army::Vec3>(dict,"ranger_muzzles",V3S);data.ranger_motion_muzzles=vector<army::Vec3>(dict,"ranger_motion_muzzles",V3S);
            data.ally_kinds=vector<int32_t>(dict,"ally_kinds",I32);data.walk_cadence=vector<double>(dict,"walk_cadence",F64);data.ally_profiles=vector<double>(dict,"ally_profiles",F64);data.ally_primaries=vector<double>(dict,"ally_primaries",F64);
            data.actions=vector<int32_t>(dict,"actions",I32);data.status_bits=vector<int32_t>(dict,"status_bits",I32);
            data.phase_ticks=vector<float>(dict,"phase_ticks",F32);data.contact_ticks=vector<float>(dict,"contact_ticks",F32);
            data.melee_from=scalar<army::Vec3>(dict,"melee_from",VEC3,{});data.melee_to=scalar<army::Vec3>(dict,"melee_to",VEC3,{});data.muzzle=scalar<army::Vec3>(dict,"muzzle",VEC3,{});
            data.bullet_speed=float(scalar<double>(dict,"bullet_speed",FLOAT,0));data.bullet_life=float(scalar<double>(dict,"bullet_life",FLOAT,0));data.bullet_tail=float(scalar<double>(dict,"bullet_tail",FLOAT,0));data.bullet_radius=float(scalar<double>(dict,"bullet_radius",FLOAT,0));data.damage_taken_multiplier=float(scalar<double>(dict,"damage_taken_multiplier",FLOAT,1));
            *static_cast<GDExtensionBool*>(ret)=crowd.combat.configure(std::move(data));break;
        }
        case HIT:{
            void* dict=const_cast<void*>(args[1]);army::Hit hit;
            hit.provoke=scalar<GDExtensionBool>(dict,"provoke",BOOL,1);hit.amount=scalar<double>(dict,"amount",FLOAT,0);hit.status_seconds=scalar<double>(dict,"status_seconds",FLOAT,0);
            hit.source_id=scalar<int64_t>(dict,"source_id",INT,0);hit.ticket_id=scalar<int64_t>(dict,"ticket_id",INT,0);
            hit.direction=scalar<army::Vec3>(dict,"direction",VEC3,{});hit.projectile=scalar<GDExtensionBool>(dict,"projectile",BOOL,0);hit.heavy=scalar<GDExtensionBool>(dict,"heavy",BOOL,0);hit.critical=scalar<GDExtensionBool>(dict,"critical",BOOL,0);
            hit.responsive_recoil=scalar<GDExtensionBool>(dict,"responsive_recoil",BOOL,0);
            hit.impulse=scalar<army::Vec3>(dict,"knockback",VEC3,{});hit.flinch=scalar<double>(dict,"flinch",FLOAT,0);hit.add_impulse=scalar<GDExtensionBool>(dict,"add_impulse",BOOL,0);
            hit.effect=equals(dict,"element","ice")?1:(equals(dict,"element","slow")?2:(equals(dict,"element","avatar")?3:(equals(dict,"element","stun")?4:(equals(dict,"element","taunt")?5:0))));
            hit.attack_slow_factor=float(scalar<double>(dict,"attack_slow_factor",FLOAT,1));hit.magical=scalar<GDExtensionBool>(dict,"magical",BOOL,0);hit.slow_factor=float(scalar<double>(dict,"slow_factor",FLOAT,1));
            auto result=crowd.combat.hit(crowd,*static_cast<const int64_t*>(args[0]),hit);
            put_bool(ret,"accepted",result.accepted);put_bool(ret,"dead",result.dead);put(ret,"hp",FLOAT,&result.hp);break;
        }
        case POSE:crowd.set_pose(*static_cast<const int64_t*>(args[0]),*static_cast<const army::Vec3*>(args[1]),float(*static_cast<const double*>(args[2])));break;
        case STATE:{auto u=crowd.unit(*static_cast<const int64_t*>(args[0]));if(!u)break;
            auto store=[&](size_t key,VT type,const void* value){auto slot=dictionary_index(ret,&owner.state_keys.values[key]);variant_destroy(slot);from_type(type)(slot,const_cast<void*>(value));};
            auto integer=[&](size_t key,int64_t value){store(key,INT,&value);};
            auto boolean=[&](size_t key,bool value){GDExtensionBool flag=value;store(key,BOOL,&flag);};
            integer(0,u->shelter_mode);store(1,FLOAT,&u->age);integer(2,u->logical_id);integer(3,u->team);integer(4,u->kind);store(5,VEC3,&u->position);store(6,VEC3,&u->velocity);store(7,VEC3,&u->pose_velocity);store(8,FLOAT,&u->walk_phase);store(9,FLOAT,&u->pose_time);store(10,FLOAT,&u->stun);integer(11,u->pose_row);double yaw=u->yaw;store(12,FLOAT,&yaw);store(13,FLOAT,&u->hp);store(14,FLOAT,&u->max_hp);store(15,FLOAT,&u->frozen);double slow=u->slow_factor;store(16,FLOAT,&slow);store(17,FLOAT,&u->buff_left);integer(18,u->chain_count);integer(19,u->combo_serial%(u->kind==7?4:3));integer(20,u->action);store(21,FLOAT,&u->action_time);integer(22,u->status);boolean(23,u->blocking);boolean(24,u->riposte);auto target=crowd.unit(u->target_handle);integer(25,target?target->logical_id:0);integer(26,u->external_target);integer(27,u->external_kind);break;}
        case EVENTS:write_events(crowd.combat,ret);break;
        case SCENE_EVENTS:write_events(crowd.combat,ret,true);break;
        case TARGETS:{
            void* dict=const_cast<void*>(args[0]);auto ids=vector<int64_t>(dict,"ids",I64);auto kinds=vector<int32_t>(dict,"kinds",I32);auto positions=vector<army::Vec3>(dict,"positions",V3S);auto hp=vector<float>(dict,"hp",F32);
            auto valid=vector<uint8_t>(dict,"targetable",BYTES),taunts=vector<uint8_t>(dict,"taunting",BYTES);auto lows=vector<army::Vec3>(dict,"minimum",V3S),highs=vector<army::Vec3>(dict,"maximum",V3S);
            auto ignores=vector<int64_t>(dict,"ignore_building",I64);
            auto priorities=vector<int32_t>(dict,"assault_priority",I32);
            std::vector<army::ExternalTarget> targets;
            if(ids.size()==kinds.size()&&ids.size()==positions.size()&&ids.size()==hp.size())for(size_t i=0;i<ids.size();++i){
                army::ExternalTarget target;target.id=ids[i];target.kind=kinds[i];target.foot=positions[i];target.hp=hp[i];target.targetable=i>=valid.size()||valid[i];target.taunting=i<taunts.size()&&taunts[i];target.minimum=i<lows.size()?lows[i]:positions[i];target.maximum=i<highs.size()?highs[i]:positions[i];target.ignore_building=i<ignores.size()?ignores[i]:-1;target.assault_priority=i<priorities.size()?std::clamp(priorities[i],0,4):0;targets.push_back(target);
            }
            crowd.combat.set_targets(std::move(targets));
            auto shelter_ids=vector<int64_t>(dict,"shelter_ids",I64);auto entrances=vector<army::Vec3>(dict,"shelter_entrances",V3S),centers=vector<army::Vec3>(dict,"shelter_centers",V3S);auto damage_serial=vector<int64_t>(dict,"shelter_damage",I64);std::vector<army::ShelterTarget> shelters;
            if(shelter_ids.size()==entrances.size()&&shelter_ids.size()==centers.size())for(size_t i=0;i<shelter_ids.size();++i)shelters.push_back({shelter_ids[i],entrances[i],centers[i],i<damage_serial.size()?damage_serial[i]:0});crowd.combat.set_shelters(std::move(shelters));break;
        }
    }
}
void call(void* userdata,void* instance,const void* const* args,GDExtensionInt argc,void* ret,GDExtensionCallError* error){
    auto m=intptr_t(userdata);error->error=GDEXTENSION_CALL_OK;
    if(argc!=counts[m]){error->error=argc<counts[m]?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=counts[m];nil_new(ret);return;}
    alignas(8) unsigned char storage[6][32]{};const void* converted[6]{};
    for(int i=0;i<argc;++i){to_type(types[m][i])(storage[i],const_cast<void*>(args[i]));converted[i]=storage[i];}
    if(outputs[m]==NIL){ptrcall(userdata,instance,converted,nullptr);nil_new(ret);}
    else if(outputs[m]==DICT||outputs[m]==I64||outputs[m]==ARRAY){Blob result;constructor(outputs[m],0)(&result,nullptr);ptrcall(userdata,instance,converted,&result);from_type(outputs[m])(ret,&result);destructor(outputs[m])(&result);}
    else{alignas(8) unsigned char result[8]{};ptrcall(userdata,instance,converted,result);from_type(outputs[m])(ret,result);}
    for(int i=0;i<argc;++i)if(types[m][i]==DICT||types[m][i]==ARRAY||types[m][i]>=BYTES)destructor(types[m][i])(storage[i]);
}
GDExtensionObjectPtr create(void*,GDExtensionBool){auto object=construct_object(&parent_name);set_instance(object,&class_name,new Instance);return object;}
void free_instance(void*,void* instance){delete static_cast<Instance*>(instance);}
void bind(int method,const char* method_text,const char* const* argument_text){
    Blob method_name=name(method_text),empty_name=name("");Blob empty;string_new(&empty,"");
    Blob names[6];GDExtensionPropertyInfo arguments[6]{};GDExtensionClassMethodArgumentMetadata metadata[6]{};
    for(int i=0;i<counts[method];++i){names[i]=name(argument_text[i]);arguments[i]={types[method][i],&names[i],&empty_name,0,&empty,6};metadata[i]=types[method][i]==FLOAT?GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE:GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;}
    GDExtensionPropertyInfo output{outputs[method],&empty_name,&empty_name,0,&empty,6};
    GDExtensionClassMethodInfo info{};info.name=&method_name;info.method_userdata=reinterpret_cast<void*>(intptr_t(method));info.call_func=call;info.ptrcall_func=ptrcall;info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;info.has_return_value=outputs[method]!=NIL;info.return_value_info=&output;info.argument_count=counts[method];info.arguments_info=arguments;info.arguments_metadata=metadata;
    register_method(library,&class_name,&info);
    for(int i=0;i<counts[method];++i)release_name(names[i]);release_name(method_name);release_name(empty_name);destructor(STR)(&empty);
}
bool initialize(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr lib){
    library=lib;
    #define LOAD(variable,type,symbol) variable=reinterpret_cast<type>(proc(symbol));if(!variable)return false
    LOAD(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");
    LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");
    LOAD(constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");
    LOAD(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");
    LOAD(builtin,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");
    auto operator_evaluator=reinterpret_cast<GDExtensionInterfaceVariantGetPtrOperatorEvaluator>(proc("variant_get_ptr_operator_evaluator"));
    if(!operator_evaluator)return false;
    multiply_basis=operator_evaluator(GDEXTENSION_VARIANT_OP_MULTIPLY,GDEXTENSION_VARIANT_TYPE_BASIS,GDEXTENSION_VARIANT_TYPE_BASIS);
    Blob scaled=name("scaled"),normalized=name("normalized");
    scale_basis=builtin(GDEXTENSION_VARIANT_TYPE_BASIS,&scaled,3934786792LL);
    normalize_vector=builtin(VEC3,&normalized,1776574132LL);
    release_name(scaled);release_name(normalized);
    if(!multiply_basis||!scale_basis||!normalize_vector)return false;
    LOAD(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");
    LOAD(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");
    LOAD(nil_new,GDExtensionInterfaceVariantNewNil,"variant_new_nil");
    LOAD(variant_destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");
    LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject2,"classdb_construct_object2");
    LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");
    LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass5,"classdb_register_extension_class5");
    LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
    LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");
    LOAD(dictionary_index,GDExtensionInterfaceDictionaryOperatorIndex,"dictionary_operator_index");
    LOAD(dictionary_read,GDExtensionInterfaceDictionaryOperatorIndexConst,"dictionary_operator_index_const");
    LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");
    LOAD(variant_has_key,GDExtensionInterfaceVariantHasKey,"variant_has_key");
    LOAD(variant_call,GDExtensionInterfaceVariantCall,"variant_call");
    LOAD(object_id,GDExtensionInterfaceVariantGetObjectInstanceId,"variant_get_object_instance_id");
    LOAD(object_from_id,GDExtensionInterfaceObjectGetInstanceFromId,"object_get_instance_from_id");
    LOAD(script_call,GDExtensionInterfaceObjectCallScriptMethod,"object_call_script_method");
    LOAD(has_script_method,GDExtensionInterfaceObjectHasScriptMethod,"object_has_script_method");
    LOAD(get_named,GDExtensionInterfaceVariantGetNamed,"variant_get_named");
    LOAD(set_named,GDExtensionInterfaceVariantSetNamed,"variant_set_named");
    LOAD(get_bind,GDExtensionInterfaceClassdbGetMethodBind,"classdb_get_method_bind");
    LOAD(engine_call,GDExtensionInterfaceObjectMethodBindPtrcall,"object_method_bind_ptrcall");
    LOAD(get_tag,GDExtensionInterfaceClassdbGetClassTag,"classdb_get_class_tag");
    LOAD(cast_object,GDExtensionInterfaceObjectCastTo,"object_cast_to");
    LOAD(byte_read,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");
    LOAD(double_read,GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,"packed_float64_array_operator_index_const");
    LOAD(float_read,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");
    LOAD(int_read,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");
    LOAD(long_read,GDExtensionInterfacePackedInt64ArrayOperatorIndexConst,"packed_int64_array_operator_index_const");
    LOAD(vec_read,GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,"packed_vector3_array_operator_index_const");
    LOAD(array_index,GDExtensionInterfaceArrayOperatorIndex,"array_operator_index");
    LOAD(string_utf8,GDExtensionInterfaceStringToUtf8Chars,"string_to_utf8_chars");
    LOAD(byte_write,GDExtensionInterfacePackedByteArrayOperatorIndex,"packed_byte_array_operator_index");
    LOAD(int_write,GDExtensionInterfacePackedInt32ArrayOperatorIndex,"packed_int32_array_operator_index");
    LOAD(long_write,GDExtensionInterfacePackedInt64ArrayOperatorIndex,"packed_int64_array_operator_index");
    LOAD(double_write,GDExtensionInterfacePackedFloat64ArrayOperatorIndex,"packed_float64_array_operator_index");
    LOAD(float_write,GDExtensionInterfacePackedFloat32ArrayOperatorIndex,"packed_float32_array_operator_index");
    LOAD(vec_write,GDExtensionInterfacePackedVector3ArrayOperatorIndex,"packed_vector3_array_operator_index");
    #undef LOAD
    class_name=name("GoemonCrowdRuntime");parent_name=name("RefCounted");sync_snapshot_name=name("sync_snapshot");sync_native_snapshot_name=name("sync_native_snapshot");sync_native_metadata_name=name("sync_native_metadata");shared_snapshot_name=name("uses_shared_snapshot");plain_snapshot_name=name("uses_plain_snapshot_fields");lazy_snapshot_name=name("uses_lazy_snapshot_fields");event_health_name=name("uses_event_health");hp_name=name("hp");max_hp_name=name("max_hp");velocity_name=name("velocity");
    Blob body_class=name("CharacterBody3D");characterbody3d_tag=get_tag(&body_class);release_name(body_class);
    Blob node_class=name("Node3D");node3d_tag=get_tag(&node_class);
    auto scene_method=[&](const char* text,int64_t hash){Blob method=name(text);auto result=get_bind(&node_class,&method,hash);release_name(method);return result;};
    // Hashes from the installed Godot4.6.1 extension API, same Vector3/Euler
    // setters as the original script properties, with no object-name lookup.
    get_position_bind=scene_method("get_position",3360562783LL);get_global_bind=scene_method("get_global_position",3360562783LL);
    set_position_bind=scene_method("set_position",3460891852LL);set_global_bind=scene_method("set_global_position",3460891852LL);
    get_rotation_bind=scene_method("get_rotation",3360562783LL);set_rotation_bind=scene_method("set_rotation",3460891852LL);release_name(node_class);
    Blob object_class=name("Object"),queued_method=name("is_queued_for_deletion");queued_bind=get_bind(&object_class,&queued_method,36873697LL);release_name(object_class);release_name(queued_method);
    Blob character_class=name("CharacterBody3D"),velocity_method=name("set_velocity");set_velocity_bind=get_bind(&character_class,&velocity_method,3460891852LL);release_name(character_class);release_name(velocity_method);
    if(!queued_bind||!get_position_bind||!get_global_bind||!set_velocity_bind||!node3d_tag||!set_position_bind||!set_global_bind||!get_rotation_bind||!set_rotation_bind)return false;
    for(auto t:{BYTES,I32,I64,F32,F64,V3S,ARRAY}){
        Blob resize_name=name("resize"),size_name=name("size");resize_method[t]=builtin(t,&resize_name,848867239LL);size_method[t]=builtin(t,&size_name,3173160232LL);
        release_name(resize_name);release_name(size_name);if(!resize_method[t]||!size_method[t])return false;
    }
    GDExtensionClassCreationInfo5 info{};info.is_exposed=true;info.create_instance_func=create;info.free_instance_func=free_instance;register_class(library,&class_name,&parent_name,&info);
    const char* configure[]={"capacity","team_limit"};bind(CONFIGURE,"configure",configure);
    const char* spawn[]={"logical_id","team","kind","position","hp","radius"};bind(SPAWN,"spawn",spawn);
    const char* handle[]={"handle"};bind(DESPAWN,"despawn",handle);bind(VALID,"valid",handle);
    bind(CLEAR,"clear",nullptr);bind(SNAPSHOT,"snapshot",nullptr);bind(RENDER,"render_snapshot",nullptr);
    const char* query[]={"bounds","team"};bind(QUERY,"query_aabb",query);
    const char* query_actors[]={"bounds","actors","source","extras"};bind(QUERY_ACTORS,"ordered_enemy_candidates",query_actors);
    const char* points[]={"points","origin","radius"};bind(NEARBY_POINTS,"nearby_points",points);
    const char* step_profile[]={"reset"};bind(STEP_PROFILE,"simulation_profile",step_profile);
    const char* worker_step[]={"delta"};bind(BEGIN_STEP,"begin_step",worker_step);bind(FINISH_STEP,"finish_step",nullptr);
    const char* collectors[]={"player","defenders","workers","tower_height","pickup_height","magnet_radius"};bind(COLLECTORS,"collector_snapshot",collectors);
    const char* reset_stats[]={"reset"};bind(QUERY_STATS,"query_stats",reset_stats);
    const char* parallel[]={"enabled"};bind(PARALLEL_MOVEMENT,"set_parallel_movement",parallel);
    const char* mirrors[]={"defenders","posts"};bind(SYNC_HELPERS,"sync_helper_mirrors",mirrors);
    bind(CAPTURE_HELPERS,"capture_helper_snapshot",nullptr);const char* captured_helpers[]={"snapshot","defenders","posts"};bind(SNAPSHOT_HELPERS,"sync_helper_snapshot",captured_helpers);
    const char* registration[]={"handle","row","actor"};bind(REGISTER_FACADE,"register_facade",registration);
    const char* registered[]={"snapshot"};bind(SYNC_REGISTERED,"sync_registered_facades",registered);bind(SYNC_MODEL_ROWS,"sync_model_rows",nullptr);const char* model_handles[]={"handles"};bind(SYNC_MODEL_ROWS_FOR,"sync_model_rows_for",model_handles);
    const char* facades[]={"snapshot","rows","enemies","allies","view"};bind(SYNC_FACADES,"sync_facades",facades);
    const char* projectile_args[]={"snapshot","bullet_scale","limits"};bind(PROJECTILE_BUFFERS,"projectile_buffers",projectile_args);
    const char* instances[]={"snapshot","profiles"};bind(INSTANCE_BUFFERS,"instance_buffers",instances);
    const char* boxes[]={"minimums","maximums","minimum","maximum"};bind(FILTER_BOXES,"filter_boxes",boxes);
    const char* navigation[]={"data"};bind(NAVIGATION,"set_navigation",navigation);
    const char* reachable[]={"from","goal","radius"};bind(CAN_REACH,"can_reach",reachable);
    const char* goals[]={"handles","positions","speeds"};bind(GOALS,"set_goals",goals);
    const char* step[]={"delta"};bind(STEP,"step",step);
    const char* kits[]={"data"};bind(KITS,"configure_kits",kits);
    const char* hit[]={"handle","hit"};bind(HIT,"apply_hit",hit);
    const char* enemy_index[]={"rows","handles","supported_kinds"};bind(INDEX_ENEMIES,"index_enemy_rows",enemy_index);
    bind(EVENTS,"take_events",nullptr);
    bind(SCENE_EVENTS,"take_scene_events",nullptr);
    const char* targets[]={"targets"};bind(TARGETS,"set_targets",targets);bind(STATE,"unit_state",handle);
    const char* pose[]={"handle","position","yaw"};bind(POSE,"set_pose",pose);bind(REST,"rest_allies",nullptr);bind(GUARD,"set_guard",pose);bind(REST_TICK,"rest_tick",step);
    const char* mirror[]={"handle","actions","speed","reach","approach"};bind(MIRROR,"set_mirror",mirror);
    const char* busy[]={"handle","busy"};bind(MIRROR_BUSY,"set_mirror_busy",busy);
    const char* scaling[]={"handle","health_scale","damage_scale"};bind(ENEMY_SCALING,"set_enemy_scaling",scaling);return true;
}
void deinitialize(){unregister_class(library,&class_name);release_name(class_name);release_name(parent_name);release_name(sync_snapshot_name);release_name(sync_native_snapshot_name);release_name(sync_native_metadata_name);release_name(shared_snapshot_name);release_name(plain_snapshot_name);release_name(lazy_snapshot_name);release_name(event_health_name);release_name(hp_name);release_name(max_hp_name);release_name(velocity_name);}
}
