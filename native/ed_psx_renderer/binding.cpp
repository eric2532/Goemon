// Godot 4.6 C-ABI binding; deliberately independent of the terrain extension binary.
#include "../terrain_math/gdextension_interface.h"
#include "rasterizer.h"
#include <cstring>

namespace {
using Type=GDExtensionVariantType;
constexpr Type NIL=GDEXTENSION_VARIANT_TYPE_NIL,INT=GDEXTENSION_VARIANT_TYPE_INT,
 BYTES=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,INTS=GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY;
struct alignas(8) Name {unsigned char bytes[8];};
struct alignas(8) String {unsigned char bytes[8];};
struct alignas(8) Packed {unsigned char bytes[16];};
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceVariantGetPtrConstructor constructor;
GDExtensionInterfaceVariantGetPtrDestructor destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantNewNil nil_new;
GDExtensionInterfaceClassdbConstructObject2 construct_object;
GDExtensionInterfaceObjectSetInstance set_instance;
GDExtensionInterfaceClassdbRegisterExtensionClass5 register_class;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfacePackedByteArrayOperatorIndexConst byte_read;
GDExtensionInterfacePackedByteArrayOperatorIndex byte_write;
GDExtensionInterfacePackedInt32ArrayOperatorIndexConst int_read;
GDExtensionPtrBuiltInMethod byte_size,int_size,byte_resize;
Name class_name,parent_name;
Name name(const char* text) {Name n;name_new(&n,text);return n;}
void release(Name& n) {destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&n);}
GDExtensionPtrBuiltInMethod method(Type t,const char* text,int64_t hash) {
 Name n=name(text);auto m=builtin(t,&n,hash);release(n);return m;
}
int64_t size(const void* p,GDExtensionPtrBuiltInMethod m) {int64_t result=0;m(const_cast<void*>(p),nullptr,&result,0);return result;}
void write_bytes(void* p,const std::vector<uint8_t>& data) {
 int64_t length=data.size(),error=0;const void* args[]={&length};byte_resize(p,args,&error,1);
 if(length)std::memcpy(byte_write(p,0),data.data(),data.size());
}
void ptrcall(void* userdata,void* instance,const void* const* args,void* ret) {
 auto& raster=*static_cast<ed_psx::Rasterizer*>(instance);
 if(intptr_t(userdata)==0) {
  auto n=size(args[2],byte_size),m=size(args[3],byte_size);
  auto w=*static_cast<const int64_t*>(args[0]),h=*static_cast<const int64_t*>(args[1]);
  raster.configure(w>=1&&w<=2048?int(w):0,h>=1&&h<=2048?int(h):0,n?byte_read(args[2],0):nullptr,n,m?byte_read(args[3],0):nullptr,m);
 } else {
  auto n=size(args[0],int_size);write_bytes(ret,raster.render(n?int_read(args[0],0):nullptr,n));
 }
}
const Type types[2][4]={{INT,INT,BYTES,BYTES},{INTS}};
const int counts[2]={4,1};
void call(void* userdata,void* instance,const void* const* args,GDExtensionInt argc,void* ret,GDExtensionCallError* error) {
 auto m=intptr_t(userdata);error->error=GDEXTENSION_CALL_OK;
 if(argc!=counts[m]) {error->error=argc<counts[m]?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=counts[m];nil_new(ret);return;}
 alignas(8) unsigned char storage[4][24]{};const void* converted[4]{};
 for(int i=0;i<argc;++i) {to_type(types[m][i])(storage[i],const_cast<void*>(args[i]));converted[i]=storage[i];}
 if(m==1) {Packed out;constructor(BYTES,0)(&out,nullptr);ptrcall(userdata,instance,converted,&out);from_type(BYTES)(ret,&out);destructor(BYTES)(&out);}
 else {ptrcall(userdata,instance,converted,nullptr);nil_new(ret);}
 for(int i=0;i<argc;++i)if(types[m][i]==BYTES||types[m][i]==INTS)destructor(types[m][i])(storage[i]);
}
GDExtensionObjectPtr create(void*,GDExtensionBool) {auto object=construct_object(&parent_name);set_instance(object,&class_name,new ed_psx::Rasterizer);return object;}
void free_instance(void*,void* instance) {delete static_cast<ed_psx::Rasterizer*>(instance);}
void bind(int id,const char* label,const char* const* labels) {
 Name method_name=name(label),empty=name("");String text;string_new(&text,"");
 Name names[4];GDExtensionPropertyInfo arguments[4]{};GDExtensionClassMethodArgumentMetadata metadata[4]{};
 for(int i=0;i<counts[id];++i) {names[i]=name(labels[i]);arguments[i]={types[id][i],&names[i],&empty,0,&text,6};}
 GDExtensionPropertyInfo output{id==1?BYTES:NIL,&empty,&empty,0,&text,6};
 GDExtensionClassMethodInfo info{};info.name=&method_name;info.method_userdata=reinterpret_cast<void*>(intptr_t(id));info.call_func=call;info.ptrcall_func=ptrcall;info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;info.has_return_value=id==1;info.return_value_info=&output;info.argument_count=counts[id];info.arguments_info=arguments;info.arguments_metadata=metadata;
 register_method(library,&class_name,&info);
 for(int i=0;i<counts[id];++i)release(names[i]);release(empty);release(method_name);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&text);
}
void initialize(void*,GDExtensionInitializationLevel level) {
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 class_name=name("EdPsxRasterizer");parent_name=name("RefCounted");
 byte_size=method(BYTES,"size",3173160232LL);int_size=method(INTS,"size",3173160232LL);byte_resize=method(BYTES,"resize",848867239LL);
 GDExtensionClassCreationInfo5 info{};info.is_exposed=true;info.create_instance_func=create;info.free_instance_func=free_instance;
 register_class(library,&class_name,&parent_name,&info);
 const char* config[]={"width","height","indices","palettes"};bind(0,"configure",config);
 const char* render[]={"triangles"};bind(1,"render",render);
}
void deinitialize(void*,GDExtensionInitializationLevel level) {
 if(level==GDEXTENSION_INITIALIZATION_SCENE) {unregister_class(library,&class_name);release(class_name);release(parent_name);}
}
}
extern "C" __attribute__((visibility("default"))) GDExtensionBool ed_psx_renderer_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init) {
 library=lib;
 #define LOAD(variable,type,symbol) variable=reinterpret_cast<type>(get_proc(symbol));if(!variable)return false
 LOAD(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");
 LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");
 LOAD(constructor,GDExtensionInterfaceVariantGetPtrConstructor,"variant_get_ptr_constructor");
 LOAD(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");
 LOAD(builtin,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");
 LOAD(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");
 LOAD(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");
 LOAD(nil_new,GDExtensionInterfaceVariantNewNil,"variant_new_nil");
 LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject2,"classdb_construct_object2");
 LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");
 LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass5,"classdb_register_extension_class5");
 LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
 LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");
 LOAD(byte_read,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");
 LOAD(byte_write,GDExtensionInterfacePackedByteArrayOperatorIndex,"packed_byte_array_operator_index");
 LOAD(int_read,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");
 #undef LOAD
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return true;
}
