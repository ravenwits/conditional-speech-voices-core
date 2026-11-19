import { vi, it, expect, beforeEach } from "vitest";
import {
  act,
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
  revision: "1",
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
  languageFlags: ["EN", "TR", "UZ", "TT", "TK", "TG"],
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
  localStorage.clear();
  vi.mocked(request).mockImplementation(async (path: string) =>
    path === "/project"
      ? structuredClone(project)
      : path === "/schema"
        ? schema
        : [{ key: "current", name: "Test voice" }],
  );
  vi.mocked(action).mockResolvedValue({});
});
it("approves and advances without reloading the project", async () => {
  vi.mocked(action).mockResolvedValueOnce({ row: { slot: "Slot_0", text: "Line 0", direction: "", state: "approved" } });
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", { name: "Approve" }));
  await waitFor(() => expect(action).toHaveBeenCalledWith("/save", expect.objectContaining({slot: "Slot_0", state: "approved"})));
  expect(await screen.findByDisplayValue("Line 1")).toBeTruthy();
  expect(screen.getByRole("button", { name: /Line 0.*Approved/ })).toBeTruthy();
  expect(vi.mocked(request).mock.calls.filter(([path]) => path === "/project")).toHaveLength(1);
});
it("keeps the retake status when saving text and disables the current review action", async () => {
  const reviewed = structuredClone(project);
  reviewed.rows[0].state = "redo";
  reviewed.rows[1].state = "approved";
  vi.mocked(request).mockImplementation(async path => path === "/project" ? reviewed : path === "/schema" ? schema : []);
  vi.mocked(action).mockResolvedValue({ row: { ...reviewed.rows[0], text: "Revised caption" } });

  render(<App />);
  const editor = await screen.findByRole("textbox", { name: "Spoken text / caption" });
  const review = within(screen.getByRole("button", { name: "Needs a retake" }).closest(".review-actions") as HTMLElement);
  expect((review.getByRole("button", { name: "Needs a retake" }) as HTMLButtonElement).disabled).toBe(true);

  fireEvent.change(editor, { target: { value: "Revised caption" } });
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  await waitFor(() => expect(action).toHaveBeenCalledWith("/save", expect.objectContaining({ state: "redo", text: "Revised caption" })));
  expect((review.getByRole("button", { name: "Needs a retake" }) as HTMLButtonElement).disabled).toBe(true);
  await userEvent.click(screen.getByRole("button", { name: /Line 1.*Slot_1/ }));
  expect((review.getByRole("button", { name: "Approve" }) as HTMLButtonElement).disabled).toBe(true);
});

it("shows flags and keeps settings on the current project row only", async () => {
  vi.mocked(request).mockImplementation(async (path) =>
    path === "/project" ? { ...structuredClone(project), projectKey: "active" } : path === "/schema" ? schema : [
      { key: "current", name: "My_Voice" },
      { key: "active", name: "Test voice", language: "EN" },
      { key: "other", name: "Other voice", language: "TR" },
    ],
  );
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  const menu = screen.getByRole("button", { name: "Studio menu" });
  await userEvent.click(menu);
  expect(screen.queryByRole("button", { name: "Project settings" })).toBeNull();
  await userEvent.click(await screen.findByRole("combobox", { name: "Choose project" }));
  const gear = await screen.findByRole("button", { name: "Settings for Test voice" });
  expect(screen.queryByRole("button", { name: "Remove Test voice" })).toBeNull();
  expect(screen.queryByRole("button", { name: "Settings for Other voice" })).toBeNull();
  const current = screen.getAllByRole("row")[0];
  expect(current.textContent).toContain("Test voice");
  expect(within(current).getByText("current").classList.contains("text-primary")).toBe(true);
  expect(current.querySelector('[data-slot="combobox-item"] svg')).toBeNull();
  expect(screen.getByRole("gridcell", { name: "Other voice" }).querySelector("img")?.getAttribute("src")).toBe("/studio/flag/TR");
  expect((screen.getByRole("button", { name: "Remove My_Voice" }) as HTMLButtonElement).disabled).toBe(true);
  expect(screen.getByText("Startup")).toBeTruthy();
  expect((screen.getByRole("button", { name: "Remove Other voice" }) as HTMLButtonElement).disabled).toBe(false);
  await userEvent.click(gear);
  expect(await screen.findByRole("dialog", { name: "Project" })).toBeTruthy();
});
it("asks before switching projects with an unsaved script and preserves the draft on cancel", async () => {
  vi.mocked(request).mockImplementation(async path => path === "/project"
    ? structuredClone(project) : path === "/schema" ? schema : [
      { key: "current", name: "Test voice" },
      { key: "other", name: "Other voice" },
    ]);
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  fireEvent.change(screen.getByRole("textbox", { name: "Spoken text / caption" }), {
    target: { value: "Line [whispers] 0" },
  });
  async function selectOtherProject() {
    await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
    await userEvent.click(screen.getByRole("combobox", { name: "Choose project" }));
    await userEvent.click(await screen.findByRole("gridcell", { name: "Other voice" }));
  }
  await selectOtherProject();
  expect(await screen.findByRole("alertdialog", { name: "Discard unsaved changes?" })).toBeTruthy();
  expect(action).not.toHaveBeenCalled();
  await userEvent.click(screen.getByRole("button", { name: "Keep editing" }));
  expect(screen.getByDisplayValue("Line [whispers] 0")).toBeTruthy();
  await selectOtherProject();
  await userEvent.click(await screen.findByRole("button", { name: "Discard changes" }));
  await waitFor(() => expect(action).toHaveBeenCalledWith("/open", { key: "other" }));
});

