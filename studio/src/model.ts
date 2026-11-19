export type State = "missing" | "pending" | "approved" | "redo";
export type Row = {
  slot: string;
  source?: string;
  alternate?: boolean;
  text: string;
  speechScript?: string | null;
  reference: string;
  direction: string;
  guidance?: string;
  elevenLabsTags?: string[];
  nativePreview?: boolean;
  optional?: boolean;
  profanity?: boolean;
  profanityLocked?: boolean;
  traits?: string[];
  playbackWhen?: string;
  traitRule?: {
    kind: "required" | "preferred" | "conditional" | "excluded";
    traits: string[];
    description: string;
  } | null;
  category: string;
  family: string;
  delivery: string;
  acting?: string;
  context: string;
  state: State;
  audioEdit?: {
    gainDb?: number;
    semitones?: number;
    speed?: number;
    trimStart?: number;
    trimEnd?: number;
  };
};
export type Project = {
  buildCoverage?: { required: number; covered: number; missing: string[]; missingSlots?: Record<string, string[]>; pools?: Record<string, string[]> };
  languageFlags?: string[];
  characterBase?: string;
  elevenLabs?: { configured: boolean; voice: string; languageCode?: string };
  dialogueGeneration?: boolean;
  dialogueModel?: string;
  dialogueModels?: Record<string, string>;
  canUndoReview?: boolean;
  name: string;
  author: string;
  steamProfile?: string;
  limits?: { caption: number; speechScript?: number; seconds: number; audioBytes?: number };
  description: string;
  voice: string;
  language: string;
  packVersion: string;
  trial: boolean;
  revision: string;
  projectKey: string;
  schemaError?: string | null;
  rows: Row[];
  coverage: Record<State, number>;
};
export type Slot = {
  slot: string;
  group: string;
  source?: string;
  delivery: string;
  acting?: string;
  category: string;
  family: string;
  needLevels?: number[];
  min?: number;
  max?: number;
  threat?: boolean;
  nativeEvents: string[];
};
export type Group = {
  id: string;
  family: string;
  policy: unknown;
  recovery: unknown;
  references: { file: string; line: number }[];
};
export type Schema = {
  version: number;
  contract: number;
  slots: Record<string, Slot>;
  groups: Record<string, Group>;
  sources: Record<string, string>;
};
export const stateNames: Record<State, string> = {
  missing: "Missing audio",
  pending: "Needs listening",
  approved: "Approved",
  redo: "Needs a retake",
};
export const label = (s: string) =>
  (s === "slurred" ? "drunk" : s === "congested" ? "ill" : s)
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replaceAll("_", " ")
    .replace(/^./, (c) => c.toUpperCase());
export function coverageLabel(key: string): string {
  const [group, conditions, slot] = key.split("|");
  if (slot) return label(slot);
  if (!conditions) {
    const [kind, situation, level] = key.split(" / ");
    if (kind === "severity") return `${label(situation)} · Level ${level}`;
    return situation ? label(situation) : label(key);
  }
  const { needLevels, min, max, threat } = JSON.parse(conditions);
  const details = [];
  if (needLevels?.length) details.push(`Level ${needLevels.join(", ")}`);
  else if (min !== undefined && max !== undefined)
    details.push(min === max ? `Level ${min}` : `Levels ${min}–${max}`);
  else if (min !== undefined) details.push(`Level ${min}+`);
  if (threat !== undefined) details.push(threat ? "With threat" : "Without threat");
  return [label(group), ...details].join(" · ");
}

export type Filters = {
  profanity?: string;
  search: string;
  family: string;
  trait: string;
  group: string;
  category: string;
  delivery: string;
  acting: string;
  state: string;
};
export const emptyFilters: Filters = {
  search: "",
  family: "",
  trait: "",
  group: "",
  category: "",
  delivery: "",
  acting: "",
  state: "",
};
export function recordingTraits(row: Row): string[] {
  return row.traitRule?.traits ?? row.traits ?? [];
}

export function recordingFilterState(row: Row) {
  return row.state === "missing" && row.optional ? "optional-missing" : row.state;
}

export function filterRows(rows: Row[], f: Filters, requiredSlots?: ReadonlySet<string>) {
  const query = f.search.trim().toLocaleLowerCase();
  const slotQuery = query.replace(/[ _-]+/g, "");
  return rows.filter(
    (r) =>
      (!f.profanity || r.profanity === true) &&
      (!f.family || r.family === f.family) &&
      (!f.trait || recordingTraits(r).includes(f.trait)) &&
      (!f.group || r.context === f.group) &&
      (!f.category || r.category === f.category) &&
      (!f.delivery || r.delivery === f.delivery) &&
      (!f.acting || (r.acting || "unspecified") === f.acting) &&
      (f.state === "required"
        ? requiredSlots?.has(r.slot)
        : !f.state || recordingFilterState(r) === f.state) &&
      (!query ||
        (!!slotQuery && [r.slot, r.source].some((id) =>
          id?.toLocaleLowerCase().replace(/[ _-]+/g, "").includes(slotQuery))) ||
        [r.text, r.context, r.delivery, r.acting]
          .join(" ")
          .toLocaleLowerCase()
          .includes(query)),
  );
}
export function isAlternate(row: Row) {
  // Earlier workbench responses only identify catalog alternates by their slot ID.
  return row.alternate ?? row.slot.startsWith("Alt_");
}

function variationOrder(row: Row) {
  if (isAlternate(row)) return 2;
  if (row.source ? row.source !== row.slot : /^(Expr|Whisper)_/.test(row.slot)) return 1;
  return 0;
}

export function groupRows(rows: Row[]) {
  const groups = new Map<string, Row[]>();
  for (const row of rows) {
    const list = groups.get(row.context);
    if (list) list.push(row);
    else groups.set(row.context, [row]);
  }
  return [...groups].map(([context, variations]) => ({
    context,
    variations: variations.sort((a, b) => variationOrder(a) - variationOrder(b)),
  }));
}
