import { vi, it, expect, beforeEach } from "vitest";
import {
  render,
  screen,
  waitFor,
  within,
  fireEvent,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { Project, Schema } from "./model";
vi.mock("./api", () => ({
  request: vi.fn(),
  action: vi.fn(),
  setRevision: vi.fn(),
  RequestError: class extends Error {
    status = 409;
  },
}));
import { request, action } from "./api";
import App from "./App";
const project: Project = {
  name: "Test voice",
  author: "Tester",
  description: "Test pack",
  voice: "test",
  language: "EN",
  packVersion: "1.0.0",
  trial: false,
  revision: "1",
  projectKey: "current",
  coverage: { missing: 1510, pending: 1, approved: 0, redo: 0 },
  rows: Array.from({ length: 1511 }, (_, i) => ({
    slot: "Slot_" + i,
    text: "Line " + i,
    reference: "Reference " + i,
    direction: "Optional note",
    category: "Dialogue",
    family: "physical",
    delivery: "normal",
    context: i < 3 ? "Thirst" : "Situation" + Math.floor(i / 3),
    state: i ? "missing" : "pending",
  })),
};
const schema: Schema = {
  version: 1,
  contract: 1,
  slots: {
    Slot_0: {
      slot: "Slot_0",
      group: "Thirst",
      delivery: "normal",
      category: "Dialogue",
      family: "physical",
      nativeEvents: [],
      needLevels: [1],
    },
  },
  groups: {
    Thirst: {
      id: "Thirst",
      family: "physical",
      policy: { limit: 1 },
      recovery: null,
      references: [{ file: "Needs.lua", line: 1 }],
    },
  },
  sources: { "Needs.lua": "return actualRule" },
};
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(request).mockImplementation(async (path: string) =>
    path === "/project"
      ? structuredClone(project)
      : path === "/schema"
        ? schema
        : [{ key: "current", name: "Test voice" }],
  );
  vi.mocked(action).mockResolvedValue({});
});
it("keeps the selected take when approving it", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", { name: "Approve" }));
  await waitFor(() => expect(action).toHaveBeenCalledWith("/save", expect.objectContaining({slot: "Slot_0", state: "approved"})));
  expect((screen.getByRole("textbox", {name: "Spoken text / caption"}) as HTMLTextAreaElement).value).toBe("Line 0");
});
it("requires distribution confirmation each time the build dialog opens", async () => {
  const ready = structuredClone(project);
  ready.rows = [ {...ready.rows[0], state: "approved"} ];
  ready.coverage = {missing: 0, pending: 0, approved: 1, redo: 0};
  vi.mocked(request).mockImplementation(async path => path === "/project" ? ready : path === "/schema" ? schema : [{key: "current", name: "Test voice"}]);
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", {name: "Build voice pack"}));
  const build = screen.getByRole("button", {name: "Build package"}) as HTMLButtonElement;
  expect(build.disabled).toBe(true);
  await userEvent.click(screen.getByRole("checkbox", {name: "I own these recordings or have permission to distribute them."}));
  expect(build.disabled).toBe(false);
  await userEvent.click(build);
  await waitFor(() => expect(action).toHaveBeenCalledWith("/package", {rightsConfirmed: true}));
  await waitFor(() => expect(build.disabled).toBe(false));
  await userEvent.click(within(screen.getByRole("dialog", {name: "Build voice pack"})).getByRole("button", {name: "Close"}));
  await waitFor(() => expect(screen.queryByRole("dialog", {name: "Build voice pack"})).toBeNull());
  await userEvent.click(screen.getByRole("button", {name: "Build voice pack"}));
  expect((screen.getByRole("button", {name: "Build package"}) as HTMLButtonElement).disabled).toBe(true);
});
it("groups variations, bounds the library and moves selection when filters change", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(document.querySelectorAll(".recording-row")).toHaveLength(50);
  fireEvent.change(screen.getByLabelText("Find a recording"), {
    target: { value: "Line 1510" },
  });
  expect(document.querySelectorAll(".recording-row")).toHaveLength(1);
  await waitFor(() =>
    expect(
      (
        screen.getByRole("textbox", {
          name: "Spoken text / caption",
        }) as HTMLTextAreaElement
      ).value,
    ).toBe("Line 1510"),
  );
  expect(
    (
      within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", {
        name: "Approve",
      }) as HTMLButtonElement
    ).disabled,
  ).toBe(true);
});
it("keeps recordings behind accessible project and prepare dialogs; new projects default to full", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(screen.queryByRole("tab")).toBeNull();
  await userEvent.click(screen.getByRole("button", { name: "Build voice pack" }));
  let dialog = await screen.findByRole("dialog");
  expect(
    within(dialog).getByRole("heading", { name: "Build voice pack" }),
  ).toBeTruthy();
  expect(
    (
      within(dialog).getByRole("button", {
        name: "Build package",
      }) as HTMLButtonElement
    ).disabled,
  ).toBe(true);
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  expect(screen.getByDisplayValue("Line 0")).toBeTruthy();
  await waitFor(() =>
    expect(
      (
        screen.getByRole("combobox", {
          name: "Choose project",
        }) as HTMLButtonElement
      ).disabled,
    ).toBe(false),
  );
  await userEvent.click(
    screen.getByRole("combobox", { name: "Choose project" }),
  );
  await userEvent.click(
    await screen.findByRole("button", { name: "New project" }),
  );
  dialog = await screen.findByRole("dialog");
  const scope = within(dialog).getByRole("combobox", { name: "Scope" });
  expect(scope.textContent).toContain("Full pack");
  await userEvent.click(scope);
  expect(
    screen.getByRole("option", { name: "Listening sample (18 recordings)" }),
  ).toBeTruthy();
});
it("protects unsaved edits on navigation", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");

  fireEvent.change(screen.getByLabelText("Spoken text / caption"), {
    target: { value: "Edited line" },
  });
  await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
  const confirmation = await screen.findByRole("alertdialog");
  await userEvent.click(
    within(confirmation).getByRole("button", { name: "Keep editing" }),
  );
  expect(screen.getByDisplayValue("Edited line")).toBeTruthy();
  expect(action).not.toHaveBeenCalled();
});

