import { useState, type ReactNode } from "react";
import { ChevronDown, Info } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectItem,
  SelectPopup,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Collapsible,
  CollapsibleTrigger,
  CollapsiblePanel,
} from "@/components/ui/collapsible";
import { Tooltip, TooltipTrigger, TooltipPopup } from "@/components/ui/tooltip";
import {
  AlertDialog,
  AlertDialogPopup,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogDescription,
  AlertDialogFooter,
} from "@/components/ui/alert-dialog";
import {
  Dialog,
  DialogPopup,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogPanel,
  DialogFooter,
} from "@/components/ui/dialog";

export function Choice({
  name,
  value,
  onChange,
  items,
  disabled = false,
}: {
  name: string;
  value: string;
  onChange: (v: string) => void;
  items: { value: string; label: string; disabled?: boolean }[];
  disabled?: boolean;
}) {
  return (
    <Select
      value={value}
      onValueChange={(v) => {
        if (v !== null) onChange(v);
      }}
      items={items}
      disabled={disabled}
    >
      <SelectTrigger aria-label={name} className="w-full min-w-0">
        <SelectValue />
      </SelectTrigger>
      <SelectPopup>
        {items.map((i) => (
          <SelectItem value={i.value} key={i.value} disabled={i.disabled}>
            {i.label}
          </SelectItem>
        ))}
      </SelectPopup>
    </Select>
  );
}
export function Fold({
  title,
  children,
  className = "",
  open,
  onOpenChange,
}: {
  title: ReactNode;
  children: ReactNode;
  className?: string;
  open?: boolean;
  onOpenChange?: (v: boolean) => void;
}) {
  return (
    <Collapsible className={className} open={open} onOpenChange={onOpenChange}>
      <CollapsibleTrigger
        render={<Button variant="ghost" className="fold-trigger" />}
      >
        <ChevronDown />
        {title}
      </CollapsibleTrigger>
      <CollapsiblePanel>{children}</CollapsiblePanel>
    </Collapsible>
  );
}
export function Hint({
  children,
  label = "Recording help",
}: {
  children: ReactNode;
  label?: string;
}) {
  return (
    <Tooltip>
      <TooltipTrigger
        render={<Button size="icon-sm" variant="ghost" aria-label={label} />}
      >
        <Info />
      </TooltipTrigger>
      <TooltipPopup>{children}</TooltipPopup>
    </Tooltip>
  );
}
export function Modal({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  panelClassName,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description: string;
  children: ReactNode;
  footer?: ReactNode;
  panelClassName?: string;
}) {
  return (
    <Dialog
      open={open}
      onOpenChange={(value) => {
        if (!value) onClose();
      }}
    >
      <DialogPopup className="studio-dialog">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <DialogPanel className={panelClassName}>{children}</DialogPanel>
        {footer && <DialogFooter>{footer}</DialogFooter>}
      </DialogPopup>
    </Dialog>
  );
}
export function useConfirm() {
  const [pending, setPending] = useState<{
    text: string;
    title?: string;
    accept?: string;
    destructive?: boolean;
    resolve: (v: boolean) => void;
  } | null>(null);
  const finish = (value: boolean) => {
    pending?.resolve(value);
    setPending(null);
  };
  const confirm = (text: string, title?: string, accept?: string, destructive = !title) =>
    new Promise<boolean>((resolve) =>
      setPending({ text, title, accept, destructive, resolve }),
    );
  const dialog = (
    <AlertDialog
      open={!!pending}
      onOpenChange={(open) => {
        if (!open) finish(false);
      }}
    >
      <AlertDialogPopup>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {pending?.title || "Discard unsaved changes?"}
          </AlertDialogTitle>
          <AlertDialogDescription>{pending?.text}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <Button variant="outline" onClick={() => finish(false)}>
            {pending?.title ? "Cancel" : "Keep editing"}
          </Button>
          <Button variant={pending?.destructive ? "destructive" : "default"} onClick={() => finish(true)}>
            {pending?.accept || "Discard changes"}
          </Button>
        </AlertDialogFooter>
      </AlertDialogPopup>
    </AlertDialog>
  );
  return { confirm, dialog };
}

export function ActionTip({
  text,
  children,
}: {
  text: string;
  children: React.ReactElement;
}) {
  return (
    <Tooltip>
      <TooltipTrigger render={children} />
      <TooltipPopup>{text}</TooltipPopup>
    </Tooltip>
  );
}
