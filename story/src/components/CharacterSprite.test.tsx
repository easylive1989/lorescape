import { render, screen } from '@testing-library/react'
import { CharacterSprite } from './CharacterSprite'
import { assetUrl } from '../data/loadScript'
import { demoScript, demoLayout } from '../test/fixtures'

const master = demoScript.characters[0]

test('渲染四個部件圖並依 layout 定位', () => {
  render(<CharacterSprite character={master} member={{ character: 'master', position: 'center' }} slug="demo" layout={demoLayout} />)
  const sprite = screen.getByTestId('sprite-master')
  expect(sprite.querySelectorAll('img')).toHaveLength(4)
  const head = sprite.querySelector('.sprite__head') as HTMLElement
  expect(head).toHaveAttribute('src', assetUrl('demo', 'characters/master/head.png'))
  expect(head.style.left).toBe('50%')
  expect(head.style.top).toBe('3%')
  expect(head.style.height).toBe('22%')
})

test('talking 時掛 is-talking class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left', talking: true }} slug="demo" layout={demoLayout} />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-talking', 'sprite--left')
  rerender(<CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" layout={demoLayout} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-talking')
})