it("selects a variation without duplicating its situation in the sidebar", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(document.querySelectorAll(".recording-row.selected")).toHaveLength(1);
  await userEvent.click(screen.getByRole("combobox", { name: "Variation" }));
  await userEvent.click(
    await screen.findByRole("option", {
      name: "2. Slot_1",
    }),
  );
  await screen.findByDisplayValue("Line 1");
  expect(
    (
      screen.getByRole("button", {
        name: "Play recording",
      }) as HTMLButtonElement
    ).disabled,
  ).toBe(true);
  expect(screen.queryByText("Import audio to hear this line.")).toBeNull();
  expect(document.querySelector(".review-status.missing")?.textContent).toBe(
    "Missing audio",
  );
});

it("exposes variations on demand and keeps guidance read-only", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(document.querySelectorAll(".variation-row")).toHaveLength(3);

  expect(document.querySelectorAll(".variation-row")).toHaveLength(3);
  await userEvent.click(screen.getByRole("button", { name: /Line 2.*Slot_2/ }));
  await screen.findByDisplayValue("Line 2");

  expect(screen.queryByRole("textbox", { name: /Recording note/ })).toBeNull();
  expect(
    document.querySelector(".recording-guidance p")?.textContent,
  ).toBeTruthy();
});
it("puts batch import in the library and build actions in the pack footer", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Batch import" }));
  const dialog = await screen.findByRole("dialog");
  expect(
    within(dialog).getByRole("button", { name: "Choose audio files" }),
  ).toBeTruthy();
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  await userEvent.click(screen.getByRole("button", { name: "Build voice pack" }));
  expect(
    screen.queryByRole("button", { name: "Choose audio files" }),
  ).toBeNull();
  expect(
    screen
      .getByRole("button", { name: "Build package" })
      .closest(".build-footer"),
  ).toBeTruthy();
  expect(
    within(screen.getByRole("dialog")).getAllByRole("button", {
      name: "Close",
    }).length,
  ).toBeGreaterThan(0);
});
it("searches languages with game-compatible codes", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await waitFor(() =>
    expect(
      (
        screen.getByRole("combobox", {
          name: "Choose project",
        }) as HTMLButtonElement
      ).disabled,
    ).toBe(false),
  );
  await userEvent.click(
    screen.getByRole("combobox", { name: "Choose project" }),
  );
  await userEvent.click(
    await screen.findByRole("button", { name: "New project" }),
  );
  const input = screen.getByRole("combobox", { name: "Language" });
  await userEvent.clear(input);
  await userEvent.type(input, "Turkish");
  await userEvent.click(
    await screen.findByRole("option", { name: "Turkish (TR)" }),
  );
  expect((input as HTMLInputElement).value).toBe("Turkish (TR)");
});

