const CROSSFADE_MS = 1000
const CROSSFADE_STEP_MS = 100
const CROSSFADE_STEPS = CROSSFADE_MS / CROSSFADE_STEP_MS

// jsdom 的 HTMLMediaElement.play() 未實作，回傳 undefined 而非 Promise。
function safePlay(audio: HTMLAudioElement): void {
  const result = audio.play() as unknown
  if (result && typeof (result as Promise<void>).catch === 'function') {
    ;(result as Promise<void>).catch(() => {})
  }
}

export class AudioManager {
  private unlocked = false
  private current: HTMLAudioElement | null = null
  private currentSrc: string | null = null
  // 目前正在淡出、尚未 pause 完成的舊曲（fade 進行中才有值）
  private outgoing: HTMLAudioElement | null = null
  private fadeInterval: ReturnType<typeof setInterval> | null = null

  unlock(): void {
    this.unlocked = true
  }

  playBgm(src: string): void {
    if (!this.unlocked) return
    if (this.currentSrc === src) return

    // 上一次的 crossfade 還沒跑完就再換曲：那首還在淡出中的舊曲即將失去參照，
    // 先立刻 pause 掉，避免它變成背景孤兒曲目繼續播放。
    if (this.fadeInterval) {
      clearInterval(this.fadeInterval)
      this.fadeInterval = null
      if (this.outgoing) {
        this.outgoing.pause()
        this.outgoing = null
      }
    }

    const prev = this.current
    const next = new Audio(src)
    next.loop = true
    next.volume = prev ? 0 : 1
    safePlay(next)

    this.current = next
    this.currentSrc = src

    if (!prev) return

    this.outgoing = prev
    let step = 0
    this.fadeInterval = setInterval(() => {
      step += 1
      prev.volume = Math.max(0, 1 - step / CROSSFADE_STEPS)
      next.volume = Math.min(1, step / CROSSFADE_STEPS)
      if (step >= CROSSFADE_STEPS) {
        if (this.fadeInterval) clearInterval(this.fadeInterval)
        this.fadeInterval = null
        prev.pause()
        this.outgoing = null
      }
    }, CROSSFADE_STEP_MS)
  }

  playSfx(src: string): void {
    if (!this.unlocked) return
    const sfx = new Audio(src)
    safePlay(sfx)
  }

  stop(): void {
    if (this.fadeInterval) {
      clearInterval(this.fadeInterval)
      this.fadeInterval = null
    }
    if (this.outgoing) {
      this.outgoing.pause()
      this.outgoing = null
    }
    if (this.current) {
      this.current.pause()
      this.current = null
    }
    this.currentSrc = null
  }
}

export const audioManager = new AudioManager()
