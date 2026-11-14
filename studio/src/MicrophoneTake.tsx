import { useEffect, useRef, useState } from "react";
import { Choice } from "./controls";
import { Button } from "@/components/ui/button";

export function MicrophoneTake({
  seconds, busy, apply,
}: {
  seconds: number;
  busy: boolean;
  apply: (file: File) => Promise<boolean>;
}) {
  const [phase, setPhase] = useState<"idle" | "permission" | "recording" | "finishing">("idle");
  const [take, setTake] = useState<{ file: File; url: string }>();
  const [error, setError] = useState("");
  const active = useRef(false);
  const stream = useRef<MediaStream | undefined>(undefined);
  const recorder = useRef<MediaRecorder | undefined>(undefined);
  const timeout = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const preview = useRef("");

  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [device, setDevice] = useState("");
  const [elapsed, setElapsed] = useState(0);
  const [level, setLevel] = useState(0);
  const context = useRef<AudioContext | undefined>(undefined);
  const monitor = useRef<ReturnType<typeof setInterval> | undefined>(undefined);

  async function refreshDevices() {
    try {
      const list = await navigator.mediaDevices?.enumerateDevices?.();
      if (!active.current || !list) return;
      const inputs = list.filter((item) => item.kind === "audioinput" && item.deviceId && item.deviceId !== "default");
      setDevices(inputs);
      setDevice((current) => inputs.some((item) => item.deviceId === current) ? current : "");
    } catch {
      // The browser's default input still works when device enumeration is unavailable.
    }
  }

  function monitorInput(input: MediaStream) {
    const started = performance.now();
    setElapsed(0);
    setLevel(0);
    let readLevel: (() => number) | undefined;
    try {
      const audio = new AudioContext();
      context.current = audio;
      const analyser = audio.createAnalyser();
      audio.createMediaStreamSource(input).connect(analyser);
      const samples = new Float32Array(analyser.fftSize);
      readLevel = () => {
        analyser.getFloatTimeDomainData(samples);
        return Math.min(1, Math.sqrt(samples.reduce((sum, sample) => sum + sample * sample, 0) / samples.length) * 4);
      };
      void audio.resume().catch(() => {});
    } catch {
      // The timer remains available without a live level meter.
    }
    monitor.current = setInterval(() => {
      setElapsed(Math.min(seconds, (performance.now() - started) / 1000));
      if (readLevel) setLevel(readLevel());
    }, 80);
  }

  function release() {
    clearTimeout(timeout.current);
    clearInterval(monitor.current);
    if (context.current) void context.current.close().catch(() => {});
    context.current = undefined;
    stream.current?.getTracks().forEach((track) => track.stop());
    stream.current = undefined;
  }
  useEffect(() => {
    active.current = true;
    void refreshDevices();
    const media = navigator.mediaDevices;
    media?.addEventListener?.("devicechange", refreshDevices);
    return () => {
      active.current = false;
      media?.removeEventListener?.("devicechange", refreshDevices);
      const current = recorder.current;
      if (current) {
        current.onstop = null;
        current.onerror = null;
        if (current.state !== "inactive") current.stop();
      }
      release();
      if (preview.current) URL.revokeObjectURL(preview.current);
    };
  }, []);

  function stop() {
    if (recorder.current?.state === "recording") {
      setPhase("finishing");
      recorder.current.stop();
      release();
    }
  }
  async function start() {
    setError("");
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      setError("This browser cannot record audio. Import an audio file instead.");
      return;
    }
    setPhase("permission");
    try {
      const input = await navigator.mediaDevices.getUserMedia({ audio: device ? { deviceId: { exact: device } } : true });
      if (!active.current) {
        input.getTracks().forEach((track) => track.stop());
        return;
      }
      stream.current = input;
      void refreshDevices();
      const next = new MediaRecorder(input);
      recorder.current = next;
      const chunks: Blob[] = [];
      let failed = false;
      next.ondataavailable = ({ data }) => { if (data.size) chunks.push(data); };
      next.onerror = () => {
        failed = true;
        release();
        setPhase("idle");
        setError("Recording failed. Check your microphone and try again.");
      };
      next.onstop = () => {
        release();
        if (!active.current || failed) return;
        setPhase("idle");
        const type = next.mimeType || chunks[0]?.type || "audio/webm";
        const extension = type.includes("ogg") ? "ogg" : type.includes("mp4") ? "m4a" : "webm";
        const file = new File(chunks, `microphone.${extension}`, { type });
        if (!file.size) {
          setError("No audio was captured. Try recording again.");
          return;
        }
        if (preview.current) URL.revokeObjectURL(preview.current);
        preview.current = URL.createObjectURL(file);
        setTake({ file, url: preview.current });
      };
      next.start();
      monitorInput(input);
      setPhase("recording");
      // Leave room for encoder padding at the import duration limit.
      timeout.current = setTimeout(stop, Math.max(100, seconds * 1000 - 350));
    } catch {
      release();
      if (active.current) {
        setPhase("idle");
        setError("Microphone unavailable. Check browser permission and input settings.");
      }
    }
  }

  return (
    <div className="form-stack">
      {error && <p role="alert">{error}</p>}
      {phase === "permission" && <p role="status">Waiting for microphone permission…</p>}
      <div className="form-stack">
        <span>Microphone</span>
        <Choice name="Microphone" value={device} onChange={setDevice} disabled={busy || phase !== "idle"}
          items={[
            { value: "", label: "System default" },
            ...devices.map((input, index) => ({ value: input.deviceId, label: input.label || `Microphone ${index + 1}` })),
          ]}
        />
      </div>
      {phase === "recording" && (
        <div className="microphone-monitor">
          <span>Recording</span>
          <meter aria-label="Microphone input level" min={0} max={1} value={level} />
          <span aria-label="Elapsed time">{elapsed.toFixed(1)} / {seconds} s</span>
        </div>
      )}
      {phase === "idle" && take && <audio controls src={take.url} aria-label="Preview microphone take" />}
      <div className="button-row">
        {phase === "recording" ? (
          <Button variant="destructive" onClick={stop}>Stop recording</Button>
        ) : (
          <Button variant="outline" disabled={busy || phase !== "idle"} onClick={() => void start()}>
            {take ? "Record again" : "Start recording"}
          </Button>
        )}
        {take && (
          <Button disabled={busy || phase !== "idle"} onClick={() => void apply(take.file)}>
            Use this take
          </Button>
        )}
      </div>
    </div>
  );
}
