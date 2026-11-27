"""Revalidate the inspected717-map BG bank after source-only layout publications."""
import hashlib,json
from collections import Counter
from review_east_backgrounds import ROOT,OUT,CATALOG,Native,decode,overview

REPORT=OUT/'Current Source Revalidation'
def sha(data):return hashlib.sha256(data).hexdigest()
def run():
    census=json.loads((OUT/'census.json').read_text());classification=json.loads((OUT/'classification.json').read_text())
    previous={r['map']:r for r in census['maps']};decisions={r['map']:r for r in classification['maps']}
    roles={r['graphic']:r['classification'] for r in classification['graphics']}
    old_fg={g['graphic'] for r in census['maps'] for g in r['layer1_graphics']}
    catalog=json.loads(CATALOG.read_text());changed=[];coverage=[];unclassified=set();new_objects=set();native=None
    REPORT.mkdir(exist_ok=True);(REPORT/'.gdignore').touch()
    for row in catalog['maps'].values():
        mid=row['id'];w,h,raw,values,bits,aliases=decode(row);n=w*h;raw_sha=sha(raw)
        bg=Counter();fg=Counter()
        for s,count in Counter(values[:n]).items():
            if s>=1000:bg[aliases.get(s,s)]+=count
        for s,count in Counter(values[n:]).items():
            if s>=1000:fg[aliases.get(s,s)]+=count
        unknown=set(bg)-roles.keys();unclassified.update(unknown);new_objects.update(set(fg)-old_fg)
        coverage.append(dict(map=mid,active_raw_sha256=raw_sha,all_bg_native_ids_previously_inspected=not unknown,
            baseline_raw_unchanged=raw_sha==previous[mid]['source_raw_sha256'],prior_large_body_negative=decisions[mid]['large_BG_body_negative']))
        if raw_sha==previous[mid]['source_raw_sha256']:continue
        old_bg={g['graphic']:g['count'] for g in previous[mid]['layer0_graphics']}
        before_roles={roles[g] for g in old_bg};after_roles={roles.get(g,'UNREVIEWED') for g in bg}
        if native is None:native=Native()
        a,b=overview(native,w,h,values,aliases);a.save(REPORT/f'{mid}-bg.jpg',quality=92);b.save(REPORT/f'{mid}-both.jpg',quality=92)
        changed.append(dict(map=mid,title=row['title'],old_raw_sha256=previous[mid]['source_raw_sha256'],active_raw_sha256=raw_sha,
            added_bg_native_ids=sorted(set(bg)-old_bg.keys()),unclassified_bg_native_ids=sorted(unknown),added_object_ids_to_previous_full_corpus=sorted(set(fg)-old_fg),
            prior_bg_roles=sorted(before_roles),current_bg_roles=sorted(after_roles),same_inspected_role_set=before_roles==after_roles,
            prior_large_body_negative=decisions[mid]['large_BG_body_negative'],current_bg_counts=bg,current_object_counts=fg,
            visual_review='Fresh active-plane BG/combined overview prepared; inspection required before retaining the prior negative classification.'))
    report=dict(scope='Read-only revalidation; historical census/classification/contact images remain unchanged. No runtime/map/art mutation.',
        historical_census_sha256=sha((OUT/'census.json').read_bytes()),historical_classification_sha256=sha((OUT/'classification.json').read_bytes()),
        current_catalog_sha256=sha(CATALOG.read_bytes()),maps=len(coverage),changed_maps=changed,new_unclassified_bg_native_ids=sorted(unclassified),
        object_ids_new_to_previous_full_fixed_corpus=sorted(new_objects),coverage=coverage)
    (REPORT/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('BG_SOURCE_REVALIDATION maps=',len(coverage),'changed=',[r['map'] for r in changed],'unclassifiedBG=',sorted(unclassified),'newPG1=',sorted(new_objects))
if __name__=='__main__':run()
