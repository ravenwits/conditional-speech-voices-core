export type State = "missing" | "pending" | "approved" | "redo";
export type Row = {
  slot: string;
  text: string;
  reference: string;
  direction: string;
  guidance?: string;
  category: string;
  family: string;
  delivery: string;
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
  canUndoReview?: boolean;
  name: string;
  author: string;
  steamProfile?: string;
  limits?: { caption: number; seconds: number; audioBytes?: number };
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
  s
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replaceAll("_", " ")
    .replace(/^./, (c) => c.toUpperCase());
// Browsing labels for trait-linked takes. Gameplay eligibility remains in Core.
const traitsBySituation: Record<string, string[]> = {
  Agoraphobic: ["Agoraphobic"],
  Claustrophobic: ["Claustrophobic"],
  BloodAversion: ["Fear of Blood"],
  NicotineNeed: ["Smoker"],
  StartleBrave: ["Brave"],
  StartleCowardly: ["Cowardly"],
  StartleDesensitized: ["Desensitized"],
  TraitDriver: ["Sunday Driver"],
  TraitVigilant: ["Deaf", "Hard of Hearing", "Conspicuous"],
  TraitHunger: ["Hearty Appetite", "Fast Metabolism"],
  TraitThirst: ["High Thirst"],
  TraitLoad: ["Weak", "Feeble", "Disorganized"],
  TraitCold: ["Prone to Illness"],
  TraitNausea: ["Weak Stomach"],
  TraitFull: ["Light Eater", "Slow Metabolism"],
  TraitSight: ["Short Sighted"],
  TraitRest: ["Restless Sleeper", "Sleepyhead"],
  TraitWound: ["Slow Healer"],
  TraitFumble: ["All Thumbs"],
  TraitReading: ["Slow Reader"],
  TraitStudy: ["Slow Learner"],
  TraitFall: ["Clumsy"],
  TraitScratch: ["Thin-skinned"],
  TraitIlliterate: ["Illiterate"],
};

export function recordingTraits(situation: string): string[] {
  return traitsBySituation[situation] ?? [];
}

export type Filters = {
  search: string;
  family: string;
  trait: string;
  group: string;
  category: string;
  state: string;
};
export const emptyFilters: Filters = {
  search: "",
  family: "",
  trait: "",
  group: "",
  category: "",
  state: "",
};
export function filterRows(rows: Row[], f: Filters) {
  const query = f.search.trim().toLocaleLowerCase();
  return rows.filter(
    (r) =>
      (!f.family || r.family === f.family) &&
      (!f.trait || recordingTraits(r.context).includes(f.trait)) &&
      (!f.group || r.context === f.group) &&
      (!f.category || r.category === f.category) &&
      (!f.state || r.state === f.state) &&
      (!query ||
        [r.slot, r.text, r.context, r.delivery]
          .join(" ")
          .toLocaleLowerCase()
          .includes(query)),
  );
}
export function groupRows(rows: Row[]) {
  const groups = new Map<string, Row[]>();
  for (const row of rows) {
    const list = groups.get(row.context);
    if (list) list.push(row);
    else groups.set(row.context, [row]);
  }
  return [...groups].map(([context, variations]) => ({ context, variations }));
}
