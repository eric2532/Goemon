"""Prepare a reviewable support patch and isolated copies; never edits shared owners."""
import difflib
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Native Support Proof'


def replace_once(source, old, new):
    assert source.count(old) == 1, ('Shared source changed; review before regenerating', old[:100])
    return source.replace(old, new, 1)


def candidate(path, source):
    if path.endswith('terrain.h'):
        return replace_once(source, '    std::unordered_map<uint64_t,std::vector<int>> obstacle_grid_;',
                            '    std::unordered_map<uint64_t,std::vector<size_t>> piece_grid_;\n    std::vector<std::array<float,4>> piece_bounds_;\n    mutable std::vector<uint32_t> piece_visited_;\n    mutable uint32_t piece_visit_=0;\n    std::unordered_map<uint64_t,std::vector<int>> obstacle_grid_;')
    if path.endswith('terrain.cpp'):
        insertion = '''    if(!same_surface){
        piece_grid_.clear();piece_bounds_.clear();piece_visited_.assign(data_.pieces.size()/10,0);piece_visit_=0;
        for(size_t i=0;i<data_.pieces.size();i+=10){
            const float* p=data_.pieces.data()+i;
            bool valid=true;for(int n=0;n<10;++n)valid=valid&&std::isfinite(p[n]);
            if(!valid)continue;
            if(p[4]<0||p[5]<=0||p[6]>p[7])continue;
            float length2=p[2]*p[2]+p[3]*p[3];
            float lo_x=minimum_.x,lo_z=minimum_.z,hi_x=maximum_.x,hi_z=maximum_.z;
            if(length2>0&&std::isfinite(length2)){
                float ax=p[0]+p[2]*p[6]/length2,az=p[1]+p[3]*p[6]/length2;
                float bx=p[0]+p[2]*p[7]/length2,bz=p[1]+p[3]*p[7]/length2;
                float tolerance=.002f/std::sqrt(length2);
                float pad_x=std::abs(p[3])*p[4]/length2+tolerance,pad_z=std::abs(p[2])*p[4]/length2+tolerance;
                lo_x=std::max(minimum_.x,std::min(ax,bx)-pad_x);hi_x=std::min(maximum_.x,std::max(ax,bx)+pad_x);
                lo_z=std::max(minimum_.z,std::min(az,bz)-pad_z);hi_z=std::min(maximum_.z,std::max(az,bz)+pad_z);
            }else if(!std::isfinite(length2)||p[6]>0||p[7]<0)continue;
            if(!std::isfinite(lo_x)||!std::isfinite(lo_z)||!std::isfinite(hi_x)||!std::isfinite(hi_z)||lo_x>hi_x||lo_z>hi_z)continue;
            piece_bounds_.push_back({lo_x,lo_z,hi_x,hi_z});
            for(int x=int(std::floor(lo_x/OBSTACLE_CELL));x<=int(std::floor(hi_x/OBSTACLE_CELL));++x)
                for(int z=int(std::floor(lo_z/OBSTACLE_CELL));z<=int(std::floor(hi_z/OBSTACLE_CELL));++z)piece_grid_[key(x,z)].push_back(i);
        }
    }
'''
        source = replace_once(source, '    // A triangle stays inside its vertex range.', insertion+'    // A triangle stays inside its vertex range.')
        source = replace_once(source, 'if(!same_surface&&data_.width>0&&data_.pieces.empty())', 'if(!same_surface&&data_.width>0)')
        source = replace_once(source, '''            if(covered)field_spans_[size_t(z)*w+x]=high-low+1e-6*(1+std::max(std::abs(low),std::abs(high)));
        }
    }
    for(size_t i=0;i<data_.obstacle_min.size();++i){''', '''            if(covered)field_spans_[size_t(z)*w+x]=high-low+1e-6*(1+std::max(std::abs(low),std::abs(high)));
        }
        // Exact piece sampling is required only near explicit support; retain
        // the existing flat-field certificate everywhere else.
        for(const auto& box:piece_bounds_){
            int x0=std::max(0,int(std::floor((box[0]-data_.origin.x)/data_.spacing))-4);
            int z0=std::max(0,int(std::floor((box[1]-data_.origin.z)/data_.spacing))-4);
            int x1=std::min(w-1,int(std::ceil((box[2]-data_.origin.x)/data_.spacing))+3);
            int z1=std::min(w-1,int(std::ceil((box[3]-data_.origin.z)/data_.spacing))+3);
            for(int z=z0;z<=z1;++z)for(int x=x0;x<=x1;++x)field_spans_[size_t(z)*w+x]=INFINITY;
        }
    }
    for(size_t i=0;i<data_.obstacle_min.size();++i){''')
        source = replace_once(source, '    double result=0;\n    if(data_.width>0){', '    double result=0;bool uncovered=false;\n    if(data_.width>0){')
        source = replace_once(source, '''        if(!data_.covered[at]||!data_.covered[at+1]||!data_.covered[at+data_.width]||!data_.covered[at+data_.width+1])return NAN;
        double u=std::clamp(double(px)-ix,0.0,1.0),v=std::clamp(double(pz)-iz,0.0,1.0);
        double h00=data_.heights[at],h10=data_.heights[at+1],h01=data_.heights[at+data_.width],h11=data_.heights[at+data_.width+1];
        result=u+v<=1?h00+(h10-h00)*u+(h01-h00)*v:h11+(h01-h11)*(1-u)+(h10-h11)*(1-v);
    }
    for(size_t i=0;i<data_.pieces.size();i+=10){''', '''        uncovered=!data_.covered[at]||!data_.covered[at+1]||!data_.covered[at+data_.width]||!data_.covered[at+data_.width+1];
        if(uncovered)result=NAN;
        else{
            double u=std::clamp(double(px)-ix,0.0,1.0),v=std::clamp(double(pz)-iz,0.0,1.0);
            double h00=data_.heights[at],h10=data_.heights[at+1],h01=data_.heights[at+data_.width],h11=data_.heights[at+data_.width+1];
            result=u+v<=1?h00+(h10-h00)*u+(h01-h00)*v:h11+(h01-h11)*(1-u)+(h10-h11)*(1-v);
        }
    }
    auto found=piece_grid_.find(key(int(std::floor(x/OBSTACLE_CELL)),int(std::floor(z/OBSTACLE_CELL))));
    if(found==piece_grid_.end())return result;
    for(size_t i:found->second){''')
        source = replace_once(source, '        result=std::max(result,double(p[8])+(double(p[9])-p[8])*std::clamp(double(along)/p[5],0.0,1.0));',
                              '        double top=double(p[8])+(double(p[9])-p[8])*std::clamp(double(along)/p[5],0.0,1.0);\n        if(!std::isfinite(top))continue;\n        result=uncovered?top:std::max(result,top);uncovered=false;')
        source = replace_once(source, '''    }
    return true;
}
bool Terrain::prepare_routes''', '''    }
    if(layer<=0&&!piece_grid_.empty()&&!certified){
        // Fine source lips may be narrower than the ordinary .7m interval.
        // Test their exact boundaries using local buckets, without allocating
        // candidate lists or scanning every prepared support piece.
        if(++piece_visit_==0){std::fill(piece_visited_.begin(),piece_visited_.end(),0);piece_visit_=1;}
        Vec3 offsets[9]{};for(int i=0;i<8;++i)offsets[i+1]=axes[i]*radius;
        int x0=int(std::floor(std::max(minimum_.x,std::min(from.x,to.x)-radius-.002f)/OBSTACLE_CELL));
        int z0=int(std::floor(std::max(minimum_.z,std::min(from.z,to.z)-radius-.002f)/OBSTACLE_CELL));
        int x1=int(std::floor(std::min(maximum_.x,std::max(from.x,to.x)+radius+.002f)/OBSTACLE_CELL));
        int z1=int(std::floor(std::min(maximum_.z,std::max(from.z,to.z)+radius+.002f)/OBSTACLE_CELL));
        for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z){
            auto bucket=piece_grid_.find(key(x,z));if(bucket==piece_grid_.end())continue;
            for(size_t index:bucket->second){
                if(piece_visited_[index/10]==piece_visit_)continue;piece_visited_[index/10]=piece_visit_;
                const float* piece=data_.pieces.data()+index;
                for(int sample=0;sample<9;++sample)for(int axis=0;axis<2;++axis){
                    Vec3 offset=offsets[sample];
                    auto coordinate=[&](Vec3 p){float ox=p.x+offset.x-piece[0],oz=p.z+offset.z-piece[1];return axis?double(-ox*piece[3]+oz*piece[2]):double(ox*piece[2]+oz*piece[3]);};
                    double a=coordinate(from),b=coordinate(to);if(std::abs(b-a)<1e-12)continue;
                    double edges[]{axis?-piece[4]-.001:piece[6]-.001,axis?piece[4]+.001:piece[7]+.001};
                    for(double edge:edges){
                        double t=(edge-a)/(b-a);if(t<=0||t>=1)continue;
                        double epsilon=.00005/std::abs(b-a);double old_height=NAN;Vec3 old_point{};
                        for(double at:{std::max(0.0,t-epsilon),std::min(1.0,t+epsilon)}){
                            Vec3 p=from+(to-from)*float(at);double center=height(p.x,p.z,layer);
                            if(!std::isfinite(center))return false;
                            if(sample==0){
                                if(!clear(p,radius,layer,check_objects))return false;
                                if(std::isfinite(old_height)&&std::abs(center-old_height)>.15+std::hypot(p.x-old_point.x,p.z-old_point.z)*.35)return false;
                                old_height=center;old_point=p;
                            }else{
                                double foot=height(p.x+offset.x,p.z+offset.z,layer);
                                if(!std::isfinite(foot)||std::abs(foot-center)>.15+radius*.35)return false;
                            }
                        }
                    }
                }
            }
        }
    }
    return true;
}
bool Terrain::prepare_routes''')
        return source
    if path.endswith('forest_ramparts.gd'):
        insertion = '''func piece_height(x:float,z:float)->float:
 # Explicit prepared floors may supply support over an otherwise uncovered cell.
 var p=Vector2(x,z);var result=NAN
 for piece in height_buckets.get(Vector2i(floori(x/BUCKET_SIZE),floori(z/BUCKET_SIZE)),NO_PIECES):
  var offset=p-piece.a;var u=offset.dot(piece.along)
  if u<piece.start-.001 or u>piece.end+.001 or absf(offset.dot(piece.side))>piece.half+.001:continue
  var top=lerpf(piece.h0,piece.h1,clampf(u/piece.length,0.,1.))
  if not is_finite(top):continue
  result=top if is_nan(result) else maxf(result,top)
 return result
'''
        return replace_once(source, 'func disk_clear(point: Vector3,radius: float)->bool:', insertion+'func disk_clear(point: Vector3,radius: float)->bool:')
    if path.endswith('forest_kai_terrain.gd'):
        source = replace_once(source, ' return covered[offset]!=0 and covered[offset+1]!=0 and covered[offset+width]!=0 and covered[offset+width+1]!=0',
                              ' return (covered[offset]!=0 and covered[offset+1]!=0 and covered[offset+width]!=0 and covered[offset+width+1]!=0) or not is_nan(super.piece_height(x,z))')
        return replace_once(source, ' if covered[at]==0 or covered[at+1]==0 or covered[at+width]==0 or covered[at+width+1]==0:return NAN',
                            ' if covered[at]==0 or covered[at+1]==0 or covered[at+width]==0 or covered[at+width+1]==0:return super.piece_height(x,z)')
    return source


