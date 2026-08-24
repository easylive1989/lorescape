import React from "react";

/**
 * Split a line into segments, tagging any segment that matches one of the
 * `highlights` substrings so callers can style it (colour, underline, …).
 */
export const splitHighlights = (
  line: string,
  highlights: string[] = [],
): { text: string; highlight: boolean }[] => {
  if (highlights.length === 0 || line.length === 0) {
    return [{ text: line, highlight: false }];
  }
  const escaped = highlights
    .filter(Boolean)
    .map((h) => h.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  if (escaped.length === 0) return [{ text: line, highlight: false }];

  const re = new RegExp(`(${escaped.join("|")})`, "g");
  return line
    .split(re)
    .filter((s) => s.length > 0)
    .map((s) => ({ text: s, highlight: highlights.includes(s) }));
};

export interface HighlightedLineProps {
  line: string;
  /** Omitted (or undefined) means "emphasise nothing" — see Beat.highlights. */
  highlights?: string[];
  highlightColor: string;
  highlightStyle?: "color" | "underline" | "brush";
}

export const HighlightedLine: React.FC<HighlightedLineProps> = ({
  line,
  highlights = [],
  highlightColor,
  highlightStyle = "color",
}) => {
  const segments = splitHighlights(line, highlights);
  return (
    <>
      {segments.map((seg, i) =>
        seg.highlight ? (
          <span
            key={i}
            style={{
              color: highlightStyle === "color" ? highlightColor : undefined,
              fontWeight: 900,
              borderBottom:
                highlightStyle === "underline"
                  ? `0.12em solid ${highlightColor}`
                  : undefined,
              paddingBottom: highlightStyle === "underline" ? "0.05em" : undefined,
              background:
                highlightStyle === "brush"
                  ? `linear-gradient(transparent 55%, ${highlightColor} 55%)`
                  : undefined,
              boxDecorationBreak: "clone",
              WebkitBoxDecorationBreak: "clone",
            }}
          >
            {seg.text}
          </span>
        ) : (
          <React.Fragment key={i}>{seg.text}</React.Fragment>
        ),
      )}
    </>
  );
};
