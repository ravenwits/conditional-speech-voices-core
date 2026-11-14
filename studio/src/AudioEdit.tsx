import { useEffect, useState } from "react";
import { SlidersHorizontal, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Fold, Hint } from "./controls";
import { request } from "./api";
import type { Row } from "./model";

export function AudioEdit({
  row,
  reset = 0,
  busy,
  onSave,
  onDirty,
}: {
  row: Row;
  reset?: number;
  busy: boolean;
  onSave: (
    gain: number,
    pitch: number,
    restore: boolean,
    speed: number,
    trimStart: number,
    trimEnd: number,
  ) => Promise<void>;
  onDirty: (dirty: boolean) => void;
}) {
  const [duration, setDuration] = useState(0);
  useEffect(() => {
    let active = true;
    setDuration(0);
    request<{ duration: number }>(
      "/duration?slot=" + encodeURIComponent(row.slot),
    )
      .then((v) => {
        if (active) setDuration(v.duration);
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, [row.slot, reset]);
  const savedGain = row.audioEdit?.gainDb || 0,
    savedPitch = row.audioEdit?.semitones || 0,
    savedSpeed = row.audioEdit?.speed ?? 1;
  const savedStart = row.audioEdit?.trimStart ?? 0,
    savedEnd = row.audioEdit?.trimEnd ?? 0;
  const [trimStart, setTrimStart] = useState(savedStart),
    [trimEnd, setTrimEnd] = useState(savedEnd);
  const [gain, setGain] = useState(savedGain),
    [pitch, setPitch] = useState(savedPitch),
    [speed, setSpeed] = useState(savedSpeed);
  useEffect(() => {
    setTrimStart(savedStart);
    setTrimEnd(savedEnd);
    setGain(savedGain);
    setPitch(savedPitch);
    setSpeed(savedSpeed);
    onDirty(false);
  }, [
    row.slot,
    savedGain,
    savedPitch,
    savedSpeed,
    savedStart,
    savedEnd,
    reset,
  ]);
  const dirty =
    gain !== savedGain ||
    pitch !== savedPitch ||
    speed !== savedSpeed ||
    trimStart !== savedStart ||
    trimEnd !== savedEnd;
  useEffect(() => {
    onDirty(dirty);
  }, [dirty]);
  return (
    <Fold
      title={
        <>
          <SlidersHorizontal size={14} />
          Edit audio{dirty ? " · Unsaved" : ""}
        </>
      }
      className="audio-edit"
    >
      <div className="audio-edit-body">
        <div className="audio-sliders">
          <div>
            <div className="slider-label">
              <span className="label-with-info">
                Volume{" "}
                <Hint label="Volume help">
                  Excessive gain is rejected before saving. Edited takes need
                  listening approval again.
                </Hint>
              </span>
              <output>
                {gain > 0 ? "+" : ""}
                {gain} dB
              </output>
            </div>
            <Slider
              aria-label="Recording volume"
              getAriaLabel={() => "Recording volume"}
              min={-12}
              max={12}
              step={0.5}
              value={gain}
              disabled={busy}
              onValueChange={(v) => setGain(Number(v))}
            />
          </div>
          <div>
            <div className="slider-label">
              <span>Pitch</span>
              <output>
                {pitch > 0 ? "+" : ""}
                {pitch} semitones
              </output>
            </div>
            <Slider
              aria-label="Recording pitch"
              getAriaLabel={() => "Recording pitch"}
              min={-4}
              max={4}
              step={0.5}
              value={pitch}
              disabled={busy}
              onValueChange={(v) => setPitch(Number(v))}
            />
          </div>
        </div>
        <div className="speed-edit">
          <div className="slider-label">
            <span>Speed</span>
            <output>{speed.toFixed(2)}×</output>
          </div>
          <Slider
            aria-label="Recording speed"
            getAriaLabel={() => "Recording speed"}
            min={0.25}
            max={2}
            step={0.05}
            value={speed}
            disabled={busy}
            onValueChange={(v) => setSpeed(Number(v))}
          />
        </div>
        <div className="audio-sliders">
          {[
            { label: "Trim start", value: trimStart, set: setTrimStart },
            { label: "Trim end", value: trimEnd, set: setTrimEnd },
          ].map((t) => (
            <div key={t.label}>
              <div className="slider-label">
                <span>{t.label}</span>
                <output>{t.value.toFixed(2)} s</output>
              </div>
              <Slider
                aria-label={t.label}
                getAriaLabel={() => t.label}
                min={0}
                max={Math.max(
                  0,
                  Math.floor(
                    (duration -
                      (t.label === "Trim start" ? trimEnd : trimStart) -
                      0.01) *
                      100,
                  ) / 100,
                )}
                step={0.01}
                value={t.value}
                disabled={busy || !duration}
                onValueChange={(v) => t.set(Number(v))}
              />
            </div>
          ))}
        </div>
        <div className="button-row audio-edit-actions">
          <Button
            disabled={busy || !dirty}
            onClick={() =>
              void onSave(gain, pitch, false, speed, trimStart, trimEnd)
            }
          >
            Apply
          </Button>
          <Button
            variant="outline"
            disabled={
              busy ||
              (!savedGain &&
                !savedPitch &&
                savedSpeed === 1 &&
                !savedStart &&
                !savedEnd)
            }
            onClick={() => void onSave(0, 0, true, 1, 0, 0)}
          >
            <RotateCcw />
            Restore
          </Button>
        </div>
      </div>
    </Fold>
  );
}
