import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { chromium } = require("/opt/homebrew/lib/node_modules/playwright");

const BASE = process.env.CAPTURE_BASE || "http://localhost:8899";
const OUT = process.env.CAPTURE_OUT ||
  "/Users/paulwu/lorescape-screenshots-editor/public/screenshots/lorescape";
const SCALE = 4;
const SCREENS = (process.env.CAPTURE_SCREENS || "stories,reader,explore,history,paywall,settings,hooks").split(",");

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 460, height: 920 },
  deviceScaleFactor: SCALE,
});
const page = await context.newPage();

for (const screen of SCREENS) {
  await page.goto(`${BASE}/_capture.html?screen=${screen}`, { waitUntil: "networkidle" });
  await page.waitForSelector(".phone.capture", { timeout: 15000 });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(
      Array.from(document.images).map((img) =>
        img.complete ? Promise.resolve() : new Promise((r) => { img.onload = img.onerror = r; }),
      ),
    );
  });
  await page.waitForTimeout(600);
  const el = await page.$(".phone.capture");
  await el.screenshot({ path: `${OUT}/${screen}.png` });
  console.log(`captured ${screen}`);
}
await browser.close();
console.log("DONE");
