import { Ban, ChevronRight, CircleHelp, Copy } from "lucide-react";
import type { ReactNode } from "react";
import { Badge, badgeVariants } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { toastManager } from "@/components/ui/toast";
import { ActionTip, Choice } from "./controls";
import { isAlternate, label, recordingTraits, stateNames, type Row, type Schema } from "./model";

import { ConditionIcon, PlaybackConditions, traitDescription } from "./PlaybackConditions";

export function AlternateBadge() {
  return (
    <Badge variant="outline" size="sm" className="me-1.5 align-middle text-muted-foreground" title="Alternate take">
      ALT
    </Badge>
  );
}

function acting(row: Row) {
  return row.acting || "unspecified";
}

function sourceSlot(slot: string, schema: Schema | null) {
  const seen = new Set<string>();
  while (!seen.has(slot)) {
    seen.add(slot);
    const source = schema?.slots[slot]?.source;
    if (!source || source === slot) break;
    slot = source;
  }
  return slot;
}

function correspondingTake(rows: Row[], selected: Row, schema: Schema | null) {
  const source = sourceSlot(selected.slot, schema);
  const sameLine = rows.filter(
    (row) => sourceSlot(row.slot, schema) === source,
  );
  return (
    sameLine.find((row) => row.text === selected.text && isAlternate(row) === isAlternate(selected)) ??
    sameLine.find((row) => isAlternate(row) === isAlternate(selected)) ??
    sameLine[0] ??
    rows.find((row) => row.text === selected.text) ??
    rows[0]
  );
}

export function RecordingSelection({
  selected,
  rows,
  schema,
  busy,
  onChoose,
  onProfanityChange,
}: {
  selected: Row;
  rows: Row[];
  schema: Schema | null;
  busy: boolean;
  onChoose: (row: Row) => void;
  onProfanityChange: (enabled: boolean) => void;
}) {
  const deliveries = [...new Set(rows.map((row) => row.delivery))];
  const inDelivery = rows.filter((row) => row.delivery === selected.delivery);
  const styles = [...new Set(inDelivery.map(acting))];
  const variations = inDelivery.filter(
    (row) => acting(row) === acting(selected),
  );
  function chooseFrom(candidates: Row[]) {
    const next = correspondingTake(candidates, selected, schema);
    if (next && next.slot !== selected.slot) onChoose(next);
  }
  return (
    <header className="recording-selection">
      <div className="recording-heading">
        <div className="flex min-w-0 flex-wrap items-center gap-x-2">
          <span className="text-xs text-muted-foreground">
            <span className="sr-only">Category </span>
            {label(selected.family)}
          </span>
          <ChevronRight
            aria-hidden="true"
            className="size-3 text-muted-foreground"
          />
          <h2 className="text-base font-semibold">
            <span className="sr-only">Situation </span>
            {label(selected.context)}
          </h2>
        </div>
        <Badge variant="outline" className={"review-status " + selected.state}>
          {stateNames[selected.state]}
        </Badge>
      </div>
      <div className="take-controls">
        <fieldset className="take-selectors">
          <legend className="sr-only">Choose a recording</legend>
          <div className="take-field">
            <span>Delivery</span>
            <Choice
              name="Delivery"
              value={selected.delivery}
              disabled={busy || deliveries.length < 2}
              items={deliveries.map((value) => ({
                value,
                label: label(value),
              }))}
              onChange={(value) => {
                const candidates = rows.filter((row) => row.delivery === value);
                const sameActing = candidates.filter(
                  (row) => acting(row) === acting(selected),
                );
                chooseFrom(sameActing.length ? sameActing : candidates);
              }}
            />
          </div>
          <div className="take-field">
            <span>Acting</span>
            <Choice
              name="Acting"
              value={acting(selected)}
              disabled={busy || styles.length < 2}
              items={styles.map((value) => ({
                value,
                label: value === "unspecified" ? "Not specified" : label(value),
              }))}
              onChange={(value) =>
                chooseFrom(inDelivery.filter((row) => acting(row) === value))
              }
            />
          </div>
          <div className="take-field take-variation">
            <span>Variation</span>
            <div className="flex min-w-0 items-center gap-1">
              <Choice
                name="Variation"
                value={selected.slot}
                disabled={busy || variations.length < 2}
                selectedContent={`${variations.indexOf(selected) + 1} of ${variations.length}${selected.optional ? " · Optional" : ""}`}
                items={variations.map((row, index) => ({
                  value: row.slot,
                  label: row.text || row.slot,
                  content: (
                    <span className="grid max-w-[min(26rem,70vw)] gap-0.5">
                      <span className="truncate">
                        {isAlternate(row) && <AlternateBadge />}
                        {index + 1}. {row.text || row.slot}
                      </span>
                      {row.text && (
                        <span className="truncate font-mono text-xs text-muted-foreground">
                          {row.slot}
                        </span>
                      )}
                    </span>
                  ),
                }))}
                onChange={(value) => {
                  const row = variations.find((row) => row.slot === value);
                  if (row) onChoose(row);
                }}
              />
              <ActionTip text={`Copy slot ID · ${selected.slot}`}>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  className="shrink-0"
                  aria-label="Copy slot ID"
                  onClick={async () => {
                    try {
                      await navigator.clipboard.writeText(selected.slot);
                      toastManager.add({ title: "Slot ID copied" });
                    } catch {
                      toastManager.add({
                        title: "Could not copy the slot ID",
                        type: "error",
                      });
                    }
                  }}
                >
                  <Copy />
                </Button>
              </ActionTip>
            </div>
          </div>
        </fieldset>
        <Label className="profanity-control">
          <Checkbox
            checked={Boolean(selected.profanity)}
            disabled={busy || selected.profanityLocked}
            onCheckedChange={onProfanityChange}
          />
          {selected.profanityLocked
            ? "Contains profanity (Core)"
            : "Contains profanity"}
        </Label>
      </div>
    </header>
  );
}

