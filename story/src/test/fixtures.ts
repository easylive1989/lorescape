import type { Script } from '../engine/schema'

export const demoScript: Script = {
  slug: 'demo', title: '測試故事', place: '測試地', intro: '你是一名學徒。',
  startNode: 'n1',
  characters: [{ id: 'master', name: '師傅', image: 'characters/master/full.png' }],
  nodes: [
    { id: 'n1', background: 'scenes/n1.png', bgm: 'audio/main.mp3',
      cast: [{ character: 'master', position: 'center' }],
      paragraphs: [{ text: '第一段' }, { text: '第二段' }], choices: [
        { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/n1.png', paragraphs: [{ text: '結局A' }], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/n1.png', paragraphs: [{ text: '結局B' }], ending: { title: '結局B' } },
    // n2：附加在陣列末端、無入邊的 next 型節點，只供 graphMath retarget 測試使用；
    // 不影響既有節點的順序/索引，其餘測試不受影響。
    { id: 'n2', background: 'scenes/n1.png', paragraphs: [{ text: '過場' }], next: 'end-b' },
  ],
}