it("requires distribution confirmation each time the build dialog opens", async () => {
  const ready = structuredClone(project);
  ready.rows = [ {...ready.rows[0], state: "approved"} ];
  ready.coverage = {missing: 0, pending: 0, approved: 1, redo: 0};
  vi.mocked(request).mockImplementation(async path => path === "/project" ? ready : path === "/schema" ? schema : [{key: "current", name: "Test voice"}]);
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", {name: "Build"}));
  const build = screen.getByRole("button", {name: "Build package"}) as HTMLButtonElement;
  expect(build.disabled).toBe(true);
  await userEvent.click(screen.getByRole("checkbox", {name: "I have the rights to distribute these recordings."}));
  expect(build.disabled).toBe(false);
  await userEvent.click(build);
  await waitFor(() => expect(action).toHaveBeenCalledWith("/package", {rightsConfirmed: true}));
  await waitFor(() => expect(build.disabled).toBe(false));
  await userEvent.click(within(screen.getByRole("dialog", {name: "Build voice pack"})).getByRole("button", {name: "Close"}));
  await waitFor(() => expect(screen.queryByRole("dialog", {name: "Build voice pack"})).toBeNull());
  await userEvent.click(screen.getByRole("button", {name: "Build"}));
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
  await userEvent.click(screen.getByRole("button", { name: "Build" }));
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
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
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
      name: /2\. Line 1.*Slot_1/,
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

it("shows alternates after regular takes in both lists and follows that order with Next", async () => {
  const base = project.rows[0];
  const alternate = { ...base, slot: "Alt_Slot_0", text: "Alternate phrase", alternate: true, optional: true, source: base.slot };
  const primary = { ...base, text: "First phrase", optional: true, source: base.slot };
  const mixed = { ...project, rows: [alternate, primary] };
  vi.mocked(request).mockImplementation(async (path) => path === "/project" ? mixed : path === "/schema" ? schema : []);
  render(<App />);
  await screen.findByDisplayValue("First phrase");
  const list = within(screen.getByRole("complementary"));
  const buttons = list.getAllByRole("button", { name: /phrase/ });
  expect(buttons.map((button) => button.getAttribute("aria-current"))).toEqual(["true", null]);
  expect(within(buttons[0]).queryByText("ALT")).toBeNull();
  expect(within(buttons[1]).getByText("ALT")).toBeTruthy();
  await userEvent.click(screen.getByRole("combobox", { name: "Variation" }));
  const options = await screen.findAllByRole("option");
  expect(options[0].textContent).toContain("First phrase");
  expect(within(options[1]).getByText("ALT")).toBeTruthy();
  await userEvent.keyboard("{Escape}");
  await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
  expect(await screen.findByDisplayValue("Alternate phrase")).toBeTruthy();
  expect(screen.getByRole("combobox", { name: "Variation" }).textContent).toContain("2 of 2");
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
    screen.getByRole("region", { name: "Recording guidance" }).querySelector("p")?.textContent,
  ).toBeTruthy();
});
it("puts batch import in the Studio menu and build actions in the pack footer", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
  await userEvent.click(screen.getByRole("button", { name: "Batch import" }));
  const dialog = await screen.findByRole("dialog");
  expect(
    within(dialog).getByRole("button", { name: "Choose audio files" }),
  ).toBeTruthy();
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  await userEvent.click(screen.getByRole("button", { name: "Build" }));
  expect(
    screen.queryByRole("button", { name: "Choose audio files" }),
  ).toBeNull();
  expect(
    screen
      .getByRole("button", { name: "Build package" })
      .closest('[data-slot="dialog-footer"]'),
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
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
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
  expect(screen.queryByRole("button", { name: "Approve filtered" })).toBeNull();
  fireEvent.change(screen.getByLabelText("Find a recording"), {
    target: { value: "Line 0" },
  });
  await userEvent.click(within(document.querySelector(".bulk-review") as HTMLElement).getByRole("button", {name:"Approve filtered"}));
  let dialog = await screen.findByRole("alertdialog");
  expect(
    within(dialog).getByRole("heading", { name: "Approve 1 recordings?" }),
  ).toBeTruthy();
  await userEvent.click(within(dialog).getByRole("button", { name: "Cancel" }));
  expect(action).not.toHaveBeenCalled();
  await userEvent.click(within(document.querySelector(".bulk-review") as HTMLElement).getByRole("button", {name:"Approve filtered"}));
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
  expect(screen.queryByRole("button", { name: "Approve filtered" })).toBeNull();
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
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
  await userEvent.click(
    screen.getByRole("button", { name: "Check audio levels" }),
  );
  expect(
    await screen.findByRole("progressbar", { name: "Checking audio levels" }),
  ).toBeTruthy();
  expect(
    (screen.getByRole("button", { name: "Studio menu" }) as HTMLButtonElement)
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
 expect(screen.getByRole("combobox",{name:"Variation"}).textContent).toContain("1 of 2");
 expect(document.querySelector(".variation-row.selected")?.textContent).toContain("Slot_2");
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
    await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
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

it("keeps acting alternatives separate inside the same delivery",async()=>{
 const mixed=structuredClone(project);
 mixed.rows=mixed.rows.slice(0,3).map((r,i)=>({...r,acting:i===1?'breathless':'unspecified'}));
 vi.mocked(request).mockImplementation(async path=>path==='/project'?mixed:path==='/schema'?schema:[]);
 render(<App/>);await screen.findByDisplayValue('Line 0');
 await userEvent.click(screen.getByRole('combobox',{name:'Acting'}));
 await userEvent.click(await screen.findByRole('option',{name:'Breathless'}));
 await screen.findByDisplayValue('Line 1');
 expect(screen.getByRole('combobox',{name:'Delivery'}).textContent).toContain('Normal');
 const variation = screen.getByRole('combobox', {name: 'Variation'}) as HTMLButtonElement;
 expect(variation.textContent).toContain('1 of 1');
 expect(variation.disabled).toBe(true);
});
it("keeps hidden filters visible as a count and clears them", async () => {
 render(<App />);
 await screen.findByDisplayValue("Line 0");
 expect(screen.queryByRole("combobox", {name:"Category"})).toBeNull();
 await userEvent.click(screen.getByRole("button", {name:"Filters"}));
 await userEvent.click(screen.getByRole("combobox", {name:"Category"}));
 await userEvent.click(await screen.findByRole("option", {name:"Physical (1511)"}));
 await userEvent.click(screen.getByRole("button", {name:"Filters, active"}));
 await waitFor(()=>expect(screen.queryByRole("combobox", {name:"Category"})).toBeNull());
 expect(screen.getByRole("button", {name:"Filters, active"})).toBeTruthy();
 await userEvent.click(screen.getByRole("button", {name:"Clear filters"}));
 expect(screen.getByRole("button", {name:"Filters"})).toBeTruthy();
});

it("opens the recordings needed for an uncovered Core group and drops them after approval", async () => {
  const fixture = structuredClone(project);
  fixture.rows[0].state = "missing";
  fixture.rows[1].state = "pending";
  fixture.buildCoverage = {
    required: 2, covered: 1, missing: ['severity / Thirst / 1'],
    missingSlots: { 'severity / Thirst / 1': ['Slot_0', 'Slot_1'] },
  };
  vi.mocked(request).mockImplementation(async (path) =>
    path === "/project" ? structuredClone(fixture) : [{ key: "current", name: "Test voice" }],
  );
  const user = userEvent.setup();
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await user.click(screen.getByRole("button", { name: "Build" }));
  expect(screen.getByRole("button", { name: "Review in library" })).toBeTruthy();
  await user.click(within(screen.getByRole("dialog")).getByRole("button", { name: /Thirst.*Level 1.*Needs listening/ }));
  expect(screen.getByDisplayValue("Line 1")).toBeTruthy();
  expect(screen.getByRole("combobox", { name: "Recording status" }).textContent).toContain("Required gaps (2)");
  expect(screen.getByLabelText("Required groups for this take").textContent).toContain("Thirst · Level 1");
  expect(within(screen.getByRole("complementary")).getByText("Line 1")).toBeTruthy();
  expect(screen.queryByText("Line 2")).toBeNull();

  fixture.buildCoverage = { required: 2, covered: 2, missing: [], missingSlots: {} };
  fixture.rows[1].state = "approved";
  await user.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", { name: "Approve" }));
  await waitFor(() => expect(screen.queryByLabelText("Required groups for this take")).toBeNull());
  expect(within(screen.getByRole("complementary")).queryByText("Line 1")).toBeNull();
});


it("continues from the approved take in Required gaps instead of jumping to the first row", async () => {
  const fixture = structuredClone(project);
  fixture.rows = fixture.rows.slice(0, 5).map((row) => ({ ...row, context: "Thirst", state: "pending" }));
  const pools = { first: ["Slot_0"], coveredTogether: ["Slot_1", "Slot_2"], later: ["Slot_3"], last: ["Slot_4"] };
  fixture.buildCoverage = { required: 4, covered: 0, missing: Object.keys(pools), missingSlots: pools, pools };
  vi.mocked(request).mockImplementation(async (path) =>
    path === "/project" ? fixture : [{ key: "current", name: "Test voice" }],
  );
  vi.mocked(action).mockImplementation(async (_, data) => {
    const { slot } = data as { slot: string };
    return { row: { ...fixture.rows.find((row) => row.slot === slot), state: "approved" } };
  });

  const user = userEvent.setup();
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await user.click(screen.getByRole("combobox", { name: "Recording status" }));
  await user.click(await screen.findByRole("option", { name: "Required gaps (5)" }));
  const library = within(screen.getByRole("complementary"));
  const approve = () => user.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", { name: "Approve" }));
  await user.click(library.getByRole("button", { name: /Line 1\s*Slot_1/ }));
  await approve();
  expect(await screen.findByDisplayValue("Line 3")).toBeTruthy();
  expect(library.queryByRole("button", { name: /Line 2\s*Slot_2/ })).toBeNull();

  await user.click(library.getByRole("button", { name: /Line 4\s*Slot_4/ }));
  await approve();
  expect(await screen.findByDisplayValue("Line 3")).toBeTruthy();
});

it("chooses the next recording from refreshed coverage when a workbench omits its pools", async () => {
  const fixture = structuredClone(project);
  fixture.rows = fixture.rows.slice(0, 4).map((row) => ({ ...row, context: "Thirst", state: "pending" }));
  const missingSlots = { first: ["Slot_0"], shared: ["Slot_1", "Slot_2"], last: ["Slot_3"] };
  fixture.buildCoverage = { required: 3, covered: 0, missing: Object.keys(missingSlots), missingSlots };
  vi.mocked(request).mockImplementation(async (path) => path === "/project" ? structuredClone(fixture) : path === "/schema" ? schema : []);
  vi.mocked(action).mockImplementation(async () => {
    fixture.rows[1].state = "approved";
    fixture.buildCoverage = { required: 3, covered: 1, missing: ["first", "last"], missingSlots: { first: ["Slot_0"], last: ["Slot_3"] } };
    return { row: fixture.rows[1] };
  });

  const user = userEvent.setup();
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await user.click(screen.getByRole("combobox", { name: "Recording status" }));
  await user.click(await screen.findByRole("option", { name: "Required gaps (4)" }));
  await user.click(within(screen.getByRole("complementary")).getByRole("button", { name: /Line 1\s*Slot_1/ }));
  await user.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button", { name: "Approve" }));
  expect(await screen.findByDisplayValue("Line 3")).toBeTruthy();
  expect(screen.getByRole("combobox", { name: "Recording status" }).textContent).toContain("Required gaps (2)");
});

it("opens the audio picker with Alt+I and lists Import audio as a command", async () => {
  render(<App />);
  await screen.findByRole("button", { name: "Import audio" });
  const input = document.querySelector<HTMLInputElement>('input[type="file"]');
  expect(input).not.toBeNull();
  const click = vi.spyOn(input!, "click");
  fireEvent.keyDown(document.body, { key: "i", code: "KeyI", altKey: true });
  expect(click).toHaveBeenCalledTimes(1);
  fireEvent.keyDown(window, { key: "k", ctrlKey: true });
  expect(await screen.findByRole("option", { name: /Import audio/ })).toBeTruthy();
});


it("shows a single Core acting tag and filters by it without a suggestion panel", async () => {
  const tagged = structuredClone(project);
  tagged.rows = tagged.rows.slice(0, 2).map((r, i) => ({...r, context: i ? "EngineFailed" : "EngineRecovered", acting: i ? "frustrated" : "relieved"}));
  vi.mocked(request).mockImplementation(async path => path === "/project" ? tagged : path === "/schema" ? schema : []);
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(screen.getByRole("combobox", {name: "Acting"}).textContent).toContain("Relieved");
  expect(screen.queryByLabelText("Suggested acting")).toBeNull();
  await userEvent.click(screen.getByRole("button", {name: /Filters/}));
  await userEvent.click(screen.getByRole("combobox", {name: "Filter acting"}));
  await userEvent.click(await screen.findByRole("option", {name: /Frustrated/}));
  await screen.findByDisplayValue("Line 1");
});


it("covers the screen until initial project loading finishes", async () => {
  let finish!: (value: Project) => void;
  const pending = new Promise<Project>(resolve => { finish = resolve; });
  vi.mocked(request).mockImplementation(async path => path === "/project" ? pending : path === "/schema" ? schema : []);
  render(<App />);
  expect(await screen.findByRole("dialog", {name: "Opening project…"})).toBeTruthy();
  fireEvent.keyDown(document.body, {key: "Escape"});
  expect(screen.getByRole("dialog", {name: "Opening project…"})).toBeTruthy();
  finish(structuredClone(project));
  await waitFor(() => expect(screen.queryByRole("dialog", {name: "Opening project…"})).toBeNull());
  await screen.findByDisplayValue("Line 0");
});

it("removes the opening screen when loading fails", async () => {
  vi.mocked(request).mockRejectedValue(new Error("Project unavailable"));
  render(<App />);
  await waitFor(() => expect(screen.queryByRole("dialog", {name: "Opening project…"})).toBeNull());
  expect(await screen.findByText("Project could not be opened.")).toBeTruthy();
});

it("keeps the library in place when toggling groups and scrolls for Next", async () => {
  const data = { ...project, rows: project.rows.slice(0, 4) };
  vi.mocked(request).mockImplementation(async path => path === "/project" ? data : path === "/schema" ? schema : []);
  const previousScroll = HTMLElement.prototype.scrollIntoView;
  const scroll = vi.fn();
  HTMLElement.prototype.scrollIntoView = scroll;
  try {
    render(<App />);
    await screen.findByDisplayValue("Line 0");
    const group = screen.getByRole("button", { name: /Situation1/ });
    await userEvent.click(group);
    expect(group.getAttribute("aria-expanded")).toBe("true");
    expect(scroll).not.toHaveBeenCalled();
    expect(screen.getByDisplayValue("Line 0")).toBeTruthy();
    await userEvent.click(screen.getByRole("button", { name: "Next recording" }));
    await waitFor(() => expect(scroll).toHaveBeenCalledExactlyOnceWith({ block: "nearest" }));
    await userEvent.click(group);
    expect(scroll).toHaveBeenCalledTimes(1);
  } finally {
    HTMLElement.prototype.scrollIntoView = previousScroll;
  }
});

it("hides the ElevenLabs balance when there is no connection", async () => {
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  expect(screen.queryByRole("button", { name: /ElevenLabs balance/ })).toBeNull();
  expect(request).not.toHaveBeenCalledWith("/elevenlabs/credits");
});

it("explains a failed balance lookup and shows the balance after retry", async () => {
  let creditRequests = 0;
  const linked = { ...project, rows: [project.rows[0]], elevenLabs: { configured: true, voice: "selected" } };
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/elevenlabs/credits") {
      if (++creditRequests === 1) throw new Error("ElevenLabs did not respond in time.");
      return { used: 12, limit: 100, remaining: 88 };
    }
    return [];
  });
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
  expect(await screen.findByText("ElevenLabs did not respond in time.")).toBeTruthy();
  expect(screen.queryByRole("button", { name: /^ElevenLabs balance/ })).toBeNull();
  await userEvent.click(screen.getByRole("button", { name: "Retry ElevenLabs balance" }));
  expect(await screen.findByRole("button", { name: "ElevenLabs balance, 88% remaining, 88 credits left" })).toBeTruthy();
});

it("advances within the active review filter and scrolls the selected slot", async () => {
 const data = structuredClone(project);
 data.rows = data.rows.slice(0,4).map((row,i)=>({...row,state:i===1 ? "approved" : "pending"}));
 data.coverage={missing:0,pending:3,approved:1,redo:0};
 vi.mocked(request).mockImplementation(async path=>path==="/project" ? data : path==="/schema" ? schema : [{key:"current",name:"Test voice"}]);
 vi.mocked(action).mockResolvedValue({row:{slot:"Slot_0",text:"Line 0",direction:"",state:"approved"}});
 const scroll = vi.fn();
 HTMLElement.prototype.scrollIntoView=scroll;
 render(<App/>);
 await screen.findByDisplayValue("Line 0");
 await userEvent.click(screen.getByRole("combobox",{name:"Recording status"}));
 await userEvent.click(await screen.findByRole("option",{name:/Needs listening/}));
 await userEvent.click(within(document.querySelector(".review-actions") as HTMLElement).getByRole("button",{name:"Approve"}));
 await waitFor(()=>expect((screen.getByRole("textbox",{name:"Spoken text / caption"}) as HTMLTextAreaElement).value).toBe("Line 2"));
 await waitFor(()=>expect(scroll).toHaveBeenCalledWith({block:"nearest"}));
});

it("explains inline tag placement and captions without changing the recording draft", async () => {
  const turkish = {
    ...project, language: "TR", rows: [project.rows[0]],
    elevenLabs: { configured: true, voice: "studio-voice" },
  };
  vi.mocked(request).mockImplementation(async (path) => path === "/project" ? turkish : path === "/schema" ? schema : path === "/elevenlabs/credits" ? { used: 0, limit: 100, remaining: 100 } : []);
  render(<App />);
  const editor = await screen.findByRole("textbox", { name: "Spoken text / caption" }) as HTMLTextAreaElement;
  fireEvent.change(editor, { target: { value: "[whispers] Biraz bekleyelim." } });

  const trigger = screen.getByRole("button", { name: "Audio tag guide" });
  await userEvent.click(trigger);
  const guide = within(await screen.findByRole("dialog", { name: "Audio tag guide" }));
  const examples = guide.getByRole("region", { name: "Tag placement" });
  expect(examples.textContent).toContain("[whispers] I think they're still outside.");
  expect(examples.textContent).toContain("I had it… [steadier voice] Let me try again.");
  expect(examples.textContent).toContain("We're safe for now. [exhales]");
  await userEvent.keyboard("{Escape}");
  await waitFor(() => expect(screen.queryByRole("dialog", { name: "Audio tag guide" })).toBeNull());
  expect(editor.value).toBe("[whispers] Biraz bekleyelim.");
  expect(action).not.toHaveBeenCalled();
});

it("highlights inline tags and blocks saving an unmatched or doubled bracket", async () => {
  render(<App />);
  const editor = await screen.findByRole("textbox", { name: "Spoken text / caption" });
  fireEvent.change(editor, { target: { value: "[[whispers]] Line 0" } });
  expect(screen.getByText("Use one pair of square brackets per audio tag.")).toBeTruthy();
  expect((screen.getByRole("button", { name: "Save" }) as HTMLButtonElement).disabled).toBe(true);
  fireEvent.change(editor, { target: { value: "[whispers Line 0" } });
  expect(editor.getAttribute("aria-invalid")).toBe("true");
  fireEvent.change(editor, { target: { value: "whispers Line 0" } });
  expect(screen.getByText("If this is an audio cue, put it in square brackets [ ].")).toBeTruthy();
  expect((screen.getByRole("button", { name: "Save" }) as HTMLButtonElement).disabled).toBe(false);
  fireEvent.change(editor, { target: { value: "[whispers] Line 0" } });
  expect(editor.getAttribute("aria-invalid")).toBeNull();
  expect(document.querySelector(".caption-mirror .caption-inline-tag.text-primary")).toBeTruthy();
});

it("shows credits and previews a selected take without changing it before acceptance", async () => {
  const linked = { ...project, rows: [project.rows[0]], elevenLabs: { configured: true, voice: "my-private-voice" } };
  const script = "[low voice] Line [short breath] 0 [sighs]";
  vi.mocked(action).mockResolvedValue({ row: { ...project.rows[0], speechScript: script } });
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/elevenlabs/credits") return { used: 66, limit: 1300, remaining: 1234 };
    if (path === "/elevenlabs/describe") return { result: {
      prompt: script, characterCount: script.length, estimatedCredits: script.length,
    } };
    if (path === "/elevenlabs/generate") return { result: { id: "candidate" } };
    if (path === "/elevenlabs/preview?id=candidate") return { ready: true, cost: 17 };
    if (path === "/audio/elevenlabs?id=candidate") return new Blob([], { type: "audio/mpeg" });
    if (path === "/elevenlabs/accept") return { result: {} };
    return [{ key: "current", name: "Test voice" }];
  });

  render(<App />);
  await userEvent.hover(await screen.findByRole("button", { name: "ElevenLabs balance, 95% remaining, 1,234 credits left" }));
  expect(await screen.findByText("1,234 credits")).toBeTruthy();
  await userEvent.unhover(screen.getByRole("button", { name: "ElevenLabs balance, 95% remaining, 1,234 credits left" }));
  const editor = screen.getByRole("textbox", { name: "Spoken text / caption" }) as HTMLTextAreaElement;
  fireEvent.change(editor, { target: { value: script } });
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  await waitFor(() => expect(action).toHaveBeenCalledWith("/save", expect.objectContaining({ text: script })));
  expect(editor.value).toBe(script);
  await userEvent.click(await screen.findByRole("button", { name: "Generate audio" }));
  expect((await within(await screen.findByRole("dialog", { name: "Generate with ElevenLabs" })).findByText("[short breath]")).classList.contains("text-primary")).toBe(true);
  expect(screen.getByText("Estimated credits")).toBeTruthy();
  expect(screen.queryByRole("combobox", { name: "Add audio tag" })).toBeNull();
  expect(vi.mocked(request).mock.calls.some(([path]) => path === "/elevenlabs/generate")).toBe(false);
  await userEvent.click(screen.getByRole("button", { name: "Generate preview" }));
  const accept = await screen.findByRole("button", { name: "Use this take" });
  expect(vi.mocked(request).mock.calls.some(([path]) => path === "/elevenlabs/accept")).toBe(false);
  await userEvent.click(accept);
  await waitFor(() => expect(request).toHaveBeenCalledWith(
    "/elevenlabs/accept", { project: "current", slot: "Slot_0", id: "candidate" }, {}, true, true,
  ));
});

