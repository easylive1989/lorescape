import { readFileSync } from 'node:fs'
import { validateScript, catalogSchema } from './schema'

// public/content/ 下的劇本是播放頁的唯一事實來源，格式壞掉在 CI 就要擋下，
// 不能等到瀏覽器載入才炸。
const catalog = catalogSchema.parse(
  JSON.parse(readFileSync('public/content/index.json', 'utf8')),
)

test.each(catalog.stories.map((s) => s.slug))('%s 的 script.json 通過驗證', (slug) => {
  const raw = JSON.parse(readFileSync(`public/content/${slug}/script.json`, 'utf8'))
  expect(() => validateScript(raw)).not.toThrow()
})
