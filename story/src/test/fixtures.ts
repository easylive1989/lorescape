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

// 條件段落／選項的測試用劇本：start 的選項會 set flag，mid 有一段條件段落與
// 一個條件選項，三個選項各指向不同節點以便驗證「可見索引」對到正確目標。
export const flagScript: Script = {
  slug: 'flags', title: 'flag 測試', place: '測試地', intro: '介紹',
  startNode: 'start',
  characters: [],
  nodes: [
    { id: 'start', background: 'scenes/n1.png',
      paragraphs: [{ text: '開場' }],
      choices: [
        { text: '封爐', to: 'mid', set: ['sealed'] },
        { text: '直接走', to: 'mid' },
      ] },
    { id: 'mid', background: 'scenes/n1.png',
      paragraphs: [
        { text: '共用' },
        { text: '封了爐才有的一段', when: 'sealed' },
        { text: '沒封才有的一段', when: '!sealed' },
      ],
      choices: [
        { text: '去港口', to: 'harbor', when: '!sealed' },
        { text: '走城門', to: 'gate' },
        { text: '躲起來', to: 'end' },
      ] },
    { id: 'harbor', background: 'scenes/n1.png', paragraphs: [{ text: '港口' }], next: 'end' },
    { id: 'gate', background: 'scenes/n1.png', paragraphs: [{ text: '城門' }], next: 'end' },
    { id: 'end', background: 'scenes/n1.png', paragraphs: [{ text: '結束' }], ending: { title: '結局' } },
  ],
}
