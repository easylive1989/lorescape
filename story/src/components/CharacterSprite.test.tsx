import { render, screen } from '@testing-library/react'
import { CharacterSprite } from './CharacterSprite'
import { assetUrl } from '../data/loadScript'
import { demoScript } from '../test/fixtures'

const master = demoScript.characters[0]

test('渲染單張角色圖', () => {
  render(<CharacterSprite character={master} member={{ character: 'master', position: 'center' }} slug="demo" />)
  const sprite = screen.getByTestId('sprite-master')
  const images = sprite.querySelectorAll('img')
  expect(images).toHaveLength(1)
  expect(images[0]).toHaveAttribute('src', assetUrl('demo', master.image))
  expect(images[0]).toHaveClass('sprite__image')
})

test('talking 時掛 is-talking class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left', talking: true }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-talking', 'sprite--left')
  rerender(<CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-talking')
})
