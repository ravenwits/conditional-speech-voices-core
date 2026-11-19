import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog, DialogClose, DialogDescription, DialogFooter, DialogHeader,
  DialogPanel, DialogPopup, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog";
import { request, revision as currentRevision } from "./api";

import { PencilSparkles } from "lucide-react";
import { ActionTip } from "./controls";
import { GeminiKeyForm } from "./Gemini";

export type DraftCache = Record<string, string[]>;

export function readDrafts(key: string): DraftCache {
  try {
    return JSON.parse(localStorage.getItem(key) ?? "{}") ?? {};
  } catch {
    return {};
  }
}

async function requestDrafts(slot: string, project: string, count: number, previousDrafts: string[]) {
  const { result } = await request<{ result: { options: string[] } }>(
    "/dialogue/suggest", { slot, project, dialogue_count: count, ...(previousDrafts.length && { previous_drafts: previousDrafts }) }, { "X-Revision": currentRevision }, true, false,
  );
  return result.options;
}


function DraftCount({ value, onChange, disabled }: {
  value: number; onChange: (count: number) => void; disabled: boolean;
}) {
  return (
    <label className="flex items-center gap-2 text-sm">
      Drafts per recording
      <select className="rounded-md border bg-background px-2 py-1" value={value} disabled={disabled}
        onChange={(event) => onChange(Number(event.target.value))}>
        {[1, 2, 3].map((n) => <option key={n} value={n}>{n}</option>)}
      </select>
    </label>
  );
}

export function DialogueDrafts({ slot, project, drafts, onDrafts, configured, onConnected, onGenerated, disabled, onUse }: {
  slot: string;
  project: string;
  drafts: string[];
  onDrafts: (slot: string, drafts: string[]) => void;
  configured: boolean;
  onConnected: () => void;
  onGenerated: () => void;
  disabled: boolean;
  onUse: (draft: string) => void;
}) {
  const [pending, setPending] = useState(false);
  const [count, setCount] = useState(3);
  const [error, setError] = useState("");

  async function generate() {
    setPending(true);
    setError("");
    try {
      onDrafts(slot, await requestDrafts(slot, project, count, drafts));
    } catch (error) {
      setError(error instanceof Error ? error.message : String(error));
    } finally {
      setPending(false);
      onGenerated();
    }
  }

  return (
    <Dialog>
      <ActionTip text="Generate text">
        <DialogTrigger render={<Button variant="ghost" className="h-auto! shrink-0 self-stretch rounded-none" aria-label="Generate text" disabled={disabled} />}>
          <PencilSparkles aria-hidden="true" />
        </DialogTrigger>
      </ActionTip>
      <DialogPopup>
        <DialogHeader>
          <DialogTitle>Generate text</DialogTitle>
          <DialogDescription>
            {configured
              ? "Send this recording’s gameplay conditions, acting and guidance to Gemini for up to three dialogue drafts."
              : "Connect a Gemini API key to generate dialogue drafts."}
          </DialogDescription>
        </DialogHeader>
        <DialogPanel className="space-y-3">
          {configured && <DraftCount value={count} onChange={setCount} disabled={pending} />}
          {!configured && <GeminiKeyForm configured={false} onConnected={onConnected} />}
          {pending && (
            <div className="space-y-3" role="status">
              <span className="sr-only">Generating dialogue…</span>
              {Array.from({ length: count }, (_, index) => (
                <div key={index} aria-hidden="true" data-slot="draft-skeleton"
                  className="h-11 rounded-lg border bg-muted/60 motion-safe:animate-pulse" />
              ))}
            </div>
          )}
          {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
          {!pending && drafts.map((draft) => (
            <DialogClose key={draft}
              render={<Button type="button" variant="outline" disabled={pending || disabled} dir="auto"
                className="h-auto w-full justify-start whitespace-normal p-3 text-start" />}
              onClick={() => onUse(draft)}>
              {draft}
            </DialogClose>
          ))}
          {!pending && drafts.length > 0 && (
            <p className="text-xs text-muted-foreground">Choose a draft to edit it in the caption field. Select Save to keep it.</p>
          )}
        </DialogPanel>
        {configured && (
          <DialogFooter>
            <Button disabled={pending || disabled} onClick={() => void generate()}>
              {drafts.length || error ? "Retry" : "Generate drafts"}
            </Button>
          </DialogFooter>
        )}
      </DialogPopup>
    </Dialog>
  );
}
