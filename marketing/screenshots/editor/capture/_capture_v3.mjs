import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { chromium } = require("/opt/homebrew/lib/node_modules/playwright");

const FAMILIES = [
  { p:"iphone", w:390,  h:877,  dsf:4, shelf:"&perRow=4&books=6" },
  { p:"android",w:390,  h:938,  dsf:4, shelf:"&perRow=4&books=6" },
  { p:"ipad",   w:800,  h:1088, dsf:3, shelf:"&perRow=10&books=20" },
  { p:"tab",    w:800,  h:1378, dsf:3, shelf:"&perRow=10&books=20" },
];
const SCREENS = ["home","hooks","reader","map","history"];
const b = await chromium.launch();
for (const f of FAMILIES) {
  for (const s of SCREENS) {
    const c = await b.newContext({ viewport:{width:f.w,height:f.h}, deviceScaleFactor:f.dsf });
    const p = await c.newPage();
    const url = `http://localhost:8877/_cap3.html?screen=${s}&w=${f.w}&h=${f.h}` + (s==="history"?f.shelf:"");
    await p.goto(url, { waitUntil:"networkidle" });
    await p.evaluate(async()=>{ await document.fonts.ready;
      await Promise.all(Array.from(document.images).map(i=>i.complete?0:new Promise(r=>{i.onload=i.onerror=r;}))); });
    await p.waitForTimeout(s==="hooks"?5200:s==="map"?6000:3200);
    await p.screenshot({ path:`/tmp/ls3-proto/asset-${f.p}-${s}.png`, clip:{x:0,y:0,width:f.w,height:f.h} });
    await c.close();
  }
  console.log("family", f.p, "done");
}
await b.close();
console.log("ALL DONE");
