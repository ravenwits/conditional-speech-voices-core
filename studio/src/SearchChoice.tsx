import { useState } from "react";
import { ChevronDown, Settings, Trash2 } from "lucide-react";
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

export type ProjectChoice = { key: string; name: string; language?: string };
export function ProjectPicker({
  items,
  current,
  language,
  languageFlags,
  languageLabel,
  voice,
  characterBase,
  trial,
  disabled,
  onSelect,
  onSettings,
  onDelete,
}: {
  items: ProjectChoice[];
  current: string;
  language: string;
  languageFlags: readonly string[];
  languageLabel: string;
  voice?: string;
  characterBase?: string;
  trial: boolean;
  disabled: boolean;
  onSelect: (key: string) => Promise<void>;
  onSettings: () => void;
  onDelete: (item: ProjectChoice) => Promise<void>;
}) {
  const [open, setOpen] = useState(false);
  const selected = items.find((i) => i.key === current);
  const ordered = selected ? [selected, ...items.filter((item) => item !== selected)] : items;
  return (
    <Combobox
      items={ordered}
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
            className="h-auto! w-full min-w-0 items-start gap-2 px-3 py-2.5 text-left"
            aria-label="Choose project"
          />
        }
      >
        <span className="min-w-0 flex-1">
          <span className="block truncate font-semibold">{selected?.name || "Opening project"}</span>
          <span className="mt-1.5 grid grid-cols-[auto_minmax(0,1fr)] gap-x-2 gap-y-0.5 text-xs font-normal">
            {voice && <><span className="text-muted-foreground">Voice ID</span><span className="truncate font-mono">{voice}</span></>}
            {characterBase && <><span className="text-muted-foreground">Base</span><span className="truncate">{characterBase}</span></>}
            <span className="text-muted-foreground">Language</span>
            <span className="flex min-w-0 items-center gap-1.5 truncate">
              {languageFlags.includes(language) && (
                <img className="size-4 shrink-0 object-contain" src={`/studio/flag/${encodeURIComponent(language)}`} alt="" />
              )}
              <span className="truncate">{languageLabel}</span>
            </span>
          </span>
          {trial && <span className="text-xs text-muted-foreground">Listening sample</span>}
        </span>
        <ChevronDown aria-hidden="true" className="shrink-0" />
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
              <ComboboxItem value={i} hideIndicator className="min-w-0 pe-1">
                {i.language && languageFlags.includes(i.language) && (
                  <img className="size-4 shrink-0 object-contain" src={`/studio/flag/${encodeURIComponent(i.language)}`} alt="" />
                )}
                <span className="min-w-0 truncate">{i.name}</span>
                {i.key !== current && i.key === "current" && (
                  <span className="active-project" title="The startup project also holds local packs and cannot be deleted here.">Startup</span>
                )}
                {i.key === current && (
                  <span className="ml-auto shrink-0 text-[11px] text-primary">current</span>
                )}
              </ComboboxItem>
              {i.key === current ? (
                <Button
                  size="icon-sm"
                  variant="ghost"
                  aria-label={"Settings for " + i.name}
                  title="Project settings"
                  onClick={() => {
                    setOpen(false);
                    onSettings();
                  }}
                >
                  <Settings aria-hidden="true" />
                </Button>
              ) : (
                <Button
                  size="icon-sm"
                  variant="ghost"
                  disabled={i.key === "current" || i.key.startsWith("saved:")}
                  title={i.key === "current" ? "The startup project also holds local packs." : i.key.startsWith("saved:") ? "This project is outside Studio’s managed projects folder." : "Remove project"}
                  aria-label={"Remove " + i.name}
                  onClick={() => {
                    setOpen(false);
                    void onDelete(i);
                  }}
                >
                  <Trash2 aria-hidden="true" />
                </Button>
              )}
            </ComboboxRow>
          )}
        </ComboboxList>
      </ComboboxPopup>
    </Combobox>
  );
}
