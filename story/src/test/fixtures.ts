import type { Layout, Script } from '../engine/schema'

export const demoScript: Script = {
  slug: 'demo', title: '測試故事', place: '測試地', intro: '你是一名學徒。',
  startNode: 'n1',
  characters: [{ id: 'master', name: '師傅', parts: {
    head: 'characters/master/head.png', torso: 'characters/master/torso.png',
    leftArm: 'characters/master/left-arm.png', rightArm: 'characters/master/right-arm.png' } }],
  nodes: [
    { id: 'n1', background: 'scenes/n1.png', bgm: 'audio/main.mp3',
      cast: [{ character: 'master', position: 'center', talking: true }],
      paragraphs: ['第一段', '第二段'], choices: [
        { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/n1.png', paragraphs: ['結局A'], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/n1.png', paragraphs: ['結局B'], ending: { title: '結局B' } },
  ],
}

// 角色 id 對應 demoScript.characters；供各 task 測試共用的假 layout。
export const demoLayout: Layout = {
  canvas: { width: 1024, height: 1536 },
  characters: {
    master: {
      head: { cx: 0.5, top: 0.03, height: 0.22 },
      torso: { cx: 0.5, top: 0.2, height: 0.78 },
      leftArm: { cx: 0.33, top: 0.23, height: 0.35 },
      rightArm: { cx: 0.64, top: 0.22, height: 0.35 },
    },
  },
}
