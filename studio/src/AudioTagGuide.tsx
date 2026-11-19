import { ArrowUpRight, BookOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogPanel,
  DialogPopup,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

const placement = [
  {
    label: "At the start",
    tip: "Set the delivery before the first word.",
    tag: "[whispers]",
    after: "I think they're still outside.",
  },
  {
    label: "Between phrases",
    tip: "Put a change of delivery right before the words it affects.",
    before: "I had it…",
    tag: "[steadier voice]",
    after: "Let me try again.",
  },
  {
    label: "At the end",
    tip: "Place a vocal reaction after the last spoken word.",
    before: "We're safe for now.",
    tag: "[exhales]",
  },
] as const;

const cueTypes = [
  { title: "Delivery", examples: ["[whispers]", "[low, gravelly voice]"], tip: "Set volume, pace or voice quality." },
  { title: "Emotion", examples: ["[voice tight with fear]", "[softens with relief]"], tip: "Describe how the emotion changes the voice." },
  { title: "Vocal reactions", examples: ["[sighs]", "[clears throat]"], tip: "Place audible breaths or reactions where they belong." },
];

export function AudioTagGuide({ open, onOpenChange }: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger render={<button type="button" className="inline-flex items-center gap-1.5 rounded-sm text-xs font-medium text-primary hover:underline focus-visible:outline-2 focus-visible:outline-offset-2" />}>
        <BookOpen aria-hidden="true" className="size-3.5" />
        Audio tag guide
      </DialogTrigger>
      <DialogPopup className="sm:max-w-2xl">
        <DialogHeader className="pr-12">
          <DialogTitle>Audio tag guide</DialogTitle>
          <DialogDescription>Direct how Eleven v4 reads a line with short cues in square brackets.</DialogDescription>
        </DialogHeader>
        <DialogPanel className="space-y-6 text-sm">
          <section aria-label="Tag placement" className="space-y-3">
            <h3 className="font-semibold">Place tags where they take effect</h3>
            <div className="divide-y rounded-lg border">
              {placement.map((example) => {
                const before = "before" in example ? example.before : "";
                const after = "after" in example ? example.after : "";
                return (
                  <div key={example.label} className="grid gap-1 px-3 py-2.5 sm:grid-cols-[9rem_1fr] sm:gap-x-3">
                    <h4 className="font-medium">{example.label}</h4>
                    <div className="min-w-0">
                      <p className="wrap-break-word" lang="en">
                        {before}{before && " "}
                        <code className="font-mono font-semibold text-primary">{example.tag}</code>{after && " "}
                        {after}
                      </p>
                      <p className="mt-1 text-xs text-muted-foreground">{example.tip}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
          <section aria-label="Types of audio tags" className="space-y-2">
            <h3 className="font-semibold">Describe what you want to hear</h3>
            <dl className="grid gap-2 sm:grid-cols-3">
              {cueTypes.map(({ title, examples, tip }) => (
                <div key={title} className="space-y-1.5 rounded-lg bg-muted/48 p-3">
                  <dt className="font-medium">{title}</dt>
                  <dd className="text-xs text-muted-foreground">{tip}</dd>
                  <dd className="flex flex-wrap gap-x-2 gap-y-1 text-xs">
                    {examples.map((tag) => <code key={tag} className="font-mono font-semibold text-primary">{tag}</code>)}
                  </dd>
                </div>
              ))}
            </dl>
            <p className="text-xs leading-relaxed text-muted-foreground">
              Start with one cue that fits the recording guidance. Add another when the performance changes.
              Use punctuation for natural pauses. Avoid background effects and conflicting cues.
              Listen with your selected voice since delivery can vary between voices. There are likely many more effective tags beyond this list.
              Experiment with descriptive emotional states and actions to discover what works for your specific use case.
            </p>
          </section>
          <section aria-label="Using tags in Studio" className="space-y-2 border-t pt-4">
            <h3 className="font-semibold">Save, preview and listen</h3>
            <ol className="list-decimal space-y-2 pl-5 text-xs leading-relaxed text-muted-foreground">
              <li>Type the tags in the main caption editor and select <strong className="text-foreground">Save</strong>. Studio keeps the tags in the generation script and strips them from the in-game caption.</li>
              <li>Studio uses your inline tags in the positions you choose. Save the text without tags to use the Core recommended tags again.</li>
              <li>Open <strong className="text-foreground">Generate audio</strong> to check the script. <strong className="text-foreground">Generate preview</strong> uses credits. Listen before choosing <strong className="text-foreground">Use this take</strong>.</li>
            </ol>
          </section>
        </DialogPanel>
        <DialogFooter className="sm:items-center sm:justify-between">
          <a className="inline-flex items-center justify-center gap-1.5 rounded-sm text-xs font-medium text-primary hover:underline focus-visible:outline-2 focus-visible:outline-offset-2"
            href="https://elevenlabs.io/docs/overview/capabilities/text-to-speech/best-practices#prompting-eleven-v4"
            target="_blank" rel="noreferrer">
            ElevenLabs prompting guide <ArrowUpRight aria-hidden="true" className="size-3.5" />
          </a>
          <DialogClose render={<Button variant="outline" />}>Done</DialogClose>
        </DialogFooter>
      </DialogPopup>
    </Dialog>
  );
}