const traitLabels = {
  required: "Requires",
  preferred: "Priority for",
  conditional: "Conditional use",
  excluded: "Excludes",
};

export function RecordingBrief({
  row,
  activeTrait,
  onTraitChange,
  busy,
  tagGuide,
}: {
  row: Row;
  activeTrait: string;
  onTraitChange: (trait: string) => void;
  busy: boolean;
  tagGuide?: ReactNode;
}) {
  const traits = recordingTraits(row);
  const rule = row.traitRule;
  const traitLabel = rule?.kind === "required" && traits.length > 1
    ? "Requires one of"
    : rule ? traitLabels[rule.kind] : "Related traits";
  const RuleIcon = rule?.kind === "excluded" ? Ban : rule?.kind === "conditional" ? CircleHelp : null;
  return (
    <div className="recording-brief">
      <section aria-label="When it plays">
        <h3>When it plays</h3>
        <PlaybackConditions text={row.playbackWhen || "No playback conditions are listed for this recording."} />
        {traits.length > 0 ? (
          <div className="grid gap-1.5 border-t pt-2">
            {rule?.description && <p className="speaker-rule">{rule.description}</p>}
            <div className="speaker-rule flex flex-wrap items-center gap-1.5" data-trait-rule={rule?.kind}>
              <span className="trait-rule-label inline-flex items-center gap-1">
                {RuleIcon && <RuleIcon aria-hidden="true" className="size-3.5" />}
                {traitLabel}
              </span>
              {traits.map((trait) => (
                <ActionTip key={trait} text={traitDescription(trait)}>
                  <button type="button" disabled={busy}
                    className={badgeVariants({ variant: activeTrait === trait ? "default" : "outline" })}
                    aria-label={`Filter by ${trait}`} aria-pressed={activeTrait === trait}
                    onClick={() => onTraitChange(activeTrait === trait ? "" : trait)}>
                    <ConditionIcon name={trait} />{trait}
                  </button>
                </ActionTip>
              ))}
            </div>
          </div>
        ) : (
          row.playbackWhen && <p className="speaker-rule border-t pt-2">No trait required.</p>
        )}
      </section>
      <section aria-label="Recording guidance">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3>Recording guidance</h3>
          {tagGuide}
        </div>
        <p>
          {row.guidance ||
            row.direction ||
            (row.category === "Dialogue"
              ? "Speak at a natural pace."
              : "Record a short vocal sound without words.")}
        </p>
        {tagGuide && !!row.elevenLabsTags?.length && (
          <div
            className="flex flex-wrap items-baseline gap-x-2 gap-y-1 text-xs"
            aria-label="Recommended tags"
          >
            <span className="text-muted-foreground">Recommended tags</span>
            {row.elevenLabsTags.map((tag) => (
              <span key={tag} className="font-mono font-semibold text-primary">
                {tag}
              </span>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
