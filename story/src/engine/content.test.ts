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

  // schema 允許同一節點的 cast 出現重複 character id（工作台 addCast 永遠插入
  // characters[0]，重複是可達狀態），但重複會弄壞 sprite 的 React key、編輯器
  // 的 speaker 修復邏輯與壓暗判斷，出貨內容要守住不重複。
  const script = validateScript(raw)
  for (const node of script.nodes) {
    const ids = (node.cast ?? []).map((member) => member.character)
    expect(new Set(ids).size).toBe(ids.length)
  }
})
