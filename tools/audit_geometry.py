import collections,json
import check_layout as c
n=0; fallback=collections.Counter()
def run(v,high=False):
 global n
 fallback.update(c.draw_page(v,high=high)); n+=1
for i in range(1000):
 v=c.sample.copy();v[6]=f'{i/10:.1f}';run(v)
for i in range(2501):
 v=c.sample.copy();v[7]=str(i);run(v)
 run(['99.9',str(i),'180','220','25:01:01'],True)
for i in range(-300,301):
 v=c.sample.copy();v[10]=f'{i/10:+.1f}';run(v)
for h in range(1,13):
 for m in range(60):
  v=c.sample.copy();v[0]=f'{h}:{m:02d}';run(v)
result={'pages':n,'geometry':'PASS','fallbacks_by_font_index':dict(fallback),'scope':'resource geometry, not native renderer or physical legibility'}
open('results/geometry-sweep.json','w').write(json.dumps(result,indent=2));print(result)