def main():
    paths = ['native/terrain_math/crowd/terrain.h', 'native/terrain_math/crowd/terrain.cpp', 'native/terrain_math/crowd/air.cpp', 'native/terrain_math/crowd/math_types.h',
             'scripts/forest/forest_ramparts.gd', 'scripts/forest/forest_kai_terrain.gd']
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch(); hashes, patch = {}, []
    if '--cases-only' in sys.argv:
        write_cases()
        return
    for path in paths:
        old = (ROOT/path).read_text(); new = candidate(path, old); hashes[path] = hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
        patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/'+path, tofile='b/'+path))
        if path.endswith(('.h', '.cpp')):
            for folder, value in [('current', old), ('candidate', new)]:
                target = OUT/folder/Path(path).name; target.parent.mkdir(exist_ok=True); target.write_text(value)
        elif path.endswith('.gd'):
            target = OUT/'kai-candidate'/path; target.parent.mkdir(parents=True, exist_ok=True); target.write_text(new)
    (OUT/'kai-candidate/project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated source cap parser"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Godot/app_userdata/Azure Ember"\n')
    (OUT/'source-bank-support.patch').write_text(''.join(patch))
    (OUT/'shared-source-before.json').write_text(json.dumps(hashes, indent=2)+'\n')
    write_cases()
    print('Prepared isolated current/candidate native source and review patch; shared Native/Kai/Ramparts remain untouched.')


