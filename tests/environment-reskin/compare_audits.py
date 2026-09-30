"""Fail on any changed terrain, collision, bounds, outposts or RNG state."""
import json,sys
from pathlib import Path
folder=Path(__file__).parent
before=json.loads((folder/(sys.argv[1] if len(sys.argv)>1 else 'baseline-fixed-audit.json')).read_text())
after=json.loads((folder/(sys.argv[2] if len(sys.argv)>2 else 'final-audit.json')).read_text())
for area in before:
    for key in before[area]:
        assert before[area][key]==after[area][key],f'Area {area}: {key} changed'
    print(f'PASS area {area}: {len(before[area]["collisions"])} exact collision shapes; heights, bounds, outposts and RNG state identical')
print('ENVIRONMENT_PRESERVATION_PASS')
