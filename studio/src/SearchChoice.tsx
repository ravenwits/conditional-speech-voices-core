import { useState } from "react";
import { ChevronDown, FolderOpen, Settings, Plus } from "lucide-react";
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
              {i.label}
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
  trial,
  disabled,
  onSelect,
  onDetails,
  onCreate,
}: {
  items: ProjectChoice[];
  current: string;
  language: string;
  trial: boolean;
  disabled: boolean;
  onSelect: (key: string) => Promise<void>;
  onDetails: (key: string) => Promise<void>;
  onCreate: () => void;
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
        <FolderOpen />
        {selected?.name || "Opening project"}{" "}
        <span className="subtle">
          {language}
          {trial ? " / Trial" : ""}
        </span>
        <ChevronDown />
      </ComboboxTrigger>
      <ComboboxPopup className="project-popup">
        <ComboboxInput
          className="project-search border-b-0"
          aria-label="Find a project"
          placeholder="Find a project…"
          showTrigger={false}
        />
        <ComboboxEmpty>No projects found.</ComboboxEmpty>
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
            </ComboboxRow>
          )}
        </ComboboxList>
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
