import { Dialog as LoadingDialog } from "@base-ui/react/dialog";
import languageNames from "@studio-languages";
import { useEffect, useMemo, useRef, useState } from "react";
import type { FormEvent } from "react";
import {
  Check,
  ChevronUp,
  ListFilter,
  ChevronLeft,
  ChevronRight,
  Headphones,
  Search,
  Upload,
  Github,
  Download,
  Terminal,
  Mic,
  LoaderCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Form } from "@/components/ui/form";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { ScrollArea } from "@/components/ui/scroll-area";
import { TooltipProvider } from "@/components/ui/tooltip";
import { Choice, Fold, Modal, useConfirm, ActionTip, Hint } from "./controls";
import { MicrophoneTake } from "./MicrophoneTake";
import { AudioPlayer } from "./AudioPlayer";
import { ProjectPicker, SearchChoice } from "./SearchChoice";
import {
  Collapsible,
  CollapsibleTrigger,
  CollapsiblePanel,
} from "@/components/ui/collapsible";
import { AudioEdit } from "./AudioEdit";
import { action, request, setRevision, RequestError } from "./api";
import {
  emptyFilters,
  filterRows,
  coverageLabel,
  label,
  groupRows,
  stateNames,
} from "./model";
import type { Project, Row, Schema, State } from "./model";

import { ToastProvider, toastManager } from "@/components/ui/toast";
import {
  Command,
  CommandDialog,
  CommandDialogPopup,
  CommandInput,
  CommandPanel,
  CommandList,
  CommandItem,
  CommandEmpty,
  CommandShortcut,
} from "@/components/ui/command";
const audioFileTypes = ".wav,.flac,.mp3,.ogg,.opus,.m4a,.mp4,.aac,.webm";
const PAGE = 50;

const languageOptions = Object.entries(languageNames)
  .map(([code, name]) => ({ value: code, label: `${name} (${code})` }))
  .sort((a, b) => a.label.localeCompare(b.label));

