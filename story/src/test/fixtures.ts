import type { Script } from '../engine/schema'

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