it("confirms bulk review counts and excludes missing and filtered-out takes", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(within(document.querySelector(".bulk-review") as HTMLElement).getByRole("button", {name:"Approve"}));
  let dialog = await screen.findByRole("alertdialog");
  expect(
    within(dialog).getByRole("heading", { name: "Approve 1 recordings?" }),
  ).toBeTruthy();
  await userEvent.click(within(dialog).getByRole("button", { name: "Cancel" }));
  expect(action).not.toHaveBeenCalled();
  await userEvent.click(within(document.querySelector(".bulk-review") as HTMLElement).getByRole("button", {name:"Approve"}));
  dialog = await screen.findByRole("alertdialog");
  await userEvent.click(
    within(dialog).getByRole("button", { name: "Approve" }),
  );
  await waitFor(() =>
    expect(action).toHaveBeenCalledWith("/review", {
      slots: ["Slot_0"],
      state: "approved",
    }),
  );
  fireEvent.change(screen.getByLabelText("Find a recording"), {
    target: { value: "Line 1510" },
  });
  await waitFor(() =>
    expect(
      (
        screen.getByRole("textbox", {
          name: "Spoken text / caption",
        }) as HTMLTextAreaElement
      ).value,
    ).toBe("Line 1510"),
  );
  expect(
    (
      within(document.querySelector(".bulk-review") as HTMLElement).getByRole("button", {
        name: "Approve",
      }) as HTMLButtonElement
    ).disabled,
  ).toBe(true);
});

it("shows activity while measuring, then reports the result", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  let finish!: (result: Record<string, unknown>) => void;
  vi.mocked(action).mockImplementation(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      }),
  );
  await userEvent.click(screen.getByRole("button", { name: "Build voice pack" }));
  await userEvent.click(
    screen.getByRole("button", { name: "Check audio levels" }),
  );
  expect(
    await screen.findByRole("progressbar", { name: "Checking audio levels" }),
  ).toBeTruthy();
  expect(
    (screen.getByRole("button", { name: "Checking…" }) as HTMLButtonElement)
      .disabled,
  ).toBe(true);
  finish({
    message: "Measured 1 recording. 1510 slots missing.",
    outliers: [],
  });
  await waitFor(() =>
    expect(
      screen.queryByRole("progressbar", { name: "Checking audio levels" }),
    ).toBeNull(),
  );
  expect(await screen.findByText("Audio check complete")).toBeTruthy();
  expect(
    screen.getAllByText("Measured 1 recording. 1510 slots missing.").length,
  ).toBeGreaterThan(0);
});
it("offers Coss commands and does not navigate while typing a caption", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.keyboard("{Control>}k{/Control}");
  expect(
    await screen.findByRole("dialog", { name: "Studio commands" }),
  ).toBeTruthy();
  await userEvent.type(
    screen.getByRole("combobox", { name: "Find a command" }),
    "Next recording",
  );
  await userEvent.keyboard("{ArrowDown}{Enter}");
  await screen.findByDisplayValue("Line 1");
  const caption = screen.getByRole("textbox", {
    name: "Spoken text / caption",
  });
  await userEvent.click(caption);
  await userEvent.keyboard("{Alt>}{ArrowRight}{/Alt}");
  expect((caption as HTMLTextAreaElement).value).toBe("Line 1");
  expect(screen.queryByRole("alertdialog")).toBeNull();
});

