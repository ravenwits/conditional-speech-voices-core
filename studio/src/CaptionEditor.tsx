import { useEffect, useRef, type ComponentProps } from "react";
import { Textarea } from "@/components/ui/textarea";

const tagPattern = /\[[^\[\]\r\n]+\]/g;
const bareCue = /^(?:whispers?|shouts?|sighs|chuckles|clears throat|voice breaking)(?=\s)/i;
const wrappedCue = /\((?:whispers?|shouts?|sighs|chuckles|clears throat|voice breaking)\)/i;

export function validateCaptionTags(text: string, recommended: string[] = []) {
  const caption = text.replace(tagPattern, "");
  if (/[［］]/.test(text)) return { error: true, message: "Use standard square brackets [ ]." };
  if (/\[\s*\]/.test(text)) return { error: true, message: "Write a cue inside the brackets." };
  if (/\[\s*\[|\]\s*\]/.test(text)) return { error: true, message: "Use one pair of square brackets per audio tag." };
  if (/[\[\]]/.test(caption)) return { error: true, message: "Check for a missing opening [ or closing ]." };

  if (/(\[[^\[\]\r\n]+\])\s*\1/i.test(text)) {
    return { error: false, message: "This audio tag appears twice in a row." };
  }
  const plain = caption.trim();
  const recommendedCue = recommended.some((tag) => {
    const cue = tag.slice(1, -1).toLowerCase();
    return plain.toLowerCase().startsWith(cue + " ");
  });
  if (bareCue.test(plain) || wrappedCue.test(plain) || recommendedCue) {
    return { error: false, message: "If this is an audio cue, put it in square brackets [ ]." };
  }
  return undefined;
}

export function CaptionEditor({ value, highlight, ...props }: ComponentProps<typeof Textarea> & {
  value: string;
  highlight: boolean;
}) {
  const textarea = useRef<HTMLTextAreaElement>(null);
  const mirror = useRef<HTMLDivElement>(null);
  const scroll = () => {
    if (!textarea.current || !mirror.current) return;
    mirror.current.scrollTop = textarea.current.scrollTop;
    mirror.current.scrollLeft = textarea.current.scrollLeft;
  };
  useEffect(scroll, [value]);
  const parts = highlight ? value.split(/(\[[^\[\]\r\n]+\])/) : [value];
  const hasTags = parts.length > 1;
  return (
    <div className="caption-highlight relative w-full min-w-0 flex-1 max-[600px]:flex-none" data-highlight={hasTags || undefined}>
      <Textarea {...props} ref={textarea} value={value} className="caption-title" onScroll={scroll} />
      {hasTags && <div className="caption-mirror" ref={mirror} aria-hidden="true" dir="auto">
        {parts.map((part, index) => index % 2 === 0 ? part : (
          <span key={index} className="caption-inline-tag text-primary">{part}</span>
        ))}
        {value.endsWith("\n") ? "\u200b" : null}
      </div>}
    </div>
  );
}
