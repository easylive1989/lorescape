import { render, screen } from '@testing-library/react'
import { CharacterSprite } from './CharacterSprite'
import { demoScript } from '../test/fixtures'

const master = demoScript.characters[0]

test('渲染四個部件圖', () => {
  render(<CharacterSprite character={master} member={{ character: 'master', position: 'center' }} slug="demo" />)
  const sprite = screen.getByTestId('sprite-master')
  expect(sprite.querySelectorAll('img')).toHaveLength(4)
  expect(sprite.querySelector('.sprite__head')).toHaveAttribute(
    'src', '/content/demo/assets/characters/master/head.png')
})

test('talking 時掛 is-talking class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left', talking: true }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-talking', 'sprite--left')
  rerender(<CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-talking')
})
