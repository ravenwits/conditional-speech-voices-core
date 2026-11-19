import { useEffect, useRef, useState } from "react";
import languageNames from "@studio-languages";
import { ChevronsUpDown, Coins, ArrowUpRight } from "lucide-react";
import { PopoverPopup, PopoverRoot, PopoverTrigger } from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "./controls";
import { Combobox, ComboboxInput, ComboboxItem, ComboboxList, ComboboxPopup, ComboboxTrigger } from "@/components/ui/combobox";
import { request } from "./api";

type Voice = { id: string; name: string; category: string; languages: string[]; primaryLanguage?: string; owner?: string; owned?: boolean; originalId?: string };
export type Balance = { used: number; limit: number; remaining: number };
type VoicePage = { voices: Voice[]; next: string | null };
type Prompt = { prompt: string; characterCount: number; estimatedCredits: number; estimateSamples?: number };
type Candidate = { id: string; url: string; cost: number | null };

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "ElevenLabs request failed.";
}

async function send<T>(path: string, body: Record<string, string>, trackRevision = false) {
  return (await request<{ result: T }>("/elevenlabs/" + path, body, {}, true, trackRevision)).result;
}

export function useElevenLabsBalance(enabled: boolean, refresh: number) {
  const [state, setState] = useState<{ balance?: Balance; error?: string }>({});

  useEffect(() => {
    setState({});
    if (!enabled) return;
    let active = true;
    let inFlight = false;
    async function update() {
      if (inFlight) return;
      inFlight = true;
      try {
        const balance = await request<Balance>("/elevenlabs/credits");
        if (active) setState({ balance });
      } catch (error) {
        if (active) setState({ error: errorMessage(error) });
      } finally {
        inFlight = false;
      }
    }
    void update();
    const timer = window.setInterval(() => void update(), 60_000);
    return () => { active = false; window.clearInterval(timer); };
  }, [enabled, refresh]);
  return state;
}

export function remainingBalancePercent(balance: Balance) {
  if (!balance.limit) return 0;
  return Math.max(0, Math.min(100, 100 * balance.remaining / balance.limit));
}

export function ElevenLabsBalance({ balance }: { balance: Balance }) {
  const remaining = remainingBalancePercent(balance);
  const percent = Math.round(remaining);
  const label = `ElevenLabs balance, ${percent}% remaining, ${balance.remaining.toLocaleString("en-US")} credits left`;
  return (
    <PopoverRoot>
      <PopoverTrigger openOnHover delay={100} render={<Button variant="ghost" size="icon" className="rounded-full" aria-label={label} />}>
        <span className="grid size-8 place-items-center rounded-full p-[2px]"
          style={{ background: `conic-gradient(var(--primary) ${remaining}%, var(--border) 0)` }}>
          <span className="grid size-full place-items-center rounded-full bg-background text-[9px] leading-none tabular-nums">{percent}%</span>
        </span>
      </PopoverTrigger>
      <PopoverPopup aria-label="ElevenLabs balance" className="w-60 p-3">
        <p className="mb-2 text-sm font-medium">ElevenLabs balance</p>
        <dl className="grid grid-cols-[1fr_auto] gap-x-3 gap-y-1 text-xs tabular-nums">
          <dt className="text-muted-foreground">Total</dt><dd>{balance.limit.toLocaleString("en-US")} credits</dd>
          <dt className="text-muted-foreground">Remaining</dt><dd>{balance.remaining.toLocaleString("en-US")} credits</dd>
        </dl>
      </PopoverPopup>
    </PopoverRoot>
  );
}