export default function App() {
  const [rightsConfirmed, setRightsConfirmed] = useState(false);
  const [commandsOpen, setCommandsOpen] = useState(false);
  const [operation, setOperation] = useState("");
  const [projectLoading, setProjectLoading] = useState("Opening project…");
  const playerControl = useRef<{ toggle: () => void }>(null);
  const { confirm, dialog } = useConfirm();
  const [audioDirty, setAudioDirty] = useState(false),
    [editReset, setEditReset] = useState(0);
  const [project, setProject] = useState<Project | null>(null),
    [schema, setSchema] = useState<Schema | null>(null);
  const [selected, setSelected] = useState(""),
    [filters, setFilters] = useState(emptyFilters),
    [page, setPage] = useState(0);
  const [modal, setModal] = useState<
      "project" | "prepare" | "import" | "create" | "open-pack" | "microphone" | null
    >(null),
    [busy, setBusy] = useState(false),
    [message, setMessage] = useState("Opening project…"),
    [error, setError] = useState("");
  useEffect(() => {
    setRightsConfirmed(false);
  }, [modal, project?.projectKey]);
  const [text, setText] = useState("");
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const [report, setReport] = useState<Record<string, unknown> | null>(null),
    [projects, setProjects] = useState<{ key: string; name: string }[]>([]);
  const [metadata, setMetadata] = useState({
      name: "",
      author: "",
      steamProfile: "",
      description: "",
      packVersion: "",
    }),
    [newProject, setNewProject] = useState({
      voice: "",
      name: "",
      language: "EN",
      female: false,
      trial: false,
    });
  const [metadataDirty, setMetadataDirty] = useState(false);
  const [playerEpoch, setPlayerEpoch] = useState(0);
  const importRef = useRef<HTMLInputElement>(null),
    batchRef = useRef<HTMLInputElement>(null),
    listRef = useRef<HTMLDivElement>(null);
  const selectedRow = project?.rows.find((r) => r.slot === selected);
  const textDirty = !!selectedRow && text !== selectedRow.text;
  const dirty = textDirty || audioDirty;
  const missingBySlot = useMemo(() => {
    const bySlot = new Map<string, string[]>();
    for (const [group, slots] of Object.entries(
      project?.buildCoverage?.missingSlots ?? {},
    )) {
      for (const slot of slots) {
        const groups = bySlot.get(slot) ?? [];
        groups.push(group);
        bySlot.set(slot, groups);
      }
    }
    return bySlot;
  }, [project]);
  const requiredSlots = useMemo(
    () => new Set(missingBySlot.keys()),
    [missingBySlot],
  );
  const filtered = useMemo(
    () => filterRows(project?.rows || [], filters, requiredSlots),
    [project, filters, requiredSlots],
  );
  const grouped = useMemo(() => groupRows(filtered), [filtered]);
  const navigationRows = useMemo(
    () => grouped.flatMap((group) => group.variations),
    [grouped],
  );
  const pageCount = Math.max(1, Math.ceil(grouped.length / PAGE)),
    currentPage = Math.min(page, pageCount - 1);
  const visible = grouped.slice(currentPage * PAGE, (currentPage + 1) * PAGE);
  const situationRows = filtered.filter(
    (r) => r.context === selectedRow?.context,
  );
  const deliveries = Array.from(new Set(situationRows.map((r) => r.delivery)));
  const actingOptions = Array.from(
    new Set(
      situationRows
        .filter((row) => row.delivery === selectedRow?.delivery)
        .map((row) => row.acting || "unspecified"),
    ),
  );
  const variations = situationRows.filter(
    (r) =>
      r.delivery === selectedRow?.delivery &&
      (r.acting || "unspecified") === (selectedRow?.acting || "unspecified"),
  );
  useEffect(() => {
    if (selectedRow)
      setExpanded((v) => ({ ...v, [selectedRow.context]: true }));
  }, [selectedRow?.slot]);
  const families = useMemo(
    () => Array.from(new Set(project?.rows.map((r) => r.family))).sort(),
    [project],
  );
  const groups = useMemo(
    () => Array.from(new Set(project?.rows.map((r) => r.context))).sort(),
    [project],
  );
  const traits = useMemo(
    () =>
      Array.from(
        new Set(project?.rows.flatMap((row) => row.traits ?? [])),
      ).sort(),
    [project],
  );
  const categories = useMemo(
    () => Array.from(new Set(project?.rows.map((r) => r.category))).sort(),
    [project],
  );
  const hasFilters = Object.values(filters).some(Boolean);
  const hasReviewableMatches =
    hasFilters && filtered.some((row) => row.state !== "missing");
  const filterCount = Object.entries(filters).filter(
    ([key, value]) => key !== "search" && key !== "state" && value,
  ).length;
  const availableFilters = useMemo(() => {
    const rows = project?.rows ?? [];
    const values = (
      key: keyof typeof emptyFilters,
      field: (row: Row) => string[],
    ) => {
      const counts = new Map<string, number>();
      for (const row of filterRows(
        rows,
        { ...filters, [key]: "" },
        requiredSlots,
      ))
        for (const value of field(row))
          counts.set(value, (counts.get(value) ?? 0) + 1);
      return counts;
    };
    return {
      family: values("family", (row) => [row.family]),
      state: values("state", (row) =>
        requiredSlots.has(row.slot) ? [row.state, "required"] : [row.state],
      ),
      group: values("group", (row) => [row.context]),
      category: values("category", (row) => [row.category]),
      delivery: values("delivery", (row) => [row.delivery]),
      acting: values("acting", (row) => [row.acting || "unspecified"]),
      trait: values("trait", (row) => row.traits ?? []),
    };
  }, [project, filters, requiredSlots]);
  function stop() {
    setPlayerEpoch((v) => v + 1);
  }
  async function choose(row: Row) {
    if (busy) return;
    if (
      dirty &&
      !(await confirm("Your text, audio settings have not been saved."))
    )
      return;
    stop();
    setSelected(row.slot);
    setText(row.text);
    const groupIndex = grouped.findIndex(
      (group) => group.context === row.context,
    );
    if (groupIndex >= 0) setPage(Math.floor(groupIndex / PAGE));

    setAudioDirty(false);
    setEditReset((v) => v + 1);
  }
  async function load(prefer?: string) {
    setAudioDirty(false);
    setEditReset((v) => v + 1);
    const p = await request<Project>("/project");
    setRevision(p.revision);
    setProject(p);
    if (p.schemaError)
      toastManager.add({
        title: "Project schema needs updating",
        description: p.schemaError,
        type: "error",
      });
    setProjects((items) =>
      items.map((item) =>
        item.key === p.projectKey ? { ...item, name: p.name } : item,
      ),
    );
    const row =
      p.rows.find((r) => r.slot === (prefer || selected)) || p.rows[0];
    if (row) {
      setSelected(row.slot);
      setText(row.text);
    } else {
      setSelected("");
      setText("");
    }
    setMetadata({
      name: p.name,
      author: p.author,
      steamProfile: p.steamProfile || "",
      description: p.description,
      packVersion: p.packVersion,
    });
    setMetadataDirty(false);
    return p;
  }
  async function work(task: () => Promise<void>, loadingMessage = "") {
    if (busy) return;
    setBusy(true);
    if (loadingMessage) setProjectLoading(loadingMessage);
    setError("");
    try {
      await task();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      toastManager.add({
        title: "Could not complete action",
        description: e instanceof Error ? e.message : String(e),
        type: "error",
        actionProps:
          e instanceof RequestError && e.status === 409
            ? {
                children: "Reload saved project",
                onClick: async () => {
                  if (
                    await confirm(
                      "Reload the saved project and discard your unsaved edits?",
                    )
                  ) {
                    await work(async () => {
                      stop();
                      await load();
                    });
                  }
                },
              }
            : undefined,
      });
    } finally {
      setBusy(false);
      setOperation("");
      if (loadingMessage) setProjectLoading("");
    }
  }
  useEffect(() => {
    void work(async () => {
      const [, s] = await Promise.all([load(), request<Schema>("/schema")]);
      setSchema(s);
      setProjects(await request("/projects"));
      setMessage("Ready. Recordings stay on this computer.");
      if (new URLSearchParams(location.search).get("new") === "1") {
        setModal("create");
        history.replaceState(null, "", location.pathname);
      }
    }, "Opening project…");
  }, []);
  useEffect(() => {
    const prevent = (e: BeforeUnloadEvent) => {
      if (dirty || metadataDirty || busy) {
        e.preventDefault();
      }
    };
    window.addEventListener("beforeunload", prevent);
    return () => window.removeEventListener("beforeunload", prevent);
  }, [dirty, metadataDirty, busy]);
  useEffect(() => {
    listRef.current
      ?.querySelector("[data-slot=scroll-area-viewport]")
      ?.scrollTo?.(0, 0);
  }, [currentPage, filters]);
  async function changeFilters(next: typeof filters, preferredSlot?: string) {
    if (busy) return;
    if (
      dirty &&
      !(await confirm("Your text or audio settings have not been saved."))
    )
      return;
    const matches = filterRows(project?.rows || [], next, requiredSlots);
    setFilters(next);
    const row =
      matches.find((r) => r.slot === (preferredSlot ?? selected)) || matches[0];
    const groupIndex =
      preferredSlot && row
        ? groupRows(matches).findIndex((group) => group.context === row.context)
        : 0;
    setPage(Math.max(0, Math.floor(groupIndex / PAGE)));
    stop();
    setSelected(row?.slot || "");
    setText(row?.text || "");

    setAudioDirty(false);
    setEditReset((v) => v + 1);
    return true;
  }
  useEffect(() => {
    if (dirty || filtered.some((r) => r.slot === selected)) return;
    const row = filtered[0];
    setSelected(row?.slot || "");
    setText(row?.text || "");
  }, [filtered, selected, dirty]);
  function updateFilter(key: keyof typeof filters, value: string) {
    void changeFilters({
      ...filters,
      [key]: value,
      ...(key === "family" || key === "trait" ? { group: "" } : {}),
    });
  }
  async function save(state: Exclude<State, "missing">, next = false) {
    if (!selectedRow) return;
    await work(async () => {
      await action("/save", {
        slot: selectedRow.slot,
        text,
        direction: selectedRow.direction,
        state,
      });
      const index = navigationRows.findIndex(
        (r) => r.slot === selectedRow.slot,
      );
      const nextSlot =
        next && index >= 0 ? navigationRows[index + 1]?.slot : undefined;
      stop();
      await load(nextSlot || selectedRow.slot);
      if (nextSlot) {
        const gi = grouped.findIndex((g) =>
          g.variations.some((r) => r.slot === nextSlot),
        );
        setPage(Math.max(0, Math.floor(gi / PAGE)));
      }
      setMessage(
        next ? "Approved. Next recording selected." : "Changes saved.",
      );
    });
  }
  async function reviewFiltered(state: "approved" | "redo") {
    if (busy || dirty || !hasReviewableMatches) return;
    const slots = filtered
      .filter((r) => r.state !== "missing" && r.state !== state)
      .map((r) => r.slot);
    if (!slots.length) return;
    const verb = state === "approved" ? "Approve" : "Mark for retake";
    if (
      !(await confirm(
        state === "approved"
          ? "Approve " +
              slots.length +
              " matching recordings across all pages? Only continue if you have listened to them. Missing recordings are excluded."
          : "Mark " +
              slots.length +
              " matching recordings across all pages for a retake? Audio files will be kept.",
        verb + " " + slots.length + " recordings?",
        verb,
      ))
    )
      return;
    await perform("/review", { slots, state });
  }
  async function importFiles(files: ArrayLike<File> | null, batch = false) {
    if (!files?.length || !project || (!batch && !selectedRow)) return;
    if (
      dirty &&
      !(await confirm(
        "Importing will discard unsaved text and audio settings.",
      ))
    )
      return;
    const snapshot = project;
    let imported = false;
    await work(async () => {
      stop();
      const selectedFiles: { row: Row; file: File }[] = [];
      let skipped = 0;
      const used = new Set<string>();
      for (const file of Array.from(files)) {
        const stem = file.name.replace(/\.[^.]+$/, "");
        const row = batch
          ? snapshot.rows.find(
              (r) => r.slot === stem || snapshot.voice + "_" + r.slot === stem,
            )
          : selectedRow;
        if (!row || (batch && !["missing", "redo"].includes(row.state))) {
          skipped++;
          continue;
        }
        if (used.has(row.slot))
          throw new Error(
            "More than one file matches " +
              row.slot +
              ". Rename duplicates before importing.",
          );
        const maxBytes = snapshot.limits?.audioBytes ?? 16 * 1024 * 1024;
        if (file.size > maxBytes)
          throw new Error(
            file.name +
              " exceeds the " +
              maxBytes / (1024 * 1024) +
              " MiB limit.",
          );
        used.add(row.slot);
        selectedFiles.push({ row, file });
      }
      let count = 0;
      try {
        for (const { row, file } of selectedFiles) {
          setMessage(
            `Importing ${count + 1} / ${selectedFiles.length}: ${file.name}`,
          );
          await request("/import", file, { "X-Slot": row.slot });
          count++;
        }
      } catch (e) {
        await load();
        setMessage(
          `${count} imported before the batch stopped. Existing imports are kept.`,
        );
        throw e;
      }
      await load(selectedRow?.slot);
      imported = count > 0;
      setMessage(
        `${count} imported${skipped ? `, ${skipped} skipped (unmatched or already recorded)` : ""}. Listen before approving.`,
      );
    });
    return imported;
  }

  async function switchProject(key: string): Promise<boolean> {
    if (busy) return false;
    if (key === project?.projectKey) return true;
    if (dirty && !(await confirm("Discard unsaved text and audio settings?")))
      return false;
    let succeeded = false;
    await work(async () => {
      stop();
      await action("/open", { key });
      await load();
      setFilters(emptyFilters);
      setPage(0);
      setReport(null);
      succeeded = true;
    }, "Opening project…");
    return succeeded;
  }
  const [packFolder, setPackFolder] = useState("");

  async function choosePackFolder() {
    await work(async () => {
      const result = await action("/browse-pack-folders", { native: true });
      if (result.unavailable) {
        throw new Error("Windows folder picker unavailable. Enter the local folder path.");
      }
      if (typeof result.selected === "string") setPackFolder(result.selected);
    });
  }

  async function openVoicePack(folder: string) {
    await work(async () => {
      const result = await action("/open-pack", { folder });
      if (!result.opened) return;
      stop();
      await load();
      setProjects(await request("/projects"));
      setFilters(emptyFilters);
      setPage(0);
      setModal(null);
    }, "Opening voice pack…");
  }

  async function closeModal() {
    if (busy) return;
    if (metadataDirty && !(await confirm("Discard unsaved project details?")))
      return;
    setMetadataDirty(false);
    setModal(null);
  }
  async function openModal(which: "project" | "prepare" | "import" | "create" | "open-pack") {
    if (busy) return;
    if (
      dirty &&
      !(await confirm("Your text, audio settings have not been saved."))
    )
      return;
    if (selectedRow) {
      setText(selectedRow.text);
    }
    if (project)
      setMetadata({
        name: project.name,
        author: project.author,
        steamProfile: project.steamProfile || "",
        description: project.description,
        packVersion: project.packVersion,
      });
    setAudioDirty(false);
    setEditReset((v) => v + 1);
    setModal(which);
    setReport(null);
    setMetadataDirty(false);
    if (which === "project")
      void work(async () => {
        setProjects(await request("/projects"));
      });
  }
  async function perform(path: string, data: unknown = {}) {
    await work(async () => {
      setOperation(path);
      stop();
      const result = await action(path, data);
      setReport(result);
      toastManager.add({
        title: path === "/measure" ? "Audio check complete" : "Saved",
        description:
          typeof result.message === "string"
            ? result.message
            : "Results are available in Build voice pack.",
        type: "success",
      });
      await load();
      setMessage(
        typeof result.message === "string"
          ? result.message
          : "Done. See the results below.",
      );
    });
  }
  async function fetchRecordingList() {
    try {
      return await request<{
        projectKey: string;
        voice: string;
        recordings: unknown[];
      }>("/recording-list");
    } catch (error) {
      if (!(error instanceof RequestError) || error.status !== 404) throw error;
      const latest = await request<Project>(
        "/project",
        undefined,
        {},
        true,
        false,
      );
      if (latest.schemaError) throw new Error(latest.schemaError);
      return {
        projectKey: latest.projectKey,
        voice: latest.voice,
        language: latest.language,
        recordings: latest.rows.map(({ slot, text, state }) => ({
          slot,
          text,
          state,
          filename: slot + ".mp3",
        })),
      };
    }
  }
  async function exportList() {
    await work(async () => {
      const { projectKey, ...data } = await fetchRecordingList();
      if (projectKey !== project?.projectKey)
        throw new Error(
          "The active project changed. Reopen it before downloading its slots.",
        );
      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = (project?.voice || "voice") + "-recording-list.json";
      document.body.append(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setMessage("Recording list exported.");
      toastManager.add({ title: "Slot list downloaded", type: "success" });
    });
  }
  const position = navigationRows.findIndex((r) => r.slot === selected);
  const complete =
    project &&
    !project.schemaError &&
    project.rows.length > 0 &&
    !project.trial &&
    (project.buildCoverage
      ? project.buildCoverage.missing.length === 0
      : project.coverage.approved === project.rows.length);
  const hasAudio = !!selectedRow && selectedRow.state !== "missing";
  const takeCommands = {
    approve: { value: "Approve", key: "Ctrl+Enter", disabled: busy || audioDirty || !hasAudio, run: () => void save("approved") },
    import: { value: "Import audio", key: "Alt+I", disabled: busy || !selectedRow, run: () => importRef.current?.click() },
    record: { value: "Record audio", key: "Alt+R", disabled: busy || !selectedRow, run: () => { stop(); setModal("microphone"); } },
    listen: { value: "Needs listening", key: "Alt+L", disabled: busy || audioDirty || !hasAudio || selectedRow?.state === "pending", run: () => void save("pending") },
    retake: { value: "Needs a retake", key: "Alt+T", disabled: busy || audioDirty || !hasAudio, run: () => void save("redo") },
  };
  const commands = [
    {
      value: "Play or pause recording",
      key: "Space",
      disabled: busy || !selectedRow || selectedRow.state === "missing",
      run: () => playerControl.current?.toggle(),
    },
    {
      value: "Previous recording",
      key: "Alt+Left",
      disabled: busy || position <= 0,
      run: () => void choose(navigationRows[position - 1]),
    },
    {
      value: "Next recording",
      key: "Alt+Right",
      disabled: busy || position < 0 || position >= navigationRows.length - 1,
      run: () => void choose(navigationRows[position + 1]),
    },
    takeCommands.approve,
    {
      value: "Undo last bulk review",
      key: "Ctrl+Shift+Z",
      disabled: busy || dirty || !project?.canUndoReview,
      run: () => void perform("/undo-review"),
    },
    takeCommands.record,
    takeCommands.listen,
    takeCommands.retake,
    takeCommands.import,
    {
      value: "Build voice pack",
      key: "",
      disabled: busy,
      run: () => void openModal("prepare"),
    },
    {
      value: "Batch import",
      key: "",
      disabled: busy || !project,
      run: () => void openModal("import"),
    },
    {
      value: "Download recording list",
      key: "",
      disabled: busy || !project,
      run: () => void exportList(),
    },
    {
      value: "Check audio levels",
      key: "",
      disabled: busy || !project || project.coverage.missing === project.rows.length,
      run: () => void perform("/measure"),
    },
    {
      value: "Clear recording filters",
      key: "",
      disabled: busy || !Object.values(filters).some(Boolean),
      run: () => void changeFilters(emptyFilters),
    },
  ];
  useEffect(() => {
    const listener = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k" && !modal) {
        e.preventDefault();
        setCommandsOpen((v) => !v);
        return;
      }
      const el = e.target as HTMLElement;
      if (
        modal ||
        commandsOpen ||
        el.closest(
          "input,textarea,select,[contenteditable=true],[role=dialog],[role=alertdialog],[role=combobox]",
        )
      )
        return;
      const takeShortcut = e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey
        ? { KeyR: 5, KeyL: 6, KeyT: 7, KeyI: 8 }[e.code as "KeyR" | "KeyL" | "KeyT" | "KeyI"]
        : undefined;
      const match = takeShortcut ?? (
        e.altKey && e.key === "ArrowLeft"
          ? 1
          : e.altKey && e.key === "ArrowRight"
            ? 2
            : (e.ctrlKey || e.metaKey) && e.key === "Enter"
              ? 3
              : (e.ctrlKey || e.metaKey) &&
                  e.shiftKey &&
                  e.key.toLowerCase() === "z"
                ? 4
                : e.code === "Space" && el === document.body
                  ? 0
                  : -1);
      if (match >= 0 && !commands[match].disabled) {
        e.preventDefault();
        commands[match].run();
      }
    };
    window.addEventListener("keydown", listener);
    return () => window.removeEventListener("keydown", listener);
  });
  return (
    <ToastProvider>
      <LoadingDialog.Root open={!!projectLoading} onOpenChange={() => {}}>
        <LoadingDialog.Portal>
          <LoadingDialog.Popup className="fixed inset-0 z-[100] flex h-dvh w-screen flex-col items-center justify-center gap-3 bg-background px-6 text-center text-foreground outline-none" aria-busy="true">
            <LoaderCircle aria-hidden="true" className="size-8 animate-spin text-primary motion-reduce:animate-none" />
            <LoadingDialog.Title className="text-lg font-semibold">{projectLoading}</LoadingDialog.Title>
            <LoadingDialog.Description className="text-sm text-muted-foreground" role="status">
              Loading recordings and project details. Please wait.
            </LoadingDialog.Description>
          </LoadingDialog.Popup>
        </LoadingDialog.Portal>
      </LoadingDialog.Root>
      <TooltipProvider delay={250}>
        <div
          className="app-shell flex h-dvh flex-col overflow-hidden max-[600px]:h-auto max-[600px]:min-h-dvh max-[600px]:overflow-visible"
          aria-busy={busy}
        >
          <header className="app-header flex shrink-0 items-center justify-between gap-5 border-b px-6 py-2.5 max-[800px]:gap-3 max-[800px]:px-4 max-[800px]:py-3 max-[600px]:items-start">
            <div className="identity">
              <div className="border-r pr-3" aria-label="Conditional Speech Voices - Studio">
                <strong className="wordmark">
                  CONDITIONAL SPEECH{" "}
                  <span className="flex gap-1.5">
                    <span className="wordmark-title">VOICES</span>
                    <span className="font-thin text-secondary text-2xl self-center">
                      STUDIO
                    </span>
                  </span>
                </strong>
              </div>
              <ProjectPicker
                items={projects}
                current={project?.projectKey || "current"}
                language={project?.language || ""}
                languageFlags={project?.languageFlags ?? []}
                trial={!!project?.trial}
                disabled={busy || !project}
                onSelect={async (key) => {
                  await switchProject(key);
                }}
                onDelete={async ({ key, name }) => {
                  if (
                    !(await confirm(
                      `Permanently delete "${name}" and all its project files and recordings? This cannot be undone.`,
                      "Delete project?",
                      "Delete project",
                      true,
                    ))
                  )
                    return;
                  await work(async () => {
                    if (key === project?.projectKey) stop();
                    await action("/remove-project", { key });
                    await load();
                    setProjects(await request("/projects"));
                  });
                }}
                onDetails={async (key) => {
                  if (key === project?.projectKey) await openModal("project");
                  else if (await switchProject(key)) {
                    setMetadataDirty(false);
                    setModal("project");
                  }
                }}
                onOpen={() => {
                  setPackFolder("");
                  void openModal("open-pack");
                }}
                onCreate={() => void openModal("create")}
              />
            </div>
            <div className="flex flex-wrap justify-end gap-2">
              <Button
                variant="ghost"
                disabled={
                  busy ||
                  !project ||
                  project.coverage.missing === project.rows.length
                }
                onClick={() => void perform("/measure")}
              >
                {operation === "/measure" ? "Checking…" : "Check audio levels"}
              </Button>
              <Button
                disabled={busy || !project}
                onClick={() => openModal("prepare")}
              >
                Build voice pack
              </Button>
            </div>
          </header>
          {operation === "/measure" && (
            <div className="measurement-progress" role="status">
              <p>Checking audio levels…</p>
              <Progress value={null} aria-label="Checking audio levels" />
              <p className="help">
                Large packs can take several minutes. Keep Studio open.
              </p>
            </div>
          )}

          <main className="min-h-0 flex-1 grid grid-cols-[330px_minmax(0,1fr)] max-[800px]:grid-cols-[280px_minmax(0,1fr)] max-[600px]:flex max-[600px]:flex-col">
            <aside
              className="flex min-h-0 flex-col border-r bg-card max-[600px]:shrink-0 max-[600px]:border-r-0 max-[600px]:border-b"
              aria-label="Recording library"
            >
              <div className="border-b px-3.5 pt-3.75 pb-2.5 max-[600px]:px-3 max-[600px]:pt-2.5 max-[600px]:pb-2">
                <div className="mb-3 flex items-center justify-between">
                  <strong className="text-[15px]">Recordings</strong>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8! min-h-8!"
                    disabled={busy}
                    onClick={() => void openModal("import")}
                  >
                    <Upload />
                    Batch import
                  </Button>
                </div>
                <div className="search-box">
                  <Search size={15} />
                  <Input
                    aria-label="Find a recording"
                    placeholder="Find a recording…"
                    value={filters.search}
                    onChange={(e) => updateFilter("search", e.target.value)}
                  />
                </div>
                <Collapsible>
                  <div className="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
                    <Choice
                      name="Recording status"
                      triggerClassName="text-[11px]"
                      value={filters.state}
                      onChange={(v) => updateFilter("state", v)}
                      items={[
                        { value: "", label: "All statuses" },
                        ...Object.entries(stateNames).map(([value, name]) => ({
                          value,
                          label: `${name} (${availableFilters.state.get(value) ?? 0})`,
                          disabled: !availableFilters.state.has(value),
                        })),
                        ...(project?.buildCoverage?.missingSlots &&
                        !project.trial
                          ? [
                              {
                                value: "required",
                                label: `Required gaps (${availableFilters.state.get("required") ?? 0})`,
                                disabled:
                                  !availableFilters.state.has("required"),
                              },
                            ]
                          : []),
                      ]}
                    />
                    <CollapsibleTrigger
                      aria-label={filterCount ? "Filters, active" : "Filters"}
                      title="More filters"
                      render={
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8! min-h-8! w-8 gap-px p-0 text-[11px] [&_svg]:w-3.25!"
                        />
                      }
                    >
                      <ListFilter aria-hidden="true" />
                      {filterCount > 0 && (
                        <span
                          aria-hidden="true"
                          className="pointer-events-none absolute right-0 top-0 size-2 rounded-full bg-primary"
                        >
                          <span className="absolute inset-0 rounded-full bg-primary/70 motion-safe:animate-ping" />
                        </span>
                      )}
                    </CollapsibleTrigger>
                  </div>
                  <CollapsiblePanel>
                    <div className="grid grid-cols-2 gap-1.5 pt-2 max-[600px]:gap-1.25 **:data-[slot=select-trigger]:min-w-0 **:data-[slot=select-trigger]:text-[11px]">
                      <Choice
                        name="Category"
                        value={filters.family}
                        onChange={(v) => updateFilter("family", v)}
                        items={[
                          { value: "", label: "All categories" },
                          ...families.map((f) => ({
                            value: f,
                            label: `${label(f)} (${availableFilters.family.get(f) ?? 0})`,
                            disabled: !availableFilters.family.has(f),
                          })),
                        ]}
                      />
                      <Choice
                        name="Situation"
                        value={filters.group}
                        onChange={(v) => updateFilter("group", v)}
                        items={[
                          { value: "", label: "All situations" },
                          ...groups.map((g) => ({
                            value: g,
                            label: `${label(g)} (${availableFilters.group.get(g) ?? 0})`,
                            disabled: !availableFilters.group.has(g),
                          })),
                        ]}
                      />
                      <Choice
                        name="Recording type"
                        value={filters.category}
                        onChange={(v) => updateFilter("category", v)}
                        items={[
                          { value: "", label: "All recording types" },
                          ...categories.map((c) => ({
                            value: c,
                            label: `${c} (${availableFilters.category.get(c) ?? 0})`,
                            disabled: !availableFilters.category.has(c),
                          })),
                        ]}
                      />
                      <Choice
                        name="Delivery filter"
                        value={filters.delivery}
                        onChange={(v) => updateFilter("delivery", v)}
                        items={[
                          { value: "", label: "All deliveries" },
                          ...Array.from(
                            new Set(project?.rows.map((row) => row.delivery)),
                          )
                            .sort()
                            .map((delivery) => ({
                              value: delivery,
                              label: `${label(delivery)} (${availableFilters.delivery.get(delivery) ?? 0})`,
                              disabled:
                                !availableFilters.delivery.has(delivery),
                            })),
                        ]}
                      />
                      <Choice
                        name="Filter acting"
                        value={filters.acting}
                        onChange={(v) => updateFilter("acting", v)}
                        items={[
                          { value: "", label: "All acting" },
                          ...Array.from(
                            new Set(
                              project?.rows.map(
                                (r) => r.acting || "unspecified",
                              ),
                            ),
                          )
                            .sort()
                            .map((value) => ({
                              value,
                              label: `${value === "unspecified" ? "Not specified" : label(value)} (${availableFilters.acting.get(value) ?? 0})`,
                              disabled: !availableFilters.acting.has(value),
                            })),
                        ]}
                      />
                      {traits.length > 0 && (
                        <Choice
                          name="Trait"
                          value={filters.trait}
                          onChange={(value) => updateFilter("trait", value)}
                          items={[
                            { value: "", label: "All traits" },
                            ...traits.map((trait) => ({
                              value: trait,
                              label: `${trait} (${availableFilters.trait.get(trait) ?? 0})`,
                              disabled: !availableFilters.trait.has(trait),
                            })),
                          ]}
                        />
                      )}
                    </div>
                  </CollapsiblePanel>
                </Collapsible>
                <div className="library-count">
                  {Object.values(filters).some(Boolean) && (
                    <Button
                      size="xs"
                      variant="ghost"
                      className="h-8! min-h-8! w-full justify-center"
                      onClick={() => void changeFilters(emptyFilters)}
                    >
                      Clear filters
                    </Button>
                  )}
                </div>
              </div>
              {(hasReviewableMatches || project?.canUndoReview) && (
                <div
                  className="bulk-review"
                  aria-label="Review filtered recordings"
                >
                  {hasReviewableMatches && (
                    <>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={
                          busy ||
                          dirty ||
                          !filtered.some(
                            (r) =>
                              r.state !== "missing" && r.state !== "approved",
                          )
                        }
                        onClick={() => void reviewFiltered("approved")}
                      >
                        Approve filtered
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={
                          busy ||
                          dirty ||
                          !filtered.some(
                            (r) => r.state !== "missing" && r.state !== "redo",
                          )
                        }
                        onClick={() => void reviewFiltered("redo")}
                      >
                        Retake filtered
                      </Button>
                    </>
                  )}
                  {project?.canUndoReview && (
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={busy || dirty}
                      data-bulk-undo
                      onClick={() => void perform("/undo-review")}
                    >
                      Undo
                    </Button>
                  )}
                </div>
              )}
              <ScrollArea
                className="h-0 flex-1 overflow-hidden max-[600px]:h-47.5 max-[600px]:min-h-47.5 max-[600px]:flex-none"
                ref={listRef}
                key={currentPage}
              >
                {visible.map((g) => (
                  <Collapsible
                    key={g.context}
                    className="situation-group"
                    open={!!expanded[g.context]}
                    onOpenChange={(v) =>
                      setExpanded((old) => ({ ...old, [g.context]: v }))
                    }
                  >
                    <div className="situation-row">
                      <CollapsibleTrigger
                        render={
                          <Button
                            variant="ghost"
                            className={
                              "recording-row " +
                              (g.context === selectedRow?.context
                                ? "selected "
                                : "") +
                              (["missing", "redo", "pending", "approved"].find(
                                (state) =>
                                  g.variations.some((r) => r.state === state),
                              ) || "pending")
                            }
                            disabled={busy}
                          />
                        }
                      >
                        <span className="row-text">{label(g.context)}</span>
                        <Badge variant="outline" title="Approved / total">
                          {
                            g.variations.filter((r) => r.state === "approved")
                              .length
                          }
                          /{g.variations.length}
                        </Badge>
                        <ChevronUp className="group-chevron" />
                      </CollapsibleTrigger>
                    </div>
                    <CollapsiblePanel>
                      <div className="variation-list">
                        {g.variations.map((r) => (
                          <Button
                            key={r.slot}
                            variant="ghost"
                            className={
                              "variation-row" +
                              (selected === r.slot ? " selected" : "")
                            }
                            aria-current={
                              selected === r.slot ? "true" : undefined
                            }
                            disabled={busy}
                            onClick={() => void choose(r)}
                          >
                            <span>
                              {r.text || r.reference || r.slot}
                              <small>
                                {r.slot} / {label(r.delivery)}
                              </small>
                            </span>
                            <span
                              aria-label={stateNames[r.state]}
                              className={"state-dot " + r.state}
                            />
                          </Button>
                        ))}
                      </div>
                    </CollapsiblePanel>
                  </Collapsible>
                ))}
                {!visible.length && (
                  <p className="p-4 text-xs text-muted-foreground">
                    {project
                      ? "No recordings match these filters."
                      : "Loading recordings…"}
                  </p>
                )}
              </ScrollArea>
              <div className="flex items-center justify-between border-t px-3 py-0.5 text-[11px] tabular-nums text-muted-foreground">
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label="Previous page"
                  disabled={currentPage === 0 || busy}
                  onClick={() => setPage(currentPage - 1)}
                >
                  <ChevronLeft />
                </Button>
                <span>
                  {grouped.length ? currentPage * PAGE + 1 : 0}–
                  {Math.min((currentPage + 1) * PAGE, grouped.length)} of{" "}
                  {grouped.length} situations
                </span>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label="Next page"
                  disabled={currentPage >= pageCount - 1 || busy}
                  onClick={() => setPage(currentPage + 1)}
                >
                  <ChevronRight />
                </Button>
              </div>
            </aside>
            <section
              className="recording-detail"
              aria-label="Selected recording"
            >
              {selectedRow ? (
                <>
                  <div className="mb-6.5 border-b pb-5.5 max-[800px]:mb-5">
                    <div className="metadata-grid">
                      <div>
                        <span className="field-caption">Category</span>
                        <span>{label(selectedRow.family)}</span>
                      </div>
                      <div>
                        <span className="field-caption">Situation</span>
                        <span>{label(selectedRow.context)}</span>
                      </div>
                      <div>
                        <span className="field-caption">Status</span>
                        <Badge
                          variant="outline"
                          className={"review-status " + selectedRow.state}
                        >
                          {stateNames[selectedRow.state]}
                        </Badge>
                      </div>
                      <div>
                        <span className="field-caption">Recording type</span>
                        <span>{selectedRow.category}</span>
                      </div>
                    </div>
                    <div
                      className={
                        actingOptions.length > 0
                          ? "variation-field"
                          : "variation-field without-acting"
                      }
                    >
                      <Label>Delivery</Label>
                      <Choice
                        name="Delivery"
                        value={selectedRow.delivery}
                        disabled={busy}
                        items={deliveries.map((d) => ({
                          value: d,
                          label: label(d),
                        }))}
                        onChange={(d) => {
                          const same = situationRows.find(
                            (r) =>
                              r.delivery === d && r.text === selectedRow.text,
                          );
                          const row =
                            same || situationRows.find((r) => r.delivery === d);
                          if (row) void choose(row);
                        }}
                      />
                      {actingOptions.length > 0 && (
                        <>
                          <Label>Acting</Label>
                          <Choice
                            name="Acting"
                            value={selectedRow.acting || "unspecified"}
                            disabled={busy || actingOptions.length < 2}
                            items={actingOptions.map((value) => ({
                              value,
                              label:
                                value === "unspecified"
                                  ? "Not specified"
                                  : label(value),
                            }))}
                            onChange={(value) => {
                              const row = situationRows.find(
                                (r) =>
                                  r.delivery === selectedRow.delivery &&
                                  (r.acting || "unspecified") === value,
                              );
                              if (row) void choose(row);
                            }}
                          />
                        </>
                      )}
                      <Label>Variation</Label>
                      <Choice
                        name="Variation"
                        value={selectedRow.slot}
                        disabled={busy}
                        onChange={(v) => {
                          const r = variations.find((r) => r.slot === v);
                          if (r) void choose(r);
                        }}
                        items={variations.map((r, i) => ({
                          value: r.slot,
                          label: `${i + 1}. ${r.slot}${r.optional ? " (optional)" : ""}`,
                        }))}
                      />
                    </div>

                  </div>
                  <div className="caption-editor">
                    <Textarea
                      unstyled
                      aria-label="Spoken text / caption"
                      dir="auto"
                      className="caption-title"
                      value={text}
                      maxLength={project?.limits?.caption || 240}
                      onChange={(e) => setText(e.target.value)}
                      disabled={busy}
                    />
                    {textDirty && (
                      <Button
                        variant="outline"
                        disabled={busy || audioDirty}
                        onClick={() => void save("pending")}
                      >
                        Save text
                      </Button>
                    )}
                  </div>
                  {filters.state === "required" && (
                    <div
                      className="mb-3 flex flex-wrap items-center gap-2 text-xs"
                      aria-label="Required groups for this take"
                    >
                      <span className="text-muted-foreground">
                        Approving this take covers
                      </span>
                      {Array.from(
                        new Set(
                          (missingBySlot.get(selectedRow.slot) ?? []).map(
                            coverageLabel,
                          ),
                        ),
                      ).map((group) => (
                        <Badge key={group} variant="outline">
                          {group}
                        </Badge>
                      ))}
                    </div>
                  )}
                  <section
                    className="recording-guidance"
                    aria-label="Recording guidance"
                  >
                    <span className="field-caption">Recording guidance</span>
                    <p>
                      {selectedRow.guidance ||
                        selectedRow.direction ||
                        "Use a natural, conversational delivery. Keep the meaning of this line."}
                    </p>
                  </section>
                  <div className="recording-player-card">
                    <AudioPlayer
                      key={selectedRow.slot + project?.revision + playerEpoch}
                      navigation={
                        <>
                          <div className="detail-navigation">
                            <Button
                              size="icon"
                              variant="ghost"
                              aria-label="Previous recording"
                              disabled={position <= 0 || busy}
                              onClick={() =>
                                choose(navigationRows[position - 1])
                              }
                            >
                              <ChevronLeft />
                            </Button>
                            <Button
                              size="icon"
                              variant="ghost"
                              aria-label="Next recording"
                              disabled={
                                position < 0 ||
                                position >= navigationRows.length - 1 ||
                                busy
                              }
                              onClick={() =>
                                choose(navigationRows[position + 1])
                              }
                            >
                              <ChevronRight />
                            </Button>
                          </div>
                        </>
                      }
                      controlRef={playerControl}
                      slot={selectedRow.slot}
                      missing={selectedRow.state === "missing"}
                      disabled={busy}
                      onError={(description) =>
                        toastManager.add({
                          title: "Playback failed",
                          description,
                          type: "error",
                        })
                      }
                    />
                    {selectedRow.state !== "missing" && (
                      <AudioEdit
                        key={selectedRow.slot}
                        reset={editReset}
                        row={selectedRow}
                        busy={busy}
                        onDirty={setAudioDirty}
                        onSave={async (
                          gainDb,
                          semitones,
                          restore,
                          speed,
                          trimStart,
                          trimEnd,
                        ) => {
                          if (
                            textDirty &&
                            !(await confirm(
                              "Applying audio settings will discard unsaved text.",
                            ))
                          )
                            return;
                          await perform("/process", {
                            slot: selectedRow.slot,
                            gainDb,
                            semitones,
                            speed,
                            trimStart,
                            trimEnd,
                            restore,
                          });
                        }}
                      />
                    )}
                  </div>
                  <div
                    className="mt-4 grid grid-cols-2 gap-2 max-[480px]:grid-cols-1"
                    aria-label="Add a take"
                  >
                    <ActionTip text={takeCommands.import.key}>
                      <Button size="lg" variant="outline" disabled={takeCommands.import.disabled} onClick={takeCommands.import.run} aria-keyshortcuts="Alt+I">
                        <Upload /> Import audio
                      </Button>
                    </ActionTip>
                    <ActionTip text={takeCommands.record.key}>
                      <Button size="lg" variant="outline" disabled={takeCommands.record.disabled} onClick={takeCommands.record.run} aria-keyshortcuts="Alt+R">
                        <Mic /> Record audio
                      </Button>
                    </ActionTip>
                  </div>
                  <div className="review-actions" aria-label="Review this take">
                    <ActionTip text={takeCommands.listen.key}>
                      <Button size="lg" variant="outline" disabled={takeCommands.listen.disabled} onClick={takeCommands.listen.run} aria-keyshortcuts="Alt+L">
                        Needs listening
                      </Button>
                    </ActionTip>
                    <ActionTip text={`${takeCommands.retake.key} · Mark this take for replacement. The current file stays until you import a new one.`}>
                      <Button size="lg" variant="outline" disabled={takeCommands.retake.disabled} onClick={takeCommands.retake.run} aria-keyshortcuts="Alt+T">
                        Needs a retake
                      </Button>
                    </ActionTip>
                    <ActionTip text={takeCommands.approve.key}>
                      <Button size="lg" disabled={takeCommands.approve.disabled} onClick={takeCommands.approve.run} aria-keyshortcuts="Control+Enter Meta+Enter">
                        <Check /> Approve
                      </Button>
                    </ActionTip>
                    <input
                      ref={importRef}
                      hidden
                      type="file"
                      accept={audioFileTypes}
                      onChange={(e) => {
                        void importFiles(e.target.files);
                        e.target.value = "";
                      }}
                    />
                  </div>
                </>
              ) : (
                <div className="flex flex-col items-center gap-4 pt-[15vh] text-muted-foreground">
                  <Headphones />
                  <p>
                    {error
                      ? "Project could not be opened."
                      : "Choose a recording to listen and review."}
                  </p>
                </div>
              )}
            </section>
          </main>
          <footer className="app-footer">
            <div className="flex flex-wrap justify-self-start [&_a[data-slot=button]]:text-[11px]!">
              <Button
                variant="link"
                size="sm"
                render={
                  <a
                    href="https://github.com/ravenwits/conditional-speech-voices-core"
                    target="_blank"
                    rel="noreferrer"
                  />
                }
              >
                <Github size={14} /> GitHub
              </Button>
              <Button
                variant="link"
                size="sm"
                render={
                  <a
                    href="https://steamcommunity.com/sharedfiles/filedetails/?id=3834426673"
                    target="_blank"
                    rel="noreferrer"
                  />
                }
              >
                <svg
                  aria-hidden="true"
                  viewBox="0 0 24 24"
                  width="16"
                  height="16"
                  fill="currentColor"
                >
                  <path d="M12 0a12 12 0 0 0-12 11.1l6.45 2.67a3.38 3.38 0 0 1 1.89-.58l2.87-4.16v-.06a4.53 4.53 0 1 1 4.53 4.53h-.11l-4.11 2.94a3.4 3.4 0 0 1-6.71.78L.16 15.3A12 12 0 1 0 12 0zm-5.12 18.3 1.48.61a2.55 2.55 0 1 0 1.97-4.7l-1.53-.63a2.7 2.7 0 1 1-1.92 4.72zm8.86-6.3a3.03 3.03 0 1 1 0-6.06 3.03 3.03 0 0 1 0 6.06zm0-.75a2.28 2.28 0 1 0 0-4.56 2.28 2.28 0 0 0 0 4.56z" />
                </svg>
                Workshop
              </Button>
              <Button
                variant="link"
                size="sm"
                render={
                  <a
                    href="https://github.com/ravenwits/conditional-speech-voices-core/blob/main/Contents/mods/ConditionalSpeechVoicesCore/authoring/README.md#command-line"
                    target="_blank"
                    rel="noreferrer"
                  />
                }
              >
                <Terminal size={14} /> CLI guide
              </Button>
            </div>
            <Button
              className="footer-commands"
              variant="ghost"
              size="sm"
              onClick={() => setCommandsOpen(true)}
              disabled={busy || !!modal}
            >
              Commands <kbd>Ctrl K</kbd>
            </Button>
            <span className="coverage">
              <span>
                {project?.coverage.approved || 0}/
                {project?.rows.length.toLocaleString() || 0} approved
              </span>
              <span>{project?.coverage.missing || 0} missing</span>
              <span>{project?.coverage.redo || 0} need a retake</span>
            </span>
            <span className="sr-only" role="status">
              {busy ? "Working. " : ""}
              {message}
            </span>
          </footer>
          <Modal
            open={modal === "microphone"}
            onClose={closeModal}
            title="Record a take"
            description={
              selectedRow
                ? `Record and preview a take for ${selectedRow.slot}.`
                : "Record and preview a take."
            }
          >
            {modal === "microphone" && selectedRow && (
              <MicrophoneTake
                key={`${project?.projectKey}:${selectedRow.slot}`}
                seconds={project?.limits?.seconds ?? 20}
                busy={busy}
                apply={async (file) => {
                  if (await importFiles([file])) {
                    setModal(null);
                    return true;
                  }
                  return false;
                }}
              />
            )}
          </Modal>
          <Modal
            open={modal === "prepare"}
            onClose={closeModal}
            title="Build voice pack"
            panelClassName="pb-1"
            description="Check the recordings, then build a local Steam Workshop project."
            footer={
              <div className="flex w-full flex-wrap items-center justify-end gap-3">
                <Label className="rights-confirmation">
                  <Checkbox
                    checked={rightsConfirmed}
                    onCheckedChange={setRightsConfirmed}
                    disabled={busy}
                  />
                  <span>
                    I have the{" "}
                    <a
                      className="underline underline-offset-2"
                      href="https://github.com/ravenwits/conditional-speech-voices-core/blob/main/Contents/mods/ConditionalSpeechVoicesCore/authoring/CREATOR-RESPONSIBILITIES.md"
                      target="_blank"
                      rel="noreferrer"
                    >
                      rights
                    </a>{" "}
                    to distribute these recordings.
                  </span>
                </Label>
                <div className="flex flex-wrap justify-end gap-2">
                  <ActionTip text="Download all variations with their status and batch-import filename.">
                    <Button
                      variant="outline"
                      disabled={busy || !project}
                      onClick={() => void exportList()}
                    >
                      Recording list
                    </Button>
                  </ActionTip>
                  <Button
                    disabled={busy || !complete || !rightsConfirmed}
                    onClick={() =>
                      void perform("/package", { rightsConfirmed })
                    }
                  >
                    Build package
                  </Button>
                </div>
              </div>
            }
          >
            <div>
              <strong className="text-[22px] font-[550]">
                {(
                  project?.buildCoverage?.covered ??
                  project?.coverage.approved ??
                  0
                ).toLocaleString()}
                <span className="text-[13px] font-normal text-muted-foreground">
                  {" "}
                  /{" "}
                  {(
                    project?.buildCoverage?.required ??
                    project?.rows.length ??
                    0
                  ).toLocaleString()}{" "}
                  {project?.buildCoverage
                    ? "required recording groups ready"
                    : "approved"}
                </span>
              </strong>
              <Progress
                className="my-3"
                aria-label="Package coverage"
                max={
                  project?.buildCoverage?.required ?? project?.rows.length ?? 1
                }
                value={
                  project?.buildCoverage?.covered ??
                  project?.coverage.approved ??
                  0
                }
              />
              <p className="text-[11px] text-muted-foreground">
                Recording library:{" "}
                {(project?.rows.length ?? 0).toLocaleString()} slots ·{" "}
                {(project?.coverage.approved ?? 0).toLocaleString()} approved ·{" "}
                {(project?.coverage.pending ?? 0).toLocaleString()} need
                listening · {(project?.coverage.redo ?? 0).toLocaleString()}{" "}
                need a retake
              </p>
            </div>
            {modal === "prepare" &&
              !project?.trial &&
              !!project?.buildCoverage?.missing.length && (
                <section
                  aria-label="Required recording groups"
                  className="mt-4 space-y-2"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <strong className="text-destructive-foreground">
                      {project.buildCoverage.missing.length} required groups
                      missing
                    </strong>
                    {project.buildCoverage.missingSlots && (
                      <Button
                        variant="link"
                        size="sm"
                        className="text-[11px]!"
                        disabled={busy}
                        onClick={async () => {
                          if (
                            await changeFilters({
                              ...emptyFilters,
                              state: "required",
                            })
                          )
                            setModal(null);
                        }}
                      >
                        Review in library
                      </Button>
                    )}
                  </div>
                  <ScrollArea
                    className="h-auto bg-muted/72 p-1"
                    viewportClassName="max-h-32"
                    scrollbarGutter
                    overscrollContain
                  >
                    <ul className="text-[11px] text-muted-foreground">
                      {project.buildCoverage.missing.map((group) => {
                        const slot =
                          project.buildCoverage?.missingSlots?.[group]?.[0];
                        return (
                          <li key={group}>
                            {slot ? (
                              <button
                                type="button"
                                className="w-full rounded-sm px-1 py-0.5 text-left hover:bg-muted hover:text-foreground focus-visible:outline focus-visible:outline-ring"
                                disabled={busy}
                                onClick={async () => {
                                  if (
                                    await changeFilters(
                                      { ...emptyFilters, state: "required" },
                                      slot,
                                    )
                                  )
                                    setModal(null);
                                }}
                              >
                                {coverageLabel(group)}
                              </button>
                            ) : (
                              coverageLabel(group)
                            )}
                          </li>
                        );
                      })}
                    </ul>
                  </ScrollArea>
                </section>
              )}
            {modal === "prepare" && project && (
              <section aria-label="Workshop artwork" className="mt-4">
                <h3 className="mb-2 text-sm font-medium">Workshop artwork</h3>
                <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1.78fr)] gap-3">
                  {(["square", "wide"] as const).map((format) => (
                    <figure key={format} className="min-w-0">
                      <img
                        className={
                          format === "square"
                            ? "aspect-square w-full rounded-md bg-muted object-contain"
                            : "aspect-video w-full rounded-md bg-muted object-contain"
                        }
                        src={`/studio/cover/${format}/${encodeURIComponent(project.language)}`}
                        alt={
                          format === "square"
                            ? "Square Workshop cover"
                            : "Wide Workshop cover"
                        }
                      />
                      <figcaption className="mt-1 text-xs text-muted-foreground">
                        {format === "square"
                          ? "Workshop preview · 1:1"
                          : "Wide cover · 16:9"}
                      </figcaption>
                    </figure>
                  ))}
                </div>
              </section>
            )}
            {project?.trial && (
              <ActionTip text="Add current Core requirements while preserving your recordings and saving a backup.">
                <Button
                  variant="outline"
                  disabled={busy}
                  onClick={() => void perform("/update", { apply: true })}
                >
                  Expand to full pack
                </Button>
              </ActionTip>
            )}

            {report && (
              <div
                className="mb-3 flex items-center justify-between bg-muted p-3 text-xs"
                role="status"
              >
                {typeof report.message === "string"
                  ? report.message
                  : typeof report.output === "string"
                    ? `Built: ${report.output}`
                    : Array.isArray(report.added)
                      ? `${report.added.length} added, ${(report.removed as unknown[]).length} removed, ${(report.changed as unknown[]).length} changed.`
                      : "Check complete."}
                {Array.isArray(report.outliers) && (
                  <p>
                    {report.outliers.length} level outliers flagged for
                    listening.
                  </p>
                )}
                {typeof report.output === "string" && (
                  <section className="mt-6 [&_code]:wrap-anywhere">
                    <h2>Upload through Project Zomboid</h2>
                    <p>
                      Copy <code>{report.output}</code> into{" "}
                      <code>Zomboid/Workshop</code>. Select the project in the
                      game's Workshop menu and review its preview and visibility
                      before uploading.
                    </p>
                    <h2>Test locally</h2>
                    <ol className="list-decimal pl-5 [&_li]:my-2.5 [&_li]:leading-[1.6]">
                      <li>Close Project Zomboid.</li>
                      <li>
                        Copy the generated mod folder from{" "}
                        <code>{String(report.mod ?? "")}</code> into your{" "}
                        <code>Zomboid/mods</code> folder. Keep its 42 and common
                        folders together.
                      </li>
                      <li>
                        Enable Conditional Speech, Conditional Speech Voices
                        Core and your pack in the game or save's mod list.
                      </li>
                      <li>
                        Select this voice when creating a character. Test
                        speech, whispers, calls and pain before sharing.
                      </li>
                    </ol>
                  </section>
                )}
                <Fold title={<>Details</>}>
                  <pre>{JSON.stringify(report, null, 2)}</pre>
                </Fold>
              </div>
            )}
          </Modal>
          <Modal
            open={modal === "import"}
            onClose={closeModal}
            title="Batch import"
            description="Match audio files to slots by filename."
            footer={
              <div className="flex w-full flex-wrap justify-end gap-2">
                <Button
                  variant="outline"
                  disabled={busy || !project}
                  onClick={() => void exportList()}
                >
                  <Download /> Download slot names
                </Button>
                <Button
                  disabled={busy}
                  onClick={() => batchRef.current?.click()}
                >
                  <Upload /> Choose audio files
                </Button>
              </div>
            }
          >
            <div className="grid gap-3.5">
              <div className="grid gap-2 rounded-[10px] border bg-muted px-3.5 py-3 [&_code]:wrap-anywhere">
                <span className="text-xs text-muted-foreground">
                  Filename examples
                </span>
                <div className="flex flex-wrap gap-2">
                  <code>Explore_1.wav</code>
                  <code>{project?.voice}_Explore_1.mp3</code>
                </div>
              </div>
              <p>
                Studio fills missing slots and replaces takes marked “Needs a
                retake”. Files without a matching slot are skipped.
              </p>
              <p className="help">
                Up to {project?.limits?.seconds ?? 20} seconds and{" "}
                {(project?.limits?.audioBytes ?? 16 * 1024 * 1024) /
                  (1024 * 1024)}{" "}
                MiB per file. Supports WAV, FLAC, MP3, Ogg, Opus, M4A, MP4, AAC
                and WebM.
              </p>
              <input
                hidden
                ref={batchRef}
                type="file"
                accept={audioFileTypes}
                multiple
                onChange={(e) => {
                  void importFiles(e.target.files, true);
                  e.target.value = "";
                }}
              />
            </div>
          </Modal>
          <Modal
            open={modal === "open-pack"}
            onClose={closeModal}
            title="Open project"
            description="Choose a local Conditional Speech Voices pack. An existing Studio project will open if it matches."
            footer={
              <div className="flex w-full flex-wrap justify-end gap-2">
                <Button variant="outline" disabled={busy} onClick={() => void choosePackFolder()}>
                  Browse folders
                </Button>
                <Button disabled={busy || !packFolder.trim()} onClick={() => void openVoicePack(packFolder.trim())}>
                  Open folder
                </Button>
              </div>
            }
          >
            <label className="grid gap-2">
              Local folder path
              <Input value={packFolder} onChange={(event) => setPackFolder(event.target.value)} />
            </label>
          </Modal>
          <Modal
            open={modal === "project"}
            onClose={closeModal}
            title="Project"
            description="Edit the voice pack details. Recording slots and game rules come from Core."
            footer={
              <>
                <Button variant="outline" disabled={busy} onClick={closeModal}>
                  Close
                </Button>
                <Button
                  disabled={
                    busy ||
                    !metadataDirty ||
                    !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(metadata.packVersion) ||
                    (!!metadata.steamProfile &&
                      !/^https:\/\/steamcommunity\.com\/(?:id\/[A-Za-z0-9_-]+|profiles\/[0-9]{17})\/?$/.test(
                        metadata.steamProfile,
                      ))
                  }
                  onClick={() =>
                    void work(async () => {
                      await action("/metadata", metadata);
                      await load();
                      setMessage("Project details saved.");
                    })
                  }
                >
                  Save details
                </Button>
              </>
            }
          >
            <div className="form-stack">
              {(
                [
                  "name",
                  "author",
                  "steamProfile",
                  "packVersion",
                  "description",
                ] as const
              ).map((key) => (
                <Label key={key}>
                  {
                    {
                      name: "Voice name",
                      author: "Author",
                      steamProfile: "Steam profile URL (optional)",
                      packVersion: "Pack version",
                      description: "Description",
                    }[key]
                  }
                  <Input
                    value={metadata[key]}
                    pattern={
                      key === "packVersion"
                        ? "[0-9]+\\.[0-9]+\\.[0-9]+"
                        : key === "steamProfile"
                          ? "https://steamcommunity\\.com/(id/[A-Za-z0-9_-]+|profiles/[0-9]{17})/?"
                          : undefined
                    }
                    disabled={busy}
                    onChange={(e) => {
                      setMetadata({
                        ...metadata,
                        [key]:
                          key === "packVersion"
                            ? e.target.value.replace(/[^0-9.]/g, "")
                            : e.target.value,
                      });
                      setMetadataDirty(true);
                    }}
                  />
                </Label>
              ))}
              <p className="help">
                {project?.voice} · {project?.language} ·{" "}
                {project?.trial ? "18-recording trial" : "Full pack"} · Core
                contract {schema?.contract}
              </p>
            </div>
          </Modal>
          <Modal
            open={modal === "create"}
            onClose={closeModal}
            title="Create a voice project"
            description="Use your own recordings. Every voice follows the same Core schema."
            footer={
              <>
                <Button variant="outline" onClick={closeModal} disabled={busy}>
                  Close
                </Button>
                <Button type="submit" form="create-voice" disabled={busy}>
                  Create project
                </Button>
              </>
            }
          >
            <Form
              id="create-voice"
              className="form-stack"
              onSubmit={async (e: FormEvent) => {
                e.preventDefault();
                if (
                  metadataDirty &&
                  !(await confirm("Discard unsaved project details?"))
                )
                  return;
                void work(async () => {
                  await action("/create", newProject);
                  await load();
                  setProjects(await request("/projects"));
                  setFilters(emptyFilters);
                  setPage(0);
                  setModal(null);
                  setMessage(
                    "New project created. Import your recordings to begin.",
                  );
                }, "Creating project…");
              }}
            >
              <Label>
                <span>
                  Voice ID{" "}
                  <Hint label="About voice IDs">
                    A unique lowercase identifier used by the game. Use letters,
                    numbers and underscores. Include your creator name to avoid
                    collisions with other packs.
                  </Hint>
                </span>
                <Input
                  required
                  pattern="[a-z][a-z0-9_]*"
                  maxLength={48}
                  placeholder="my_voice"
                  aria-label="Voice ID"
                  value={newProject.voice}
                  onChange={(e) =>
                    setNewProject({ ...newProject, voice: e.target.value })
                  }
                />
              </Label>
              <Label>
                In-game voice name
                <Input
                  required
                  maxLength={80}
                  value={newProject.name}
                  placeholder="Alex (English)"
                  onChange={(e) =>
                    setNewProject({ ...newProject, name: e.target.value })
                  }
                />
              </Label>
              <div className="grid grid-cols-2 gap-3">
                <Label>
                  Language
                  <SearchChoice
                    name="Language"
                    value={newProject.language}
                    items={languageOptions}
                    onChange={(language) =>
                      setNewProject({ ...newProject, language })
                    }
                  />
                </Label>
                <Label>
                  Character base
                  <Choice
                    name="Character base"
                    value={newProject.female ? "female" : "male"}
                    onChange={(v) =>
                      setNewProject({ ...newProject, female: v === "female" })
                    }
                    items={[
                      { value: "male", label: "Male" },
                      { value: "female", label: "Female" },
                    ]}
                  />
                </Label>
              </div>
              <Label>
                <span>
                  Scope{" "}
                  <Hint label="About recording scope">
                    The 18-recording sample covers normal speech, whispers,
                    calls, breathing, effort and pain. Expand it later without
                    losing recordings.
                  </Hint>
                </span>
                <Choice
                  name="Scope"
                  value={newProject.trial ? "trial" : "full"}
                  onChange={(v) =>
                    setNewProject({ ...newProject, trial: v === "trial" })
                  }
                  items={[
                    { value: "full", label: "Full pack" },
                    {
                      value: "trial",
                      label: "Listening sample (18 recordings)",
                    },
                  ]}
                />
              </Label>
            </Form>
          </Modal>
          {dialog}
        </div>
        <CommandDialog open={commandsOpen} onOpenChange={setCommandsOpen}>
          <CommandDialogPopup aria-label="Studio commands">
            <Command items={commands.filter((c) => !c.disabled)}>
              <CommandInput
                placeholder="Find a command…"
                aria-label="Find a command"
              />
              <CommandPanel>
                <CommandEmpty>No available commands.</CommandEmpty>
                <CommandList>
                  {(item: (typeof commands)[number]) => (
                    <CommandItem
                      key={item.value}
                      value={item}
                      onClick={() => {
                        setCommandsOpen(false);
                        item.run();
                      }}
                    >
                      {item.value}
                      <CommandShortcut>{item.key}</CommandShortcut>
                    </CommandItem>
                  )}
                </CommandList>
              </CommandPanel>
            </Command>
          </CommandDialogPopup>
        </CommandDialog>
      </TooltipProvider>
    </ToastProvider>
  );
}