it("lists voice IDs and flags only for the active project language", async () => {
  const linked = {
    ...project, rows: [project.rows[0]], language: "TR",
    elevenLabs: { configured: true, voice: "private-tr-id", languageCode: "TR" },
  };
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path.startsWith("/elevenlabs/voices")) return {
      voices: [
        ...(path.endsWith("search=English") ? [] : [{ id: "private-tr-id", name: "My private voice", languages: ["TR"], owned: true }]),
        { id: "english-voice", name: "English voice", languages: ["EN", "TR"], primaryLanguage: "EN" },
      ],
      next: null,
    };
    if (path.startsWith("/elevenlabs/library")) return {
      voices: [{ id: "public-tr", name: "Turkish library voice", owner: "public-owner", primaryLanguage: "TR" }],
      next: null,
    };
    if (path === "/elevenlabs/settings") return { result: { voice: "copied-tr" } };
    if (path === "/elevenlabs/credits") return { used: 1, limit: 100, remaining: 99 };
    return [{ key: "current", name: "Test voice" }];
  });
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
  await userEvent.click(screen.getByRole("button", { name: "ElevenLabs settings" }));
  const select = await screen.findByRole("combobox", { name: "ElevenLabs voice" });
  await waitFor(() => expect(select.textContent).toContain("private-tr-id"));
  expect(select.querySelector("img")?.getAttribute("src")).toBe("/studio/flag/TR");
  await userEvent.click(select);
  const personal = await screen.findByRole("option", { name: /My private voice/ });
  expect(screen.getAllByRole("option")[0]).toBe(personal);
  expect(screen.queryByRole("option", { name: /English voice/ })).toBeNull();
  const libraryVoice = await screen.findByRole("option", { name: /Turkish library voice/ });
  expect(libraryVoice.querySelector("img")?.getAttribute("src")).toBe("/studio/flag/TR");
  await userEvent.click(libraryVoice);
  await userEvent.click(screen.getByRole("button", { name: "Add to My Voices and use" }));
  await waitFor(() => expect(request).toHaveBeenCalledWith(
    "/elevenlabs/settings", { project: "current", voice: "public-tr", owner: "public-owner", name: "Turkish library voice" }, {}, true, true,
  ));
});

