import type { ReactNode } from "react";
import { useEffect, useRef, useState, useImperativeHandle } from "react";
import { Play, Pause, Square, Repeat } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";

import { request } from "./api";

export const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;

// Mounted per saved take. Cleanup also cancels a fetch that finishes after navigation.
export function AudioPlayer({
  navigation,
  controlRef,
  slot,
  missing,
  disabled,
  onError,
}: {
  navigation?: ReactNode;
  controlRef?: React.Ref<{ toggle: () => void }>;
  slot: string;
  missing: boolean;
  disabled: boolean;
  onError: (message: string) => void;
}) {
  const [loop, setLoop] = useState(false);
  const [hover, setHover] = useState<number | null>(null);
  const [scrubbing, setScrubbing] = useState(false);
  useEffect(() => {
    if (!scrubbing) return;
    const finish = () => setScrubbing(false);
    window.addEventListener("pointerup", finish);
    window.addEventListener("pointercancel", finish);
    window.addEventListener("blur", finish);
    return () => {
      window.removeEventListener("pointerup", finish);
      window.removeEventListener("pointercancel", finish);
      window.removeEventListener("blur", finish);
    };
  }, [scrubbing]);
  const audio = useRef<HTMLAudioElement | null>(null);
  const alive = useRef(true),
    url = useRef(""),
    loading = useRef(false);
  const [playing, setPlaying] = useState(false),
    [pending, setPending] = useState(false);
  const [time, setTime] = useState(0),
    [duration, setDuration] = useState(0);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      audio.current?.pause();
      if (url.current) URL.revokeObjectURL(url.current);
    };
  }, []);
  const toggle = async () => {
    if (loading.current || disabled || missing) return;
    if (playing) {
      audio.current?.pause();
      setPlaying(false);
      return;
    }
    loading.current = true;
    setPending(true);
    try {
      if (!audio.current) {
        const blob = await request<Blob>(
          "/audio?slot=" + encodeURIComponent(slot),
        );
        if (!alive.current) return;
        url.current = URL.createObjectURL(blob);
        const a = new Audio(url.current);
        audio.current = a;
        a.onloadedmetadata = () => {
          if (alive.current)
            setDuration(Number.isFinite(a.duration) ? a.duration : 0);
        };
        a.ontimeupdate = () => {
          if (alive.current) setTime(a.currentTime);
        };
        a.onended = a.onpause = () => {
          if (alive.current) setPlaying(false);
        };
        a.onerror = () => {
          if (alive.current) {
            setPlaying(false);
            onError(
              "Could not play this recording. Re-import the file to try again.",
            );
          }
        };
      }
      const a = audio.current;
      a.loop = loop;
      a.playbackRate = 1;
      a.preservesPitch = true;
      await a.play();
      if (alive.current) setPlaying(true);
      else a.pause();
    } catch (e) {
      if (alive.current)
        onError(e instanceof Error ? e.message : "Playback failed.");
    } finally {
      loading.current = false;
      if (alive.current) setPending(false);
    }
  };
  useImperativeHandle(controlRef, () => ({
    toggle: () => {
      void toggle();
    },
  }));
  const fraction = duration > 0 ? Math.min(1, time / duration) : 0;
  const marker = scrubbing ? fraction : hover;
  const centiseconds = Math.floor((marker ?? 0) * duration * 100);

  return (
    <div className="audio-player" aria-label="Recording player">
      <div className="player-controls">
        <Button
          className="player-play"
          disabled={disabled || missing || pending}
          onClick={() => void toggle()}
          aria-label={playing ? "Pause recording" : "Play recording"}
        >
          {playing ? <Pause /> : <Play />}
        </Button>
        <Button
          size="icon"
          variant="ghost"
          aria-label="Stop recording"
          disabled={!audio.current || disabled || pending}
          onClick={() => {
            const a = audio.current;
            if (a) {
              a.pause();
              a.currentTime = 0;
            }
            setTime(0);
            setPlaying(false);
          }}
        >
          <Square fill="currentColor" />
        </Button>
        {navigation}
        <Button
          size="icon"
          variant="ghost"
          aria-label="Loop recording"
          aria-pressed={loop}
          className={loop ? "loop-active" : ""}
          disabled={disabled || missing}
          onClick={() => {
            setLoop((v) => !v);
            if (audio.current) audio.current.loop = !loop;
          }}
        >
          <Repeat />
        </Button>
      </div>
      <div className="player-timeline">
        <span>{clock(time)}</span>
        <div
            className="seek-container"
            onPointerDownCapture={() => {
              if (duration && !disabled && !pending) setScrubbing(true);
            }}
            onPointerMove={(e) => {
              if (!duration || disabled || pending) return;
              const rect = e.currentTarget.getBoundingClientRect();
              setHover(
                Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width)),
              );
            }}
            onPointerLeave={() => setHover(null)}
          >
            <Slider
              getAriaLabel={() => "Playback position"}
              aria-label="Playback position"
              value={time}
              min={0}
              max={duration || 1}
              step={0.01}
              thumbAlignment="center"
              disabled={!duration || disabled || pending}
              onValueChange={(v) => {
                const t = Array.isArray(v) ? v[0] : v;
                if (audio.current) audio.current.currentTime = t;
                setTime(t);
              }}
            />
            {marker !== null && duration > 0 && !disabled && !pending && (
              <>
                <span className="seek-highlight" style={{ width: `${marker * 100}%` }} />
                <span className="seek-time" role="tooltip" style={{ left: `${marker * 100}%` }}>
                  {String(Math.floor(centiseconds / 100)).padStart(2, "0")}:
                  {String(centiseconds % 100).padStart(2, "0")}
                </span>
              </>
            )}
        </div>
        <span>{clock(duration)}</span>
      </div>
    </div>
  );
}
