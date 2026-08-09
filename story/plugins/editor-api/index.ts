import fs from 'node:fs'
import path from 'node:path'
import chokidar from 'chokidar'
import type { Plugin } from 'vite'
import { safeContentPath, validateContentPayload, type ContentFile } from './core'
import { classifyPath, SelfWriteGuard } from './watcher'

export function editorApiPlugin(): Plugin {
  return {
    name: 'editor-api',
    apply: 'serve',
    configureServer(server) {
      const root = path.resolve(server.config.root, 'public/content')
      const guard = new SelfWriteGuard()
      const clients = new Set<import('node:http').ServerResponse>()

      server.middlewares.use('/__editor/events', (req, res) => {
        res.writeHead(200, {
          'content-type': 'text/event-stream',
          'cache-control': 'no-cache', connection: 'keep-alive',
        })
        res.write('\n')
        clients.add(res)
        req.on('close', () => clients.delete(res))
      })

      const watcher = chokidar.watch(root, { ignoreInitial: true })
      for (const type of ['change', 'add', 'unlink'] as const)
        watcher.on(type, (absPath: string) => {
          if (guard.isSelf(absPath)) return
          const event = classifyPath(root, absPath)
          if (!event) return
          const payload = `data: ${JSON.stringify({ ...event, type })}\n\n`
          for (const client of clients) client.write(payload)
        })
      // httpServer 在 middleware mode（含 vitest 內部的測試 server）為 null，不會 emit 'close'；
      // 改包 server.close() 本身以確保 watcher 一定會被關掉，避免 process 卡住不退出
      const closeServer = server.close.bind(server)
      server.close = async () => {
        await watcher.close()
        return closeServer()
      }

      server.middlewares.use('/__editor', (req, res, next) => {
        const url = new URL(req.url ?? '/', 'http://local')
        const match = url.pathname.match(/^\/content\/(?:([\w-]+)\/)?([\w.-]+\.json)$/)
        if (!match) return next()
        const [, slug = '', file] = match
        const target = safeContentPath(root, slug, file)
        if (!target) { res.statusCode = 400; return res.end('{"error":"bad path"}') }
        if (req.method === 'GET') {
          if (!fs.existsSync(target)) { res.statusCode = 404; return res.end('{}') }
          res.setHeader('content-type', 'application/json')
          return res.end(fs.readFileSync(target, 'utf-8'))
        }
        if (req.method === 'PUT') {
          // body 大小上限：擋失控或惡意的超大 payload 把 body 字串撐爆記憶體；超過就 413 並中止累積
          const MAX_BODY_BYTES = 20 * 1024 * 1024
          let body = ''
          let bytes = 0
          let rejected = false
          req.on('data', (chunk) => {
            if (rejected) return
            bytes += chunk.length
            if (bytes > MAX_BODY_BYTES) {
              rejected = true
              res.statusCode = 413
              res.end('{"error":"payload too large"}')
              req.destroy()
              return
            }
            body += chunk
          })
          req.on('end', () => {
            if (rejected) return
            try {
              const data = JSON.parse(body)
              const scriptPath = safeContentPath(root, slug, 'script.json')
              const context = file === 'layout.json' && scriptPath && fs.existsSync(scriptPath)
                ? { script: JSON.parse(fs.readFileSync(scriptPath, 'utf-8')) }
                : undefined
              const verdict = validateContentPayload(file as ContentFile | 'index.json', data, context)
              if (!verdict.ok) {
                res.statusCode = 400
                return res.end(JSON.stringify({ error: verdict.error }))
              }
              guard.markWrite(target)
              fs.writeFileSync(target, JSON.stringify(data, null, 2) + '\n')
              res.statusCode = 204
              res.end()
            } catch (error) {
              res.statusCode = 400
              res.end(JSON.stringify({ error: String(error) }))
            }
          })
          return
        }
        next()
      })
    },
  }
}
