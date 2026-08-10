/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { editorApiPlugin } from './plugins/editor-api'

export default defineConfig({
  plugins: [react(), editorApiPlugin()],
  server: {
    watch: {
      // content 變更由 editor-api 的 SSE 精準推播，避免 Vite full-reload 洗掉編輯器狀態；
      // 副作用是 dev 模式 /play 改內容需手動重整（spec 已知偏差）
      ignored: ['**/public/content/**'],
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
})
