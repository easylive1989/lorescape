import { z } from 'zod'

export const characterSchema = z.object({
  id: z.string().min(1), name: z.string().min(1),
  parts: z.object({ head: z.string(), torso: z.string(), leftArm: z.string(), rightArm: z.string() }),
})
export const castMemberSchema = z.object({
  character: z.string(), position: z.enum(['left', 'center', 'right']),
  talking: z.boolean().optional(),
})
export const choiceSchema = z.object({ text: z.string().min(1), to: z.string().min(1) })
export const nodeSchema = z.object({
  id: z.string().min(1), background: z.string().min(1), bgm: z.string().optional(),
  cast: z.array(castMemberSchema).optional(),
  paragraphs: z.array(z.string().min(1)).min(1),
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
    for (const m of node.cast ?? [])
      if (!charIds.has(m.character)) throw new Error(`節點 ${node.id} 引用未定義角色：${m.character}`)
  }
  return script
}
