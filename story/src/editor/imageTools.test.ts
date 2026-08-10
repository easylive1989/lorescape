import { coverRect } from './imageTools'

test('過寬來源裁左右', () => {
  expect(coverRect(2000, 1600, 900, 1600)).toEqual({ sx: 550, sy: 0, sw: 900, sh: 1600 })
})
test('過高來源裁上下', () => {
  expect(coverRect(900, 3200, 900, 1600)).toEqual({ sx: 0, sy: 800, sw: 900, sh: 1600 })
})
test('等比縮放後置中', () => {
  // 900x1600 目標比例 0.5625；864/1536 = 0.5625 才是正確裁切（見 task-13-report 附註）
  expect(coverRect(1024, 1536, 900, 1600)).toEqual({ sx: 80, sy: 0, sw: 864, sh: 1536 })
})