it("offers My Voices while the Voice Library is still loading", async () => {
  let failLibrary!: (error: Error) => void;
  const library = new Promise((_resolve, reject) => { failLibrary = reject; });
  const voice = { id: "personal-en", name: "Personal voice", languages: ["EN"], owned: true };
  const linked = { ...project, rows: [project.rows[0]], elevenLabs: { configured: true, voice: "", languageCode: "EN" } };
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/elevenlabs/credits") return { used: 3, limit: 100, remaining: 97 };
    if (path.startsWith("/elevenlabs/voices")) return { voices: [voice], next: null };
    if (path.startsWith("/elevenlabs/library")) return library;
    return [];
  });
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  await userEvent.click(screen.getByRole("button", { name: "Studio menu" }));
  await userEvent.click(screen.getByRole("button", { name: "ElevenLabs settings" }));
  await userEvent.click(await screen.findByRole("combobox", { name: "ElevenLabs voice" }));
  expect(await screen.findByRole("option", { name: /Personal voice/ })).toBeTruthy();
  expect(screen.getByText("Loading voices…")).toBeTruthy();
  failLibrary(new Error("ElevenLabs did not respond in time."));
  expect(await screen.findByText("Voice Library: ElevenLabs did not respond in time.")).toBeTruthy();
  expect(screen.getByRole("option", { name: /Personal voice/ })).toBeTruthy();
  expect(screen.getByRole("button", { name: "Retry voices" })).toBeTruthy();
});

