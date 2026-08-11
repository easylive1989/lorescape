import { z } from 'zod'

export const catalogEntrySchema = z.object({
  slug: z.string().min(1), title: z.string().min(1),
  place: z.string().min(1), blurb: z.string().min(1),
})
export const catalogSchema = z.object({ stories: z.array(catalogEntrySchema) })
export type CatalogEntry = z.infer<typeof catalogEntrySchema>

export const characterSchema = z.object({
  id: z.string().min(1), name: z.string().min(1),
  image: z.string().min(1),
})
export const castMemberSchema = z.object({
  character: z.string(), position: z.enum(['left', 'center', 'right']),
})
// speaker 省略 = 旁白（走畫面下方的 .text-card）；有值 = 該角色說話，泡泡從他頭上出來。
export const paragraphSchema = z.object({
  text: z.string().min(1), speaker: z.string().optional(),
})
export const choiceSchema = z.object({ text: z.string().min(1), to: z.string().min(1) })
export const nodeSchema = z.object({
  id: z.string().min(1), background: z.string().min(1), bgm: z.string().optional(),
  cast: z.array(castMemberSchema).optional(),
  paragraphs: z.array(paragraphSchema).min(1),
  next: z.string().optional(),
  choices: z.array(choiceSchema).min(2).max(3).optional(),
  ending: z.object({ title: z.string().min(1) }).optional(),
})
export const scriptSchema = z.object({
  slug: z.string().min(1), title: z.string().min(1), place: z.string().min(1),
  intro: z.string().min(1), startNode: z.string().min(1),
  characters: z.array(characterSchema),
  nodes: z.array(nodeSchema).min(1),
})

export type Character = z.infer<typeof characterSchema>
export type CastMember = z.infer<typeof castMemberSchema>
export type Paragraph = z.infer<typeof paragraphSchema>
export type Choice = z.infer<typeof choiceSchema>
export type ScriptNode = z.infer<typeof nodeSchema>
export type Script = z.infer<typeof scriptSchema>

export function validateScript(data: unknown): Script {
  const script = scriptSchema.parse(data)
  const nodeIds = new Set(script.nodes.map((n) => n.id))
  const charIds = new Set(script.characters.map((c) => c.id))
  if (!nodeIds.has(script.startNode)) throw new Error(`startNode 不存在：${script.startNode}`)
  for (const node of script.nodes) {
    const endCount = [node.next, node.choices, node.ending].filter((x) => x !== undefined).length
    if (endCount !== 1) throw new Error(`節點 ${node.id}：next/choices/ending 必須恰好一個`)
    if (node.next && !nodeIds.has(node.next)) throw new Error(`節點 ${node.id} 的 next 指向不存在節點：${node.next}`)
    for (const c of node.choices ?? [])
      if (!nodeIds.has(c.to)) throw new Error(`節點 ${node.id} 的選項指向不存在節點：${c.to}`)
    // cast 是「台上站著哪些人」，角色與站位都必須唯一：同一個人不會同時站在兩個
    // 地方，而兩個 sprite 掛同一個站位會像素對像素完全重合、後者等於看不見。
    // 下面的 speaker 修復與比對邏輯（含工作台的刪除／抽換）都以角色唯一為前提。
    const castIds = new Set<string>()
    const castPositions = new Set<string>()
    for (const m of node.cast ?? []) {
      if (!charIds.has(m.character)) throw new Error(`節點 ${node.id} 引用未定義角色：${m.character}`)
      if (castIds.has(m.character)) throw new Error(`節點 ${node.id} 的角色重複上台：${m.character}`)
      if (castPositions.has(m.position)) throw new Error(`節點 ${node.id} 的站位重複：${m.position}`)
      castIds.add(m.character)
      castPositions.add(m.position)
    }
    // speaker 必須是已定義角色，且必須在台上——泡泡要有錨點，畫外音一律用旁白寫。
    node.paragraphs.forEach((p, i) => {
      if (p.speaker === undefined) return
      if (!charIds.has(p.speaker))
        throw new Error(`節點 ${node.id} 第 ${i + 1} 段引用未定義角色：${p.speaker}`)
      if (!castIds.has(p.speaker))
        throw new Error(`節點 ${node.id} 第 ${i + 1} 段的說話者不在台上：${p.speaker}`)
    })
  }
  return script
}
