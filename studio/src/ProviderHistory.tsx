import { useEffect, useState } from "react";
import { Modal } from "./controls";
import { request } from "./api";

type RequestEntry = {
  id: string; time: string; slot: string;
  status: "generated" | "submitted" | "unconfirmed" | "failed"; cost?: number | null; draftCount?: number;
};

export function ProviderHistory({ provider, onClose, recordings, onOpen }: {
  provider: "ElevenLabs" | "Gemini";
  onClose: () => void;
  recordings: { slot: string; text: string }[];
  onOpen: (slot: string) => void;
}) {
  const [entries, setEntries] = useState<RequestEntry[]>();
  const [error, setError] = useState("");
  useEffect(() => {
    let active = true;
    void request<RequestEntry[]>(provider === "Gemini" ? "/dialogue/history" : "/elevenlabs/history").then(
      (result) => { if (active) setEntries(result); },
      (reason) => { if (active) setError(reason instanceof Error ? reason.message : "Could not load requests."); },
    );
    return () => { active = false; };
  }, [provider]);

  return (
    <Modal open title={provider + " history"} onClose={onClose} description="The last 50 requests for this project.">
      {error ? <p role="alert">{error}</p> : !entries ? <p role="status">Loading requests…</p> :
        !entries.length ? <p className="text-sm text-muted-foreground">No requests recorded yet.</p> :
          <ul className="max-h-[55dvh] divide-y overflow-y-auto">
            {entries.map((entry) => {
              const recording = recordings.find((row) => row.slot === entry.slot);
              const outcome = entry.status === "generated"
                ? provider === "Gemini"
                  ? entry.draftCount + (entry.draftCount === 1 ? " draft generated" : " drafts generated")
                  : entry.cost == null ? "Charge unavailable" : entry.cost + " credits reported"
                : entry.status === "failed" ? "Generation failed" : "Outcome unconfirmed";
              return (
                <li key={entry.id} className="space-y-1 py-2 text-xs">
                  <div className="flex flex-wrap justify-between gap-x-2">
                    {recording ?
                      <button type="button" className="text-left font-semibold hover:text-primary hover:underline" onClick={() => onOpen(entry.slot)}>
                        {recording.text || "Open recording"}
                      </button> : <strong>Recording unavailable</strong>}
                    <time dateTime={entry.time}>{new Date(entry.time).toLocaleString("en-US")}</time>
                  </div>
                  <p className="text-muted-foreground">{outcome}</p>
                </li>
              );
            })}
          </ul>}
    </Modal>
  );
}