def write_cases():
    caps = json.loads((ROOT/'assets/maps/falan/east_region/bank_caps/data.json').read_text())['graphics']
    data = json.loads((ROOT/'assets/maps/falan/east_region/il_source_completion/data.json').read_text())
    rows = data['additional_scenery_rows']
    source_rows = {tuple(row['source_cell']): row for row in data['new_bank_caps']}
    lines = ['#include <array>\n#include <vector>\nstruct BankCase{int serial,x,z;float sx,sz,entry_radius;std::vector<std::array<float,4>> rects;std::array<float,4> join;bool source_dry_west;int source_land_z;float source_sx,source_sz;};\nstatic std::vector<BankCase> bank_cases{\n']
    for x, z, serial, _ in rows:
        row = caps[str(serial)]; approach = row['approaches']['west']
        rects = ','.join('{{'+','.join(f'{float(v):.7f}f' for v in rect)+'}}' for rect in row['support_rects'])
        join = '{{'+','.join(f'{float(v):.7f}f' for v in approach['join_rect'])+'}}'
        source = source_rows[(x, z)]
        lines.append('{'+f'{serial},{x},{z},{approach["stand"][0]:.7f}f,{approach["stand"][1]:.7f}f,{approach["entry_radius_local"]:.7f}f,'+'{'+rects+'},'+join+','+str(source['source_dry_neighbor']['dry_land']).lower()+','+str(source['source_approach_land']['cell'][1])+','+','.join(f'{v:.7f}f' for v in source['source_stand'])+'},\n')
    lines.append('};\n'); (OUT/'bank-cap-cases.h').write_text(''.join(lines))
    print('Prepared exact source bank case header only; preserved current/candidate source snapshots and published patch.')


if __name__ == '__main__': main()