export function ElevenLabsSettings({ project, language, languageCode, flags, configured, savedVoice, onConfigured, onSave, onClose }: {
  project: string;
  language: string;
  languageCode: string;
  flags: string[];
  configured: boolean;
  savedVoice: string;
  onConfigured: () => void;
  onSave: (voice: string) => void;
  onClose: () => void;
}) {
  const [accessKey, setAccessKey] = useState("");
  const [selectedVoice, setSelectedVoice] = useState<Voice | null>(null);
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [pages, setPages] = useState<Partial<Record<"voices" | "library", VoicePage>>>({});
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [lookupErrors, setLookupErrors] = useState<string[]>([]);
  const languageName = (languageNames as Record<string, string>)[language] || language;
  const matchesLanguage = (entry: Voice) => entry.primaryLanguage
    ? entry.primaryLanguage === languageCode
    : entry.languages?.includes(languageCode);
  const account = (pages.voices?.voices ?? []).filter(matchesLanguage);
  const accountIds = new Set(account.flatMap((entry) => [entry.id, entry.originalId]));
  const library = (pages.library?.voices ?? []).filter((entry) => matchesLanguage(entry) && !accountIds.has(entry.id));
  const options = [...account.filter((entry) => entry.owned), ...account.filter((entry) => !entry.owned), ...library];
  const chosen = selectedVoice ?? options.find((entry) => entry.id === savedVoice);
  const hasMore = !!(pages.voices?.next || pages.library?.next);
  const version = useRef(0);

  async function work(task: () => Promise<void>) {
    setBusy(true);
    setError("");
    try { await task(); } catch (e) { setError(errorMessage(e)); }
    finally { setBusy(false); }
  }

  async function fetchVoices(term: string, append = false) {
    const id = ++version.current;
    setLoading(true);
    setLookupErrors([]);
    const sources = (["voices", "library"] as const).filter((source) => !append || pages[source]?.next);
    await Promise.all(sources.map(async (source) => {
      const params = new URLSearchParams({ search: term });
      const next = append && pages[source]?.next;
      if (next) params.set("next", next);
      try {
        const page = await request<VoicePage>("/elevenlabs/" + source + "?" + params);
        if (id !== version.current) return;
        setPages((current) => ({
          ...current,
          [source]: {
            ...page,
            voices: [...new Map([...(append ? current[source]?.voices ?? [] : []), ...page.voices]
              .map((entry) => [entry.id, entry])).values()],
          },
        }));
      } catch (error) {
        if (id !== version.current) return;
        const label = source === "voices" ? "My Voices" : "Voice Library";
        setLookupErrors((errors) => [...errors, `${label}: ${errorMessage(error)}`]);
      }
    }));
    if (id !== version.current) return;
    setLoading(false);
  }

  useEffect(() => {
    if (!configured) return;
    const timer = window.setTimeout(() => void fetchVoices(search.trim()), search ? 300 : 0);
    return () => { window.clearTimeout(timer); version.current++; };
  }, [configured, search, languageCode]);

  function voiceLabel(entry: Voice) {
    return (
      <span className="flex min-w-0 items-center gap-2" title={entry.name + " · " + entry.id}>
        {flags.includes(language) && <img className="size-4 shrink-0 object-contain"
          src={`/studio/flag/${encodeURIComponent(language)}`} alt={languageName} />}
        <span className="min-w-0 truncate">{entry.name}</span>
        <span className="shrink-0 font-mono text-[10px] text-muted-foreground">{entry.id}</span>
      </span>
    );
  }

  return (
    <Modal open title="ElevenLabs settings" onClose={() => { if (!busy) onClose(); }}
      description={<>Connect your account and choose a voice for this project.{" "}
        <a className="text-primary hover:underline" href="https://elevenlabs.io/app/api/api-keys" target="_blank" rel="noreferrer">Get an API key</a>
      </>}
      footer={
        <>
          {savedVoice && <Button variant="ghost" disabled={busy} onClick={() => void work(async () => {
            await send("settings", { project, voice: "" }, true);
            onSave("");
          })}>Disable for this project</Button>}
          <Button disabled={!chosen || busy} onClick={() => void work(async () => {
            if (!chosen) return;
            const fields = { project, voice: chosen.id, ...(chosen.owner ? { owner: chosen.owner, name: chosen.name } : {}) };
            const result = await send<{ voice: string }>("settings", fields, true);
            onSave(result.voice);
          })}>{chosen?.owner ? "Add to My Voices and use" : "Save voice"}</Button>
        </>
      }>
      <div className="space-y-3">
        <div className="flex gap-2">
          <Input type="password" autoComplete="off" aria-label="ElevenLabs API key" value={accessKey}
            placeholder={configured ? "Replace API key" : "ElevenLabs API key"}
            onChange={(event) => setAccessKey(event.target.value)} disabled={busy} />
          <Button variant="outline" disabled={busy || !accessKey.trim()} onClick={() => void work(async () => {
            const page = await send<VoicePage>("connect", { project, key: accessKey.trim() });
            setPages({ voices: page });
            setSelectedVoice(null);
            setSearch("");
            setAccessKey("");
            if (configured && !search) await fetchVoices("");
            onConfigured();
          })}>Connect</Button>
        </div>
        {configured && (
          <div className="space-y-2">
            <Combobox items={options} value={chosen ?? null} filter={null}
              itemToStringLabel={(entry) => entry.name}
              isItemEqualToValue={(entry, value) => entry.id === value.id}
              open={open} onOpenChange={setOpen} disabled={busy}
              inputValue={search} onInputValueChange={(value, event) => {
                if (event.reason === "input-change" || event.reason === "input-clear") {
                  setPages({});
                  setLoading(true);
                  setSearch(value);
                }
              }}
              onValueChange={(entry) => { if (entry) setSelectedVoice(entry); }}>
              <ComboboxTrigger render={<Button variant="outline" className="w-full justify-between" aria-label="ElevenLabs voice" />}>
                {chosen ? voiceLabel(chosen) : <span className="truncate">{savedVoice || "Choose a voice"}</span>}
                <ChevronsUpDown aria-hidden="true" className="shrink-0" />
              </ComboboxTrigger>
              <ComboboxPopup>
                <ComboboxInput aria-label="Search ElevenLabs voices" placeholder={`Search ${languageName} voices…`} showTrigger={false} />
                <ComboboxList>
                  {(entry) => <ComboboxItem key={entry.id} value={entry}>{voiceLabel(entry)}</ComboboxItem>}
                </ComboboxList>
                {loading && <p role="status" className="px-3 py-2 text-xs text-muted-foreground">Loading voices…</p>}
                {!loading && lookupErrors.length > 0 && (
                  <div className="space-y-1 px-3 py-2 text-xs text-muted-foreground" role="status">
                    {lookupErrors.map((message) => <p key={message}>{message}</p>)}
                    <Button size="xs" variant="link" className="px-0" onClick={() => void fetchVoices(search.trim())}>Retry voices</Button>
                  </div>
                )}
                {!loading && !lookupErrors.length && !options.length && <p role="status" className="px-3 py-2 text-xs text-muted-foreground">
                  {hasMore ? "No matches on this page." : `No ${languageName} voices found. Try another search or create a voice.`}
                </p>}
                {hasMore && <Button size="sm" variant="ghost" className="shrink-0 rounded-t-none border-t"
                  disabled={loading} onClick={() => void fetchVoices(search.trim(), true)}>Load more</Button>}
              </ComboboxPopup>
            </Combobox>
            <a className="inline-flex items-center gap-1 text-xs text-primary hover:underline" href="https://elevenlabs.io/app/create-voice"
              target="_blank" rel="noreferrer">Create a voice <ArrowUpRight aria-hidden="true" className="size-3" /></a>
          </div>
        )}
        {busy && <p role="status" className="text-sm text-muted-foreground">Contacting ElevenLabs…</p>}
        {error && <p role="alert" className="text-sm text-destructive-foreground">{error}</p>}
      </div>
    </Modal>
  );
}

