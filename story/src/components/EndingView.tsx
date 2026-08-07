import { useState } from 'react'
import { submitSurvey } from '../data/analytics'
import { SurveyForm } from './SurveyForm'

type Stage = 'ending' | 'survey' | 'thanks'

export function EndingView({ endingTitle, slug }: { endingTitle?: string; slug: string }) {
  const [stage, setStage] = useState<Stage>('ending')

  if (stage === 'ending') {
    return (
      <div className="ending-view" data-testid="ending">
        <h2>你走到了：{endingTitle}</h2>
        <button onClick={() => setStage('survey')}>留下你的感受</button>
      </div>
    )
  }

  if (stage === 'survey') {
    return (
      <div className="ending-view">
        <SurveyForm
          onSubmit={async (answers) => {
            const ok = await submitSurvey(slug, answers)
            if (ok) setStage('thanks')
            return ok
          }}
        />
      </div>
    )
  }

  return (
    <div className="ending-view thanks">
      <p>追蹤 IG，下週有新故事</p>
      <a href="https://www.instagram.com/lorescape.app/" target="_blank" rel="noopener">
        追蹤 Instagram
      </a>
      <a href={`/play/${slug}`}>再玩一次</a>
    </div>
  )
}
