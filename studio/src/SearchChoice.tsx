import { useState } from "react";
import { ChevronDown, FolderOpen, Settings, Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Combobox,
  ComboboxTrigger,
  ComboboxInput,
  ComboboxPopup,
  ComboboxList,
  ComboboxItem,
  ComboboxRow,
  ComboboxEmpty,
} from "@/components/ui/combobox";

export function SearchChoice({
  name,
  value,
  items,
  onChange,
}: {
  name: string;
  value: string;
  items: { value: string; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <Combobox
      items={items}
      value={items.find((i) => i.value === value) || null}
      onValueChange={(i) => {
        if (i) onChange(i.value);
      }}
    >
      <ComboboxInput aria-label={name} placeholder="Search languages…" />
      <ComboboxPopup>
        <ComboboxEmpty>No language found.</ComboboxEmpty>
        <ComboboxList>
          {(i: { value: string; label: string }) => (
            <ComboboxItem key={i.value} value={i}>
              <span className="flex items-center gap-2"><img className="flex-none object-contain" src={`/studio/flag/${encodeURIComponent(i.value)}`} alt="" width={20} height={14} loading="lazy" />{i.label}</span>
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxPopup>
    </Combobox>
  );
}

export type ProjectChoice = { key: string; name: string };
export function ProjectPicker({
  items,
  current,
  language,
  languageFlags,
  trial,
  disabled,
  onSelect,
  onDetails,
  onDelete,
  onCreate,
  onOpen,
}: {
  items: ProjectChoice[];
  current: string;
  language: string;
  languageFlags: readonly string[];
  trial: boolean;
  disabled: boolean;
  onSelect: (key: string) => Promise<void>;
  onDetails: (key: string) => Promise<void>;
  onDelete: (item: ProjectChoice) => Promise<void>;
  onCreate: () => void;
  onOpen?: () => void;
}) {
  const [open, setOpen] = useState(false);
  const selected = items.find((i) => i.key === current);
  return (
    <Combobox
      items={items}
      value={selected || null}
      itemToStringLabel={(i) => i.name}
      open={open}
      onOpenChange={setOpen}
      disabled={disabled}
      onValueChange={(i) => {
        if (i) {
          setOpen(false);
          void onSelect(i.key);
        }
      }}
    >
      <ComboboxTrigger
        render={
          <Button
            variant="ghost"
            className="project-trigger"
            aria-label="Choose project"
          />
        }
      >
        {languageFlags.includes(language) && (
          <img className="size-4 shrink-0 object-contain" src={`/studio/flag/${encodeURIComponent(language)}`} alt="" />
        )}
        {selected?.name || "Opening project"}
        {trial && <span className="subtle">Trial</span>}
        <ChevronDown />
      </ComboboxTrigger>
      <ComboboxPopup className="project-popup">
        <ComboboxInput
          className="project-search rounded-b-none border-b-0"
          aria-label="Find a project"
          placeholder="Find a saved project…"
          showTrigger={false}
        />
        <ComboboxEmpty>No saved projects match your search.</ComboboxEmpty>
        <ComboboxList>
          {(i: ProjectChoice) => (
            <ComboboxRow key={i.key} className="project-option">
              <ComboboxItem value={i}>
                <span>{i.name}</span>
                {i.key === current && (
                  <span className="active-project">Current</span>
                )}
              </ComboboxItem>
              <Button
                size="icon"
                variant="ghost"
                aria-label={"Details for " + i.name}
                onClick={() => {
                  setOpen(false);
                  void onDetails(i.key);
                }}
              >
                <Settings />
              </Button>
              <Button
                size="icon"
                variant="ghost"
                disabled={i.key === "current" || i.key.startsWith("saved:")}
                title={i.key === "current" || i.key.startsWith("saved:") ? "Saved project is protected" : "Remove project"}
                aria-label={"Remove " + i.name}
                onClick={() => {
                  setOpen(false);
                  void onDelete(i);
                }}
              >
                <Trash2 />
              </Button>
            </ComboboxRow>
          )}
        </ComboboxList>
        {onOpen && (
          <Button variant="ghost" className="w-full" onClick={() => {
            setOpen(false);
            onOpen();
          }}>
            <FolderOpen />
            Open project
          </Button>
        )}
        <Button
          variant="ghost"
          className="w-full border-t-0 project-create"
          onClick={() => {
            setOpen(false);
            onCreate();
          }}
        >
          <Plus />
          New project
        </Button>
      </ComboboxPopup>
    </Combobox>
  );
}