const GENERATING = "Generating…";

export function ElevenLabsPreview({ project, slot, existing, native, onAccept, onGenerated, onClose }: {
  project: string;
  slot: string;
  existing: boolean;
  native: boolean;
  onAccept: (id: string) => Promise<void>;
  onGenerated: () => void;
  onClose: () => void;
}) {
  const [prompt, setPrompt] = useState<Prompt | null>(null);
  const [nativeScript, setNativeScript] = useState<string>();
  const [candidate, setCandidate] = useState<Candidate | null>(null);
  const [original, setOriginal] = useState("");
  const [operation, setOperation] = useState("");
  const [error, setError] = useState("");
  const mounted = useRef(false);

  useEffect(() => {
    mounted.current = true;
    let active = true;
    void send<Prompt>("describe", { project, slot }).then((result) => {
      if (active) setPrompt(result);
    }, (e) => { if (active) setError(errorMessage(e)); });
    return () => { mounted.current = false; active = false; };
  }, [project, slot]);

  const script = nativeScript ?? prompt?.prompt ?? "";
  const scriptChanged = native && script.trim() !== prompt?.prompt;
  const missingVocalSound = native && !/\p{L}/u.test(script.replace(/\[[^\[\]\r\n]+\]/g, ""));

  useEffect(() => () => { if (candidate) URL.revokeObjectURL(candidate.url); }, [candidate]);
  useEffect(() => () => { if (original) URL.revokeObjectURL(original); }, [original]);

  async function work(label: string, task: () => Promise<void>) {
    setOperation(label);
    setError("");
    try { await task(); } catch (e) { if (mounted.current) setError(errorMessage(e)); }
    finally { if (mounted.current) setOperation(""); }
  }

  async function generate() {
    setCandidate(null);
    setOriginal("");
    try {
      const { id } = await send<{ id: string }>("generate", { project, slot, ...(native && { nativeScript: script.trim() }) });
      const deadline = Date.now() + 90_000;
      while (mounted.current && Date.now() < deadline) {
        const result = await request<{ ready: boolean; cost: number | null }>("/elevenlabs/preview?id=" + id);
        if (result.ready) {
          const audio = await request<Blob>("/audio/elevenlabs?id=" + id);
          if (mounted.current) setCandidate({ id, url: URL.createObjectURL(audio), cost: result.cost });
          return;
        }
        await new Promise((resolve) => window.setTimeout(resolve, 750));
      }
      if (mounted.current) throw new Error("The request is still pending. Check your credits before trying again.");
    } finally { if (mounted.current) onGenerated(); }
  }

  return (
    <Modal open title="Generate with ElevenLabs" onClose={() => { if (!operation) onClose(); }}
      description={slot + " · Eleven v4"}
      footer={
        <>
          {candidate && existing && !original && <Button size="sm" variant="outline" disabled={!!operation}
              onClick={() => void work("Loading current take…", async () => {
                const audio = await request<Blob>("/audio?slot=" + encodeURIComponent(slot));
                if (mounted.current) setOriginal(URL.createObjectURL(audio));
              })}>Compare with current take</Button>}
          <Button variant={candidate ? "outline" : "default"} disabled={!prompt || !!operation || missingVocalSound}
            onClick={() => void work(GENERATING, generate)}>{candidate ? "Generate again" : "Generate preview"}</Button>
          {candidate && <Button disabled={!!operation} onClick={() => void work("Saving…", async () => {
            await onAccept(candidate.id);
          })}>Use this take</Button>}
        </>
      }>
      <div className="space-y-4">
        {native && (
          <p className="text-xs text-muted-foreground">
            Add a short vocal sound outside the brackets, such as [gasps] Ah! Eleven v4 will try to vocalize that sound.
          </p>
        )}
        {prompt && (
          <div className="overflow-hidden rounded-lg border bg-card">
            <div className="flex items-center gap-3 border-b p-3">
              <Coins aria-hidden="true" className="size-5 text-primary" />
              <div className="flex-1">
                <p className="text-sm font-medium">{candidate?.cost != null ? "Reported charge" : "Estimated credits"}</p>
                <p className="text-xs text-muted-foreground">{candidate?.cost != null ? "Reported by ElevenLabs" :
                  prompt.estimateSamples ? "Based on recent charges for this voice" : "Model rate · actual charge may vary"}</p>
              </div>
              <span className="text-xl font-semibold tabular-nums text-primary">{candidate?.cost ?? (scriptChanged ? Math.ceil(prompt.estimatedCredits * Array.from(script.trim()).length / prompt.characterCount) : prompt.estimatedCredits)}</span>
            </div>
            {native ? (
              <label className="grid gap-2 p-3 text-sm">
                Reaction script
                <textarea className="min-h-20 w-full rounded-md border bg-background p-2 font-mono text-sm"
                  value={script} aria-invalid={missingVocalSound || undefined} maxLength={10_000} disabled={!!operation} onChange={(event) => {
                    setNativeScript(event.target.value);
                    setCandidate(null);
                    setError("");
                  }} />
                {missingVocalSound && <span className="text-xs text-destructive-foreground">Add a vocal sound outside the brackets.</span>}
              </label>
            ) : <p className="break-words p-3 text-sm">
              {prompt.prompt.split(/(\[[^\]]+\])/).map((part, index) =>
                part.startsWith("[") ? <span key={index} className="font-mono font-semibold text-primary">{part}</span> : part,
              )}
            </p>}
          </div>
        )}
        {candidate && (
          <div className="space-y-2">
            <p className="text-sm">Generated preview</p>
            <audio className="w-full" aria-label="Generated preview" autoPlay controls src={candidate.url} />
          </div>
        )}
        {original && <div className="space-y-2">
          <p className="text-sm">Current take</p>
          <audio className="w-full" aria-label="Current take" controls src={original} />
        </div>}
        {operation === GENERATING ? (
          <div role="status" className="flex min-h-20 items-center justify-between gap-4 rounded-lg border border-primary/20 bg-primary/5 px-4 py-3">
            <span className="text-sm font-medium">Generating audio…</span>
            <span className="generation-wave flex h-9 shrink-0 items-center gap-0.5 text-primary" aria-hidden="true">
              <i /><i /><i /><i /><i /><i /><i /><i /><i />
            </span>
          </div>
        ) : operation && <p role="status" className="text-sm text-muted-foreground">{operation}</p>}
        {error && <p role="alert" className="text-sm text-destructive-foreground">{error}</p>}
      </div>
    </Modal>
  );
}
