import { render, screen, fireEvent } from "@testing-library/react";
import { it, expect, vi } from "vitest";
import { MicrophoneTake } from "./MicrophoneTake";

it("releases the microphone and saves only after confirming the preview", async () => {
  const stopTrack = vi.fn();
  const oldDevices = Object.getOwnPropertyDescriptor(navigator, "mediaDevices");
  Object.defineProperty(navigator, "mediaDevices", {
    configurable: true,
    value: { getUserMedia: vi.fn().mockResolvedValue({ getTracks: () => [{ stop: stopTrack }] }) },
  });
  const createUrl = vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:take");
  const revokeUrl = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => {});
  class Recorder {
    mimeType = "audio/webm";
    state = "inactive";
    ondataavailable?: (event: { data: Blob }) => void;
    onstop?: () => void;
    start() { this.state = "recording"; }
    stop() {
      this.state = "inactive";
      this.ondataavailable?.({ data: new Blob(["recorded"]) });
      this.onstop?.();
    }
  }
  vi.stubGlobal("MediaRecorder", Recorder);
  const apply = vi.fn().mockResolvedValue(true);
  const view = render(<MicrophoneTake seconds={20} busy={false} apply={apply} />);
  try {
    fireEvent.click(screen.getByRole("button", { name: "Start recording" }));
    fireEvent.click(await screen.findByRole("button", { name: "Stop recording" }));
    expect(view.container.querySelector("audio")?.getAttribute("src")).toBe("blob:take");
    expect(stopTrack).toHaveBeenCalledTimes(1);
    expect(apply).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Use this take" }));
    expect(apply.mock.calls[0][0]).toMatchObject({ name: "microphone.webm", type: "audio/webm" });
  } finally {
    view.unmount();
    vi.unstubAllGlobals();
    createUrl.mockRestore();
    revokeUrl.mockRestore();
    if (oldDevices) Object.defineProperty(navigator, "mediaDevices", oldDevices);
    else Reflect.deleteProperty(navigator, "mediaDevices");
  }
});
