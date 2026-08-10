/* Task 13：canvas cover 裁切——上傳背景/角色圖前，前端先裁成固定尺寸 PNG。 */

export function coverRect(
  srcW: number, srcH: number, dstW: number, dstH: number,
): { sx: number; sy: number; sw: number; sh: number } {
  const scale = Math.max(dstW / srcW, dstH / srcH)
  const sw = Math.round(dstW / scale)
  const sh = Math.round(dstH / scale)
  return { sx: Math.round((srcW - sw) / 2), sy: Math.round((srcH - sh) / 2), sw, sh }
}

// createImageBitmap + canvas，jsdom 測不了，僅由 coverRect 純函式測涵蓋數學
export async function coverToPngBlob(file: File, dstW: number, dstH: number): Promise<Blob> {
  const bitmap = await createImageBitmap(file)
  const { sx, sy, sw, sh } = coverRect(bitmap.width, bitmap.height, dstW, dstH)
  const canvas = document.createElement('canvas')
  canvas.width = dstW
  canvas.height = dstH
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('無法建立畫布內容')
  ctx.drawImage(bitmap, sx, sy, sw, sh, 0, 0, dstW, dstH)
  return await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob)
      else reject(new Error('圖片轉換失敗'))
    }, 'image/png')
  })
}
