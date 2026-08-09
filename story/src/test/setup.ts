import '@testing-library/jest-dom/vitest'

// jsdom 沒有 EventSource；預設路徑（未注入 subscribe stub 的測試）會 new 一個真的
// EventSource 而丟出 ReferenceError，用最小假物件頂替即可（永不連線、永不觸發 onmessage）。
if (!('EventSource' in globalThis)) {
  class MockEventSource {
    onmessage: ((event: MessageEvent) => void) | null = null
    constructor(_url: string) {}
    close() {}
  }
  // @ts-expect-error 只補測試環境需要的最小介面
  globalThis.EventSource = MockEventSource
}
