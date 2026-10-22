// Small Godot 4.6 GDExtension C-ABI adapter. No godot-cpp dependency.
#include "gdextension_interface.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <vector>
#include <unordered_set>

namespace army_binding {
bool initialize(GDExtensionInterfaceGetProcAddress,GDExtensionClassLibraryPtr);
void deinitialize();
}

namespace {
using VT=GDExtensionVariantType;
constexpr VT NIL=GDEXTENSION_VARIANT_TYPE_NIL, BOOL=GDEXTENSION_VARIANT_TYPE_BOOL,
 INT=GDEXTENSION_VARIANT_TYPE_INT, FLOAT=GDEXTENSION_VARIANT_TYPE_FLOAT,
 VEC2=GDEXTENSION_VARIANT_TYPE_VECTOR2, VEC3=GDEXTENSION_VARIANT_TYPE_VECTOR3, BYTES=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,
 FLOATS=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
 VECS2=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY, VECS3=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY;
struct V2 { float x,z; };
struct V3 { float x,y,z; };
struct alignas(8) Packed { unsigned char data[16]; };
struct alignas(8) Name { unsigned char data[8]; };
struct alignas(8) String { unsigned char data[8]; };
struct alignas(8) Variant { unsigned char data[24]; };
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceGetProcAddress proc;
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
GDExtensionInterfacePackedByteArrayOperatorIndexConst byte_data;
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst float_data;
GDExtensionInterfacePackedVector2ArrayOperatorIndexConst vec2_data;
GDExtensionInterfacePackedVector3ArrayOperatorIndexConst vec3_data;
GDExtensionInterfacePackedVector3ArrayOperatorIndex vec3_write;
Name class_name,parent_name;
GDExtensionPtrBuiltInMethod array_size[40]{},array_resize;
Name make_name(const char* s) { Name n;name_new(&n,s);return n; }
void destroy_name(Name& n) { destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&n); }
GDExtensionPtrBuiltInMethod method(VT t,const char* s,int64_t hash) {
 Name n=make_name(s);auto result=builtin(t,&n,hash);destroy_name(n);return result;
}
int64_t size(VT t,const void* p) { int64_t n=0;array_size[t](const_cast<void*>(p),nullptr,&n,0);return n; }
void write_points(void* packed,const std::vector<V3>& points) {
 int64_t n=points.size(),error=0;const void* args[]={&n};array_resize(packed,args,&error,1);
 if(n) std::memcpy(vec3_write(packed,0),points.data(),points.size()*sizeof(V3));
}
float length2(float x,float z) { return std::sqrt(x*x+z*z); }
float length3(float x,float y,float z) { return std::sqrt(x*x+y*y+z*z); }
uint64_t cell_key(int64_t x,int64_t z) { return (uint64_t(uint32_t(x))<<32)|uint32_t(z); }
struct Terrain {
 int width=0;float spacing=3.0f;
 double origin=240.0;V2 minimum{-243.0f,-243.0f},maximum{237.0f,237.0f};
 bool rect_bounds=false;
 std::vector<float> heights;std::vector<uint8_t> covered;
 std::vector<V2> trees;std::unordered_set<uint64_t> roads;std::vector<V3> walls;
 void configure(int64_t w,double s,const void* h,const void* c) {
  width=(w>=2 && w<=32768)?int(w):0;spacing=float(s);
  int64_t hn=size(FLOATS,h),cn=size(BYTES,c);
  if(hn) heights.assign(float_data(h,0),float_data(h,0)+hn);else heights.clear();
  if(cn) covered.assign(byte_data(c,0),byte_data(c,0)+cn);else covered.clear();
  if(!std::isfinite(spacing)||spacing<=0||int64_t(width)*width>hn||int64_t(width)*width>cn)width=0;
 }
 void obstacles(const void* t,const void* r,const void* w) {
  auto tn=size(VECS2,t),rn=size(VECS2,r),wn=size(VECS3,w);
  if(tn) {auto p=static_cast<const V2*>(vec2_data(t,0));trees.assign(p,p+tn);} else trees.clear();
  roads.clear();roads.reserve(rn);if(rn) {auto p=static_cast<const V2*>(vec2_data(r,0));for(int64_t i=0;i<rn;++i)roads.insert(cell_key(int64_t(p[i].x),int64_t(p[i].z)));}
  if(wn) {auto p=static_cast<const V3*>(vec3_data(w,0));walls.assign(p,p+wn);} else walls.clear();
 }
 // Coordinates intentionally round at Vector2 construction and scalar division.
 V2 coordinate(double x,double z) const {return {float(x+origin)/spacing,float(z+origin)/spacing};}
 double value(int ix,int iz,double u,double v) const {
  auto at=iz*width+ix;
  double h00=heights[at],h10=heights[at+1],h01=heights[at+width],h11=heights[at+width+1];
  return u+v<=1.0 ? h00+(h10-h00)*u+(h01-h00)*v : h11+(h01-h11)*(1.0-u)+(h10-h11)*(1.0-v);
 }
 double height(double x,double z) const {
  if(width<2)return 0;
  auto p=coordinate(x,z);int ix=std::clamp(int(std::floor(p.x)),0,width-2),iz=std::clamp(int(std::floor(p.z)),0,width-2);
  return value(ix,iz,std::clamp(double(p.x)-ix,0.0,1.0),std::clamp(double(p.z)-iz,0.0,1.0));
 }
 double covered_height(double x,double z) const {
  if(width<2)return NAN;
  auto p=coordinate(x,z);int ix=int(std::floor(p.x)),iz=int(std::floor(p.z));
  if(ix<0||iz<0||ix>=width-1||iz>=width-1)return NAN;
  int at=iz*width+ix;
  if(!covered[at]||!covered[at+1]||!covered[at+width]||!covered[at+width+1])return NAN;
  return value(ix,iz,std::clamp(double(p.x)-ix,0.0,1.0),std::clamp(double(p.z)-iz,0.0,1.0));
 }
 bool disk_clear(const V3& p,double r) const {
  double center=covered_height(p.x,p.z);if(std::isnan(center))return false;
  const V2 axes[]={{1,0},{-1,0},{0,-1},{0,1},{.707f,.707f},{-.707f,.707f},{.707f,-.707f},{-.707f,-.707f}};
  double tolerance=.15+r*.35;
  for(const auto& a:axes) {double h=covered_height(double(p.x)+double(a.x)*r,double(p.z)+double(a.z)*r);if(std::isnan(h)||std::abs(h-center)>tolerance)return false;}
  return true;
 }
 bool terrain_obstacles_clear(const V3& p,double r) const {
  if(r>=8.5)r=14.0;
  if(rect_bounds) {
   // Match Rect2.grow(-r).has_point(), including float32 intermediates.
   float rf=float(r),x=minimum.x+rf,z=minimum.z+rf;
   float sx=(maximum.x-minimum.x)-rf*2.0f,sz=(maximum.z-minimum.z)-rf*2.0f;
   if(p.x<x||p.z<z||p.x>=x+sx||p.z>=z+sz)return false;
  } else if(double(p.x)-r < minimum.x||double(p.z)-r < minimum.z||double(p.x)+r>maximum.x||double(p.z)+r>maximum.z)return false;
  for(auto t:trees) {float dx=float(std::max(0.0,std::abs(double(p.x)-t.x)-1.25)),dz=float(std::max(0.0,std::abs(double(p.z)-t.z)-1.25));if(length2(dx,dz)<r+.05)return false;}
  return true;
 }
 bool on_road(const V3& p,double r) const {
  float rf=float(r);const V2 offsets[]={{0,0},{1,0},{-1,0},{0,-1},{0,1}};
  for(auto a:offsets) {float x=p.x+a.x*rf,z=p.z+a.z*rf;if(!roads.count(cell_key(int64_t(std::round(double(x)/6.0)),int64_t(std::round(double(z)/6.0)))))return false;}
  return true;
 }
 std::vector<V3> sample(V3 from,V3 to,double radius,double step_spacing,bool horizontal,bool road) const {
  std::vector<V3> result;
  if(width<2||!std::isfinite(step_spacing)||step_spacing<=0)return result;
  float dx=to.x-from.x,dy=to.y-from.y,dz=to.z-from.z;
  double distance=horizontal?length2(dx,dz):length3(dx,dy,dz);
  double count=std::max(1.0,std::ceil(distance/step_spacing));
  if(!std::isfinite(count)||count>10000000)return result;
  int steps=int(count);result.reserve(steps);V3 previous=from;
  double previous_height=height(from.x,from.z),field_radius=radius>=8.5?14.75:radius;
  for(int i=1;i<=steps;++i) {
   float weight=float(double(i)/steps);
   V3 p={from.x+dx*weight,from.y+dy*weight,from.z+dz*weight};
   double h=height(p.x,p.z);p.y=float(h);
   float travel=length2(p.x-previous.x,p.z-previous.z);
   if(!(std::abs(h-previous_height)<=.15+double(travel)*.35)||!disk_clear(p,field_radius)||!terrain_obstacles_clear(p,radius)||(road&&!on_road(p,radius))) {result.clear();return result;}
   result.push_back(p);previous=p;previous_height=h;
  }
  return result;
 }
 bool walls_clear(const void* points,double radius) const {
  int64_t n=size(VECS3,points);if(!n||walls.empty())return true;
  auto p=static_cast<const V3*>(vec3_data(points,0));
  for(int64_t i=0;i<n;++i)for(size_t j=0;j+1<walls.size();j+=2) {
   const auto& a=walls[j];const auto& b=walls[j+1];
   float x=std::clamp(p[i].x,a.x,b.x),z=std::clamp(p[i].z,a.z,b.z);
   if(length3(p[i].x-x,p[i].y-a.y,p[i].z-z)<radius+.05)return false;
  }
  return true;
 }
};
enum Method { CONFIGURE,OBSTACLES,SAMPLE,WALLS,WORLD_DOMAIN };
void ptrcall(void* userdata,void* instance,const void* const* args,void* ret) {
 auto& t=*static_cast<Terrain*>(instance);
 switch(intptr_t(userdata)) {
  case CONFIGURE:t.configure(*static_cast<const int64_t*>(args[0]),*static_cast<const double*>(args[1]),args[2],args[3]);break;
  case OBSTACLES:t.obstacles(args[0],args[1],args[2]);break;
  case SAMPLE:write_points(ret,t.sample(*static_cast<const V3*>(args[0]),*static_cast<const V3*>(args[1]),*static_cast<const double*>(args[2]),*static_cast<const double*>(args[3]),*static_cast<const GDExtensionBool*>(args[4]),*static_cast<const GDExtensionBool*>(args[5])));break;
  case WALLS:*static_cast<GDExtensionBool*>(ret)=t.walls_clear(args[0],*static_cast<const double*>(args[1]));break;
  case WORLD_DOMAIN:t.origin=*static_cast<const double*>(args[0]);t.minimum=*static_cast<const V2*>(args[1]);t.maximum=*static_cast<const V2*>(args[2]);t.rect_bounds=*static_cast<const GDExtensionBool*>(args[3]);break;
 }
}
const VT arg_types[5][6]={{INT,FLOAT,FLOATS,BYTES},{VECS2,VECS2,VECS3},{VEC3,VEC3,FLOAT,FLOAT,BOOL,BOOL},{VECS3,FLOAT},{FLOAT,VEC2,VEC2,BOOL}};
const int arg_counts[]={4,3,6,2,4};
void call(void* userdata,void* instance,const void* const* args,GDExtensionInt argc,void* ret,GDExtensionCallError* error) {
 auto m=intptr_t(userdata);error->error=GDEXTENSION_CALL_OK;
 if(argc!=arg_counts[m]) {error->error=argc<arg_counts[m]?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=arg_counts[m];nil_new(ret);return;}
 alignas(8) unsigned char storage[6][24]{};const void* converted[6]{};
 for(int i=0;i<argc;++i) {to_type(arg_types[m][i])(storage[i],const_cast<void*>(args[i]));converted[i]=storage[i];}
 if(m==SAMPLE) {Packed packed;constructor(VECS3,0)(&packed,nullptr);ptrcall(userdata,instance,converted,&packed);from_type(VECS3)(ret,&packed);destructor(VECS3)(&packed);}
 else if(m==WALLS) {GDExtensionBool result=false;ptrcall(userdata,instance,converted,&result);from_type(BOOL)(ret,&result);}
 else {ptrcall(userdata,instance,converted,nullptr);nil_new(ret);}
 for(int i=0;i<argc;++i)if(arg_types[m][i]>=BYTES)destructor(arg_types[m][i])(storage[i]);
}
GDExtensionObjectPtr create(void*,GDExtensionBool) {auto object=construct_object(&parent_name);set_instance(object,&class_name,new Terrain);return object;}
void free_instance(void*,void* instance) {delete static_cast<Terrain*>(instance);}
void bind_method(int m,const char* name,VT return_type,const char* const* names) {
 Name method_name=make_name(name);Name empty_name=make_name("");String empty_string;string_new(&empty_string,"");
 Name argument_names[6];GDExtensionPropertyInfo args[6]{};GDExtensionClassMethodArgumentMetadata metadata[6]{};
 for(int i=0;i<arg_counts[m];++i) {argument_names[i]=make_name(names[i]);args[i]={arg_types[m][i],&argument_names[i],&empty_name,0,&empty_string,6};metadata[i]=arg_types[m][i]==FLOAT?GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE:GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;}
 GDExtensionPropertyInfo output{return_type,&empty_name,&empty_name,0,&empty_string,6};
 GDExtensionClassMethodInfo info{};info.name=&method_name;info.method_userdata=reinterpret_cast<void*>(intptr_t(m));info.call_func=call;info.ptrcall_func=ptrcall;info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;info.has_return_value=return_type!=NIL;info.return_value_info=&output;info.argument_count=arg_counts[m];info.arguments_info=args;info.arguments_metadata=metadata;
 register_method(library,&class_name,&info);
 for(int i=0;i<arg_counts[m];++i)destroy_name(argument_names[i]);destroy_name(empty_name);destroy_name(method_name);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
void initialize(void*,GDExtensionInitializationLevel level) {
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 class_name=make_name("GoemonTerrainMath");parent_name=make_name("RefCounted");
 for(auto t:{BYTES,FLOATS,VECS2,VECS3})array_size[t]=method(t,"size",3173160232LL);
 array_resize=method(VECS3,"resize",848867239LL);
 GDExtensionClassCreationInfo5 info{};info.is_exposed=true;info.create_instance_func=create;info.free_instance_func=free_instance;
 register_class(library,&class_name,&parent_name,&info);
 const char* config[]={"width","spacing","heights","covered"};bind_method(CONFIGURE,"configure_field",NIL,config);
 const char* obstacles[]={"trees","roads","walls"};bind_method(OBSTACLES,"set_obstacles",NIL,obstacles);
 const char* sample[]={"from","to","radius","spacing","horizontal","on_road"};bind_method(SAMPLE,"sample",VECS3,sample);
 const char* walls[]={"points","radius"};bind_method(WALLS,"walls_clear",BOOL,walls);
 const char* domain[]={"origin","minimum","maximum","rect_bounds"};bind_method(WORLD_DOMAIN,"set_domain",NIL,domain);
 army_binding::initialize(proc,library);
}
void deinitialize(void*,GDExtensionInitializationLevel level) {if(level==GDEXTENSION_INITIALIZATION_SCENE){army_binding::deinitialize();unregister_class(library,&class_name);destroy_name(class_name);destroy_name(parent_name);}}
}
extern "C" __attribute__((visibility("default"))) GDExtensionBool goemon_terrain_math_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init) {
 proc=get_proc;library=lib;
 #define LOAD(variable,type,symbol) variable=reinterpret_cast<type>(proc(symbol));if(!variable)return false
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
 LOAD(byte_data,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");
 LOAD(float_data,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");
 LOAD(vec2_data,GDExtensionInterfacePackedVector2ArrayOperatorIndexConst,"packed_vector2_array_operator_index_const");
 LOAD(vec3_data,GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,"packed_vector3_array_operator_index_const");
 LOAD(vec3_write,GDExtensionInterfacePackedVector3ArrayOperatorIndex,"packed_vector3_array_operator_index");
 #undef LOAD
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return true;
}