it("keeps the player loading while an imported take is uploaded and fetched", async () => {
  let finishImport!: () => void;
  let finishAudio!: (blob: Blob) => void;
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return { ...project, rows: [project.rows[0]] };
    if (path === "/schema") return schema;
    if (path === "/import") return new Promise<void>((resolve) => { finishImport = resolve; });
    if (path === "/audio?slot=Slot_0") return new Promise<Blob>((resolve) => { finishAudio = resolve; });
    return [{ key: "current", name: "Test voice" }];
  });
  render(<App />);
  await screen.findByDisplayValue("Line 0");
  const file = new File(["audio"], "take.mp3", { type: "audio/mpeg" });
  const input = document.querySelector('input[type="file"]:not([multiple])')!;
  fireEvent.change(input, { target: { files: [file] } });
  expect(await screen.findByText("Importing audio…")).toBeTruthy();
  finishImport();
  expect(await screen.findByText("Loading the imported take…")).toBeTruthy();
  await waitFor(() => expect(request).toHaveBeenCalledWith("/audio?slot=Slot_0"));
  finishAudio(new Blob([], { type: "audio/mpeg" }));
  await waitFor(() => expect(screen.queryByText("Loading the imported take…")).toBeNull());
  expect(await screen.findByRole("button", { name: "Play recording" })).toBeTruthy();
});