it("separates existing deliveries and opens the selected phrase in its group",async()=>{
 const mixed=structuredClone(project);
 mixed.rows=mixed.rows.slice(0,4).map((r,i)=>({...r,context:"Thirst",delivery:i<2?"normal":"whisper",text:"Phrase "+(i%2)}));
 vi.mocked(request).mockImplementation(async path=>path==="/project"?mixed:path==="/schema"?schema:[]);
 render(<App/>);await screen.findByDisplayValue("Phrase 0");
 expect(document.querySelectorAll(".variation-row")).toHaveLength(4);
 await userEvent.click(screen.getByRole("combobox",{name:"Delivery"}));
 await userEvent.click(await screen.findByRole("option",{name:"Whisper"}));
 expect(screen.getByRole("combobox",{name:"Variation"}).textContent).toContain("Slot_2");
 await userEvent.click(screen.getByRole("combobox",{name:"Variation"}));
 expect(await screen.findAllByRole("option")).toHaveLength(2);
 expect(screen.getAllByRole("option").every(e=>/Slot_[23]/.test(e.textContent || ""))).toBe(true);
});
it("navigates adjacent sidebar variations even when Core rows interleave situations", async () => {
  const mixed = {
    ...project,
    rows: [project.rows[0], project.rows[3], project.rows[1], project.rows[2]],
  };
  vi.mocked(request).mockImplementation(async path =>
    path === "/project" ? structuredClone(mixed) : path === "/schema" ? schema : []);
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
  await screen.findByDisplayValue("Line 1");
  await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
  await screen.findByDisplayValue("Line 2");
  await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
  await screen.findByDisplayValue("Line 3");
  await userEvent.click(screen.getByRole("button", { name: "Previous recording" }));
  await screen.findByDisplayValue("Line 2");
});
it("downloads the server's current slots when an older server lacks the list endpoint", async () => {
  const { RequestError } = await import("./api");
  const getProject = vi.mocked(request).getMockImplementation()!;
  let projectReads = 0;
  vi.mocked(request).mockImplementation(async (path, ...args) => {
    if (path === "/recording-list") throw Object.assign(new RequestError("Not found", 404), { status: 404 });
    if (path === "/project" && ++projectReads > 1) {
      expect(args[3]).toBe(false);
      return { ...project, rows: [{ ...project.rows[0], slot: "New_slot" }] };
    }
    return getProject(path, ...args);
  });
  let downloaded: Blob | undefined;
  const url = vi.spyOn(URL, "createObjectURL").mockImplementation(blob => {
    if (blob instanceof Blob) downloaded = blob;
    return "blob:slots";
  });
  const link = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
  try {
    render(<App />);
    await screen.findByDisplayValue("Line 0");
    await userEvent.click(screen.getByRole("button", { name: "Batch import" }));
    await userEvent.click(screen.getByRole("button", { name: "Download slot names" }));
    await waitFor(() => expect(link).toHaveBeenCalledOnce());
    const reader = new FileReader();
    const json = await new Promise<string>((resolve, reject) => {
      reader.onload = () => resolve(String(reader.result));
      reader.onerror = reject;
      reader.readAsText(downloaded!);
    });
    expect(JSON.parse(json).recordings).toEqual([
      { slot: "New_slot", text: "Line 0", state: "pending", filename: "New_slot.mp3" },
    ]);
    expect(screen.queryByText("Not found")).toBeNull();
  } finally {
    url.mockRestore();
    link.mockRestore();
  }
});
