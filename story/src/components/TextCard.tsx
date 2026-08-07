export function TextCard({ text, onTap }: { text: string; onTap: () => void }) {
  return (
    <div className="text-card" data-testid="text-card" onClick={onTap}>
      <p>{text}</p>
    </div>
  )
}