it("keeps the trait direction visible and hides ElevenLabs extras without an active project voice", async () => {
  const withoutVoice: Project = {
    ...project,
    elevenLabs: { configured: true, voice: "" },
    rows: [{
      ...project.rows[0],
      acting: "controlled",
      playbackWhen: "During a close attack.",
      traitRule: { kind: "required", traits: ["Brave", "Desensitized"], description: "Only Brave or Desensitized survivors use this take." },
      traits: ["Brave", "Desensitized"],
      guidance: "Keep the urgency in the pace.",
      elevenLabsTags: ["[urgent but steady]"],
    }],
  };
  vi.mocked(request).mockImplementation(async (path) =>
    path === "/project" ? withoutVoice : path === "/schema" ? schema : path === "/elevenlabs/credits" ? { used: 0, limit: 100, remaining: 100 } : []);
  render(<App />);
  const guidance = within(await screen.findByRole("region", { name: "Recording guidance" }));
  expect(guidance.getByText("Keep the urgency in the pace.")).toBeTruthy();
  expect(guidance.queryByText("Recommended tags")).toBeNull();
  expect(guidance.queryByRole("button", { name: "Audio tag guide" })).toBeNull();
  const playback = within(screen.getByRole("region", { name: "When it plays" }));
  expect(playback.getByText("During a close attack.")).toBeTruthy();
  expect(playback.getByText("Requires one of")).toBeTruthy();
  expect(playback.getByRole("button", { name: "Filter by Brave" })).toBeTruthy();
  expect(playback.getByText("Only Brave or Desensitized survivors use this take.")).toBeTruthy();
});

