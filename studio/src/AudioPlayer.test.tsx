import { it, expect, vi, beforeEach } from "vitest";
import {
  render,
  screen,
  act,
  fireEvent,
  waitFor,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AudioPlayer } from "./AudioPlayer";
import { TooltipProvider } from "@/components/ui/tooltip";
vi.mock("./api", () => ({ request: vi.fn() }));
import { request } from "./api";
class FakeAudio {
  currentTime = 0;
  duration = 8;
  playbackRate = 1;
  preservesPitch = true;
  loop = false;
  onloadedmetadata?: () => void;
  ontimeupdate?: () => void;
  onended?: () => void;
  onpause?: () => void;
  play = vi.fn(async () => {});
  pause = vi.fn(() => this.onpause?.());
}
let made: FakeAudio[];
beforeEach(() => {
  made = [];
  vi.clearAllMocks();
  vi.stubGlobal(
    "Audio",
    class extends FakeAudio {
      constructor() {
        super();
        made.push(this);
      }
    },
  );
  URL.createObjectURL = vi.fn(() => "blob:test");
  URL.revokeObjectURL = vi.fn();
  vi.mocked(request).mockResolvedValue(new Blob(["audio"]));
});
const player = (slot = "Line_1") => (
  <TooltipProvider>
    <AudioPlayer
      key={slot}
      slot={slot}
      missing={false}
      disabled={false}
      onError={vi.fn()}
    />
  </TooltipProvider>
);
it("pauses, seeks, stops at the saved speed without editing the saved take", async () => {
  render(player());
  await userEvent.click(screen.getByRole("button", { name: "Play recording" }));
  await screen.findByRole("button", { name: "Pause recording" });
  act(() => made[0].onloadedmetadata?.());
  await userEvent.click(
    screen.getByRole("button", { name: "Pause recording" }),
  );
  expect(made[0].pause).toHaveBeenCalled();
  const seek = screen.getByLabelText("Playback position", {
    selector: "input",
  });
  fireEvent.keyDown(seek, { key: "ArrowRight" });
  expect(made[0].currentTime).toBeGreaterThan(0);
  expect(made[0].playbackRate).toBe(1);
  expect(screen.queryByRole("combobox")).toBeNull();
  expect(made[0].preservesPitch).toBe(true);
  await userEvent.click(screen.getByRole("button", { name: "Stop recording" }));
  expect(made[0].currentTime).toBe(0);
  expect(request).toHaveBeenCalledTimes(1);
  expect(request).toHaveBeenCalledWith("/audio?slot=Line_1");
});
it("does not start a late audio download after switching recordings", async () => {
  let resolve!: (blob: Blob) => void;
  vi.mocked(request).mockReturnValue(
    new Promise((r) => {
      resolve = r;
    }),
  );
  const view = render(player());
  await userEvent.click(screen.getByRole("button", { name: "Play recording" }));
  view.rerender(player("Line_2"));
  await act(async () => resolve(new Blob(["late"])));
  expect(made).toHaveLength(0);
  expect(URL.createObjectURL).not.toHaveBeenCalled();
});
it("pauses and releases a loaded take when leaving it", async () => {
  const view = render(player());
  await userEvent.click(screen.getByRole("button", { name: "Play recording" }));
  await waitFor(() => expect(made[0].play).toHaveBeenCalled());
  view.unmount();
  expect(made[0].pause).toHaveBeenCalled();
  expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:test");
});

it("loops the current take without requesting or editing another file", async () => {
  render(player());
  await userEvent.click(screen.getByRole("button", { name: "Loop recording" }));
  expect(
    screen
      .getByRole("button", { name: "Loop recording" })
      .getAttribute("aria-pressed"),
  ).toBe("true");
  await userEvent.click(screen.getByRole("button", { name: "Play recording" }));
  await waitFor(() => expect(made[0].loop).toBe(true));
  await userEvent.click(screen.getByRole("button", { name: "Loop recording" }));
  expect(made[0].loop).toBe(false);
  expect(request).toHaveBeenCalledTimes(1);
});
