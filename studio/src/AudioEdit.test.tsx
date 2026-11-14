import { it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
vi.mock("./api", () => ({ request: vi.fn(async () => ({ duration: 3 })) }));
import { AudioEdit } from "./AudioEdit";
import type { Row } from "./model";

it("requires Apply for persistent edits and offers the original separately", async () => {
  const save = vi.fn(async () => {}),
    dirty = vi.fn();
  const row: Row = {
    slot: "Explore_1",
    text: "Here.",
    reference: "",
    direction: "",
    family: "routine",
    context: "Explore",
    category: "Dialogue",
    delivery: "normal",
    state: "pending",
    audioEdit: { gainDb: 3, semitones: 1 },
  };
  const { rerender } = render(
    <AudioEdit row={row} busy={false} onSave={save} onDirty={dirty} />,
  );
  await userEvent.click(screen.getByRole("button", { name: "Edit audio" }));
  // jsdom has no layout; Coss positions its thumb after measuring the track.
  const slider = screen.getByLabelText("Recording volume", {
    selector: "input",
  });
  slider.focus();
  await userEvent.keyboard("{ArrowRight}");
  expect(save).not.toHaveBeenCalled();
  expect(dirty).toHaveBeenLastCalledWith(true);
  await userEvent.click(screen.getByRole("button", { name: "Apply" }));
  expect(save).toHaveBeenLastCalledWith(3.5, 1, false, 1, 0, 0);
  const speed = screen.getByLabelText("Recording speed", { selector: "input" });
  speed.focus();
  await userEvent.keyboard("{Home}");
  await userEvent.click(screen.getByRole("button", { name: "Apply" }));
  expect(save).toHaveBeenLastCalledWith(3.5, 1, false, 0.25, 0, 0);
  screen.getByLabelText("Trim start", { selector: "input" }).focus();
  await userEvent.keyboard("{ArrowRight}");
  await userEvent.click(screen.getByRole("button", { name: "Apply" }));
  expect(save).toHaveBeenLastCalledWith(3.5, 1, false, 0.25, 0.01, 0);
  await userEvent.click(screen.getByRole("button", { name: "Restore" }));
  expect(save).toHaveBeenLastCalledWith(0, 0, true, 1, 0, 0);
  rerender(
    <AudioEdit
      row={{ ...row, audioEdit: { gainDb: 0, semitones: 0 } }}
      reset={1}
      busy={false}
      onSave={save}
      onDirty={dirty}
    />,
  );
  expect(
    screen
      .getByRole("button", { name: "Edit audio" })
      .getAttribute("aria-expanded"),
  ).toBe("true");
  expect(
    (screen.getByRole("button", { name: "Restore" }) as HTMLButtonElement)
      .disabled,
  ).toBe(true);
});
