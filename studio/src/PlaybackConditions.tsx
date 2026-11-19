const atlas = new URL("./assets/condition-icons.png", import.meta.url).href;
import entries from "./assets/condition-icons.json";
import { ActionTip } from "./controls";

const icons: Record<string, { index: number; description?: string }> = entries;

export function ConditionIcon({ name }: { name: string }) {
  const entry = icons[name];
  if (!entry) return null;
  return <span aria-hidden="true" className="inline-block size-4 shrink-0 align-text-bottom"
    style={{ backgroundImage: `url(${atlas})`, backgroundSize: "16px auto",
      backgroundPosition: `0 -${16 * entry.index}px`, imageRendering: "pixelated" }} />;
}

export function traitDescription(trait: string) {
  return icons[trait]?.description || `Filter recordings by ${trait}.`;
}

// Annotate the existing trigger sentence so qualifiers such as "or" and "below" stay with the condition.
const terms: [string, string, string][] = [
  ["exertion|exhaustion|winded", "Mood_Exhausted", "Physical effort has depleted endurance."],
  ["panic|panicked", "Mood_Panicked", "Measures the survivor’s current panic."],
  ["fatigue|drowsy", "Mood_Sleepy", "The survivor needs sleep."],
  ["intoxication|drunk", "Mood_Drunk", "Alcohol is affecting the survivor."],
  ["has a cold", "Mood_Ill", "The survivor has caught a cold."],
  ["severe cold", "Status_TemperatureLow", "The survivor’s body temperature has dropped."],
  ["severe heat|overheating", "Status_TemperatureHot", "The survivor’s body temperature is high."],
  ["thirst|thirsty", "Status_Thirst", "Measures the need for water."],
  ["hunger|hungry", "Status_Hunger", "Measures the need for food."],
  ["stress|stressed", "Mood_Stressed", "Measures the survivor’s stress."],
  ["boredom|bored", "Mood_Bored", "Measures the survivor’s boredom."],
  ["unhappiness|unhappy", "Mood_Sad", "Measures the survivor’s unhappiness."],
  ["angry|anger", "Mood_Angry", "Measures the survivor’s anger."],
  ["bleeding", "Status_Bleeding", "A wound is causing blood loss."],
  ["pain", "Mood_Pained", "Measures the pain the survivor feels."],
  ["nausea", "Mood_Nauseous", "The survivor feels sick to their stomach."],
  ["heavy load", "Status_HeavyLoad", "Carried weight exceeds capacity."],
  ["wetness", "Status_Wet", "Measures how wet the survivor is."],
];
const byTerm = new Map(terms.flatMap(([words, icon, tip]) =>
  words.split("|").map(word => [word, { icon, tip }] as const)));
const pattern = new RegExp(`(\\b(?:${[...byTerm.keys()].join("|")})\\b)`, "gi");

export function PlaybackConditions({ text }: { text: string }) {
  return <p>{text.split(pattern).map((part, index) => {
    const term = byTerm.get(part.toLowerCase());
    return term ? <ActionTip text={term.tip} key={index}>
      <button type="button" className="inline-flex items-center justify-start gap-1 rounded bg-muted px-1 font-semibold focus-visible:outline">
        <ConditionIcon name={term.icon} />{part}
      </button>
    </ActionTip> : part;
  })}</p>;
}
