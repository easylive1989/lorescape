import fs from 'node:fs'
import path from 'node:path'
import type { Plugin } from 'vite'
import { safeContentPath, validateContentPayload, type ContentFile } from './core'

export function editorApiPlugin(): Plugin {
  return {
    name: 'editor-api',
    apply: 'serve',
    configureServer(server) {
      const root = path.resolve(server.config.root, 'public/content')
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
          let body = ''
          req.on('data', (chunk) => { body += chunk })
          req.on('end', () => {
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
