import { useEffect, useState } from "react";
import { ArrowUpRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "./controls";
import { request } from "./api";

type GeminiUsage = { requestsLastDay: number; inputTokensLastMinute: number };
const limitsUrl = "https://aistudio.google.com/rate-limit";

export function useGeminiUsage(configured: boolean, refresh: number) {
  const [usage, setUsage] = useState<GeminiUsage>();
  useEffect(() => {
    if (!configured) return;
    let active = true;
    let inFlight = false;
    async function update() {
      if (inFlight) return;
      inFlight = true;
      try {
        const result = await request<GeminiUsage>("/dialogue/usage", undefined, {}, true, false);
        if (active) setUsage(result);
      } catch {
        if (active) setUsage(undefined);
      } finally {
        inFlight = false;
      }
    }
    void update();
    const timer = window.setInterval(() => void update(), 15_000);
    return () => { active = false; window.clearInterval(timer); };
  }, [configured, refresh]);
  return configured ? usage : undefined;
}

function GeminiUsageDetails({ usage }: { usage?: GeminiUsage }) {
  return (
    <div className="space-y-2">
      <dl className="grid grid-cols-[1fr_auto] gap-x-3 gap-y-1 text-xs tabular-nums">
        <dt className="text-muted-foreground">Requests sent · last 24 hours</dt>
        <dd>{usage?.requestsLastDay?.toLocaleString("en-US") ?? "—"}</dd>
        <dt className="text-muted-foreground">Input tokens · last minute</dt>
        <dd>{usage?.inputTokensLastMinute?.toLocaleString("en-US") ?? "—"}</dd>
      </dl>
      <p className="text-xs text-muted-foreground">Studio usage since restart or key change.</p>
    </div>
  );
}

export function GeminiPanel({ configured, usage, onSettings, onHistory }: {
  configured: boolean; usage?: GeminiUsage; onSettings: () => void; onHistory: () => void;
}) {
  return (
    <section className="mb-2 space-y-2 rounded-md border bg-card p-3" aria-label="Gemini usage">
      <div className="flex flex-wrap items-center justify-between gap-x-2">
        <h3 className="text-sm font-semibold">Gemini</h3>
        {configured && (
          <Button variant="link" size="xs" className="px-0 text-xs text-primary"
            render={<a href={limitsUrl} target="_blank" rel="noreferrer" />}>
            Project limits <ArrowUpRight aria-hidden="true" className="size-3" />
          </Button>
        )}
      </div>
      {configured && <GeminiUsageDetails usage={usage} />}
      <div className="flex items-center justify-between gap-2">
        <Button variant="link" size="xs" className="px-0 text-xs" onClick={onSettings}>
          {configured ? "Settings" : "Connect Gemini"}
        </Button>
        <Button variant="link" size="xs" className="px-0 text-xs" onClick={onHistory}>History</Button>
      </div>
    </section>
  );
}

export function GeminiKeyForm({ configured, model, models, onConnected }: {
  configured: boolean;
  model?: string;
  models?: Record<string, string>;
  onConnected: (model?: string) => void;
}) {
  const [key, setKey] = useState("");
  const [selected, setSelected] = useState(model);
  const changingModel = configured && !!selected && selected !== model;
  const canSubmit = !!key.trim() || changingModel;
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");

  return (
    <form className="space-y-2" onSubmit={async (event) => {
      event.preventDefault();
      if (!canSubmit || pending) return;
      setPending(true);
      setError("");
      try {
        const { result } = await request<{ result: { model?: string } }>("/dialogue/connect", {
          ...(key.trim() && { key: key.trim() }),
          ...(selected && { model: selected }),
        }, {}, true, false);
        setKey("");
        onConnected(result.model);
      } catch (error) {
        setError(error instanceof Error ? error.message : "Could not connect to Gemini.");
      } finally {
        setPending(false);
      }
    }}>
      {models && selected && (
        <label className="grid gap-1.5 text-sm">
          Dialogue model
          <select className="min-h-9 rounded-md border bg-background px-3" value={selected}
            disabled={pending} onChange={(event) => setSelected(event.target.value)}>
            {Object.entries(models).map(([id, name]) => <option key={id} value={id}>{name}</option>)}
          </select>
        </label>
      )}
      <div className="flex gap-2">
        <Input type="password" autoComplete="off" aria-label="Gemini API key" value={key}
          maxLength={256} disabled={pending} onChange={(event) => setKey(event.target.value)}
          placeholder={configured ? "Replace API key" : "Paste API key"} />
        <Button type="submit" variant="outline" disabled={!canSubmit || pending}>
          {changingModel && !key.trim() ? (pending ? "Checking…" : "Save model") : (pending ? "Connecting…" : "Connect")}
        </Button>
      </div>
      {error && <p className="text-sm text-destructive" role="alert">{error}</p>}
      <p className="text-xs text-muted-foreground">Use a Free tier project in Google AI Studio to avoid charges.</p>
      <a className="text-sm font-medium text-primary hover:underline" href="https://aistudio.google.com/api-keys"
        target="_blank" rel="noreferrer">Get a Gemini API key</a>
    </form>
  );
}

export function GeminiSettings({ configured, model, models, onConnected, onClose }: {
  configured: boolean;
  model?: string;
  models?: Record<string, string>;
  onConnected: (model?: string) => void;
  onClose: () => void;
}) {
  return (
    <Modal open title="Gemini settings" description="Choose the model Studio uses to generate dialogue."
      onClose={onClose}>
      <GeminiKeyForm configured={configured} model={model} models={models}
        onConnected={(savedModel) => { onConnected(savedModel); onClose(); }} />
    </Modal>
  );
}