it("changes the gameplay rule and direction with the selected performance, including whispered takes", async () => {
  const base = { ...project.rows[0], context: "MortalFear", playbackWhen: "A panicked survivor is attacked." };
  const required = { kind: "required" as const, traits: ["Brave", "Desensitized"], description: "Brave or Desensitized survivors use the controlled line first." };
  const fixture = { ...project, rows: [
    { ...base, slot: "Base", acting: "frightened", text: "Please...", guidance: "Let your voice shake." },
    { ...base, slot: "Quiet", acting: "frightened", delivery: "whisper", text: "Please...", guidance: "Whisper unevenly." },
    { ...base, slot: "Steady", acting: "controlled", text: "Keep moving.", traitRule: required, guidance: "Keep the urgency in the pace." },
    { ...base, slot: "QuietSteady", acting: "controlled", delivery: "whisper", text: "Keep moving.", traitRule: required, guidance: "Whisper each word evenly.", playbackWhen: "A sneaking survivor faces danger." },
  ] };
  vi.mocked(request).mockImplementation(async (path) => path === "/project" ? fixture : path === "/schema" ? schema : []);
  render(<App />);
  const playback = within(await screen.findByRole("region", { name: "When it plays" }));
  const guidance = within(screen.getByRole("region", { name: "Recording guidance" }));
  expect(playback.getByText("No trait required.")).toBeTruthy();
  await userEvent.click(screen.getByRole("combobox", { name: "Acting" }));
  await userEvent.click(await screen.findByRole("option", { name: "Controlled" }));
  expect(await screen.findByDisplayValue("Keep moving.")).toBeTruthy();
  expect(playback.getByText("Requires one of")).toBeTruthy();
  expect(guidance.getByText("Keep the urgency in the pace.")).toBeTruthy();
  await userEvent.click(screen.getByRole("combobox", { name: "Delivery" }));
  await userEvent.click(await screen.findByRole("option", { name: "Whisper" }));
  expect(screen.getByRole("combobox", { name: "Acting" }).textContent).toContain("Controlled");
  expect(playback.getByText("A sneaking survivor faces danger.")).toBeTruthy();
  expect(guidance.getByText("Whisper each word evenly.")).toBeTruthy();
  expect(action).not.toHaveBeenCalled();
});

it("toggles trait filters from recording rules and keeps the sidebar selector in sync", async () => {
  const traitRule = { kind: "conditional" as const, traits: ["Slow Learner"], description: "This also plays after finishing a skill book." };
  const fixture = { ...project, rows: [
    { ...project.rows[0], context: "Research", traitRule },
    { ...project.rows[1], context: "Hungry", traits: ["Hearty Appetite"] },
    { ...project.rows[2], context: "Reading", traits: ["Slow Learner"] },
  ] };
  vi.mocked(request).mockImplementation(async path => path === "/project" ? fixture : path === "/schema" ? schema : []);
  render(<App />);
  const trait = await screen.findByRole("button", { name: "Filter by Slow Learner" });
  const library = within(screen.getByRole("complementary"));
  fireEvent.change(screen.getByLabelText("Spoken text / caption"), { target: { value: "Draft" } });
  await userEvent.click(trait);
  await userEvent.click(within(await screen.findByRole("alertdialog")).getByRole("button", { name: "Keep editing" }));
  expect(screen.getByDisplayValue("Draft")).toBeTruthy();
  expect(trait.getAttribute("aria-pressed")).toBe("false");
  await userEvent.click(screen.getByRole("button", { name: "Cancel" }));
  await userEvent.click(trait);
  expect(trait.getAttribute("aria-pressed")).toBe("true");
  expect(library.queryByRole("button", { name: /Hungry/ })).toBeNull();
  expect(library.getByRole("button", { name: /Reading/ })).toBeTruthy();
  await userEvent.click(library.getByRole("button", { name: /Filters/ }));
  expect(library.getByRole("combobox", { name: "Trait" }).textContent).toContain("Slow Learner (2)");
  await userEvent.click(trait);
  expect(library.getByRole("combobox", { name: "Trait" }).textContent).toContain("All traits");
  expect(library.getByRole("button", { name: /Hungry/ })).toBeTruthy();
});

it("keeps navigation available during transcription and leaves the next caption alone", async () => {
  const linked = { ...project, rows: project.rows.slice(0, 2), elevenLabs: { configured: true, voice: "" } };
  let finishTranscription!: (response: { result: { text: string } }) => void;
  const transcription = new Promise((resolve) => { finishTranscription = resolve; });
  vi.mocked(request).mockImplementation(async (path) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/elevenlabs/transcribe") return transcription;
    if (path === "/elevenlabs/credits") return { used: 0, limit: 100, remaining: 100 };
    return [];
  });
  render(<App />);
  await userEvent.click(await screen.findByRole("button", { name: "Transcribe" }));
  const confirmation = await screen.findByRole("alertdialog");
  await userEvent.click(within(confirmation).getByRole("button", { name: "Transcribe" }));
  expect(await screen.findByText("Transcribing audio…")).toBeTruthy();
  await userEvent.click(screen.getByText("Line 1"));
  await screen.findByDisplayValue("Line 1");
  await act(async () => finishTranscription({ result: { text: "Transcript for line zero" } }));
  expect(screen.queryByText("Transcribing audio…")).toBeNull();
  expect(screen.getByDisplayValue("Line 1")).toBeTruthy();
  expect(screen.queryByDisplayValue("Transcript for line zero")).toBeNull();
});

