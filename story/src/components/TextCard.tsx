export function TextCard({ text }: { text: string }) {
  return (
    <div className="text-card" data-testid="text-card">
      <p>{text}</p>
    </div>
  )
}
