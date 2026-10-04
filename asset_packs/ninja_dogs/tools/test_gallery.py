import json,threading,http.server,functools
from pathlib import Path
from playwright.sync_api import sync_playwright
P=Path(__file__).resolve().parents[1]
server=http.server.ThreadingHTTPServer(('127.0.0.1',8775),functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(P/'gallery')))
threading.Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);page=browser.new_page(viewport={'width':1440,'height':1000});errors=[];page.on('pageerror',lambda e:errors.append(str(e)));page.goto('http://127.0.0.1:8775');buttons=page.locator('#dogs button');assert buttons.count()==10
 for i in range(10):
  buttons.nth(i).click()
  for v in ['comparison','views','front','side','threequarter','rear','backthreequarter','portrait']:
   page.select_option('#view',v);page.wait_for_function('document.querySelector("#preview").complete && document.querySelector("#preview").naturalWidth>0')
 page.locator('#next').click();assert page.locator('#title').inner_text().startswith('01');page.locator('#prev').click();assert page.locator('#title').inner_text().startswith('10')
 page.select_option('#view','comparison');buttons.nth(0).click();page.screenshot(path=str(P/'previews/gallery_desktop.png'),full_page=True);page.set_viewport_size({'width':390,'height':844});assert page.evaluate('document.documentElement.scrollWidth<=innerWidth');page.screenshot(path=str(P/'previews/gallery_mobile.png'),full_page=True);assert not errors;browser.close()
server.shutdown();(P/'gallery_test.json').write_text(json.dumps({'dog_buttons':10,'views_loaded':80,'wraparound_navigation':'passed','mobile_horizontal_overflow':False,'javascript_errors':errors},indent=2));print('Gallery passed')