it("puts a generated line in the caption editor without saving it", async () => {
  const linked = { ...project, rows: project.rows.slice(0, 2), dialogueGeneration: true };
  let finishFirstDrafts!: (response: { result: { options: string[] } }) => void;
  const firstDrafts = new Promise<{ result: { options: string[] } }>((resolve) => { finishFirstDrafts = resolve; });
  vi.mocked(request).mockImplementation(async (path, data) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/dialogue/suggest") {
      return (data as { previous_drafts?: string[] }).previous_drafts
        ? { result: { options: ["I need cover."] } } : firstDrafts;
    }
    return [];
  });
  render(<App />);
  await userEvent.click(await screen.findByRole("button", { name: "Generate text" }));
  const modal = await screen.findByRole("dialog");
  await userEvent.selectOptions(within(modal).getByLabelText("Drafts per recording"), "2");
  await userEvent.click(within(modal).getByRole("button", { name: "Generate drafts" }));
  expect(vi.mocked(request).mock.calls.some(([route, body]) => route === "/dialogue/suggest"
    && (body as { dialogue_count?: number }).dialogue_count === 2)).toBe(true);
  expect(within(modal).getByRole("status").querySelectorAll('[data-slot="draft-skeleton"]')).toHaveLength(2);
  finishFirstDrafts({ result: { options: ["Keep moving.", "Find some cover."] } });
  await userEvent.click(await within(modal).findByRole("button", { name: "Retry" }));
  expect(vi.mocked(request).mock.calls.some(([route, body]) => route === "/dialogue/suggest"
    && (body as { previous_drafts?: string[] }).previous_drafts?.includes("Find some cover."))).toBe(true);
  await userEvent.click(await within(modal).findByRole("button", { name: "I need cover." }));
  const draftEditor = await screen.findByDisplayValue("I need cover.");
  expect(screen.getByText("Unsaved changes")).toBeTruthy();
  expect(draftEditor.getAttribute("aria-describedby")).toContain("caption-unsaved");
  await userEvent.click(screen.getByRole("button", { name: "Cancel" }));
  expect(screen.queryByText("Unsaved changes")).toBeNull();
  expect(vi.mocked(request).mock.calls.some(([route]) => route === "/save")).toBe(false);
});

it("connects Gemini from Generate text and offers key replacement in the menu", async () => {
  const linked = {
    ...project, rows: project.rows.slice(0, 2), elevenLabs: { configured: true, voice: "" },
    dialogueModel: "gemini-3.5-flash-lite",
    dialogueModels: { "gemini-3.5-flash-lite": "Gemini 3.5 Flash-Lite", "gemini-3.5-flash": "Gemini 3.5 Flash" },
  };
  vi.mocked(request).mockImplementation(async (path, body) => {
    if (path === "/project") return linked;
    if (path === "/schema") return schema;
    if (path === "/elevenlabs/credits") return { limit: 100, used: 10, remaining: 90 };
    if (path === "/dialogue/connect") return { result: { configured: true, model: (body as { model?: string })?.model } };
    if (path === "/dialogue/usage") return { requestsLastDay: 7, inputTokensLastMinute: 1234 };
    if (path === "/dialogue/history") return [
      { id: "first-request", slot: project.rows[0].slot, status: "generated", draftCount: 2, time: "2026-11-19T00:00:00Z" },
    ];
    return [];
  });
  const user = userEvent.setup();
  render(<App />);
  await user.click(await screen.findByRole("button", { name: "Generate text" }));
  const dialog = await screen.findByRole("dialog");
  const input = within(dialog).getByLabelText("Gemini API key") as HTMLInputElement;
  expect(input.type).toBe("password");
  await user.type(input, "AQ.test_gemini_key_for_ui");
  await user.click(within(dialog).getByRole("button", { name: "Connect" }));
  expect(await within(dialog).findByRole("button", { name: "Generate drafts" })).toBeTruthy();
  expect(request).toHaveBeenCalledWith("/dialogue/connect", { key: "AQ.test_gemini_key_for_ui" }, {}, true, false);
  await user.click(within(dialog).getByRole("button", { name: "Close" }));
  expect(screen.getByRole("button", { name: /ElevenLabs balance, 90% remaining/ })).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Studio menu" }));
  expect(screen.getByRole("region", { name: "ElevenLabs usage" })).toBeTruthy();
  expect(screen.queryByRole("button", { name: "Gemini usage" })).toBeNull();
  const panel = screen.getByRole("region", { name: "Gemini usage" });
  expect(await within(panel).findByText("1,234")).toBeTruthy();
  expect(within(panel).getByRole("link", { name: "Project limits" })).toBeTruthy();
  await user.click(within(panel).getByRole("button", { name: "History" }));
  const history = await screen.findByRole("dialog", { name: "Gemini history" });
  expect(await within(history).findByText("2 drafts generated")).toBeTruthy();
  await user.click(within(history).getByRole("button", { name: "Close" }));
  await user.click(screen.getByRole("button", { name: "Studio menu" }));
  await user.click(within(screen.getByRole("region", { name: "Gemini usage" })).getByRole("button", { name: "Settings" }));
  const settings = await screen.findByRole("dialog", { name: "Gemini settings" });
  expect(within(settings).getByLabelText("Gemini API key").getAttribute("placeholder")).toBe("Replace API key");
  const model = within(settings).getByRole<HTMLSelectElement>("combobox", { name: "Dialogue model" });
  expect(model.value).toBe("gemini-3.5-flash-lite");
  await user.selectOptions(model, "gemini-3.5-flash");
  await user.click(within(settings).getByRole("button", { name: "Save model" }));
  expect(request).toHaveBeenCalledWith("/dialogue/connect", { model: "gemini-3.5-flash" }, {}, true, false);
});

it("opens Gemini setup from the Studio menu before a key is connected", async () => {
  render(<App />);
  const user = userEvent.setup();
  await user.click(await screen.findByRole("button", { name: "Studio menu" }));
  await user.click(screen.getByRole("button", { name: "Connect Gemini" }));
  const settings = await screen.findByRole("dialog", { name: "Gemini settings" });
  expect(within(settings).getByLabelText("Gemini API key").getAttribute("placeholder")).toBe("Paste API key");
});
