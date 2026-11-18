import { Popover } from "@base-ui/react/popover";
import type { ComponentProps } from "react";
import { cn } from "@/lib/utils";

export const PopoverRoot = Popover.Root;
export const PopoverTrigger = Popover.Trigger;

export function PopoverPopup({ className, ...props }: ComponentProps<typeof Popover.Popup>) {
  return (
    <Popover.Portal>
      <Popover.Positioner align="end" sideOffset={6} className="z-50">
        <Popover.Popup className={cn("rounded-lg border bg-popover p-2 text-popover-foreground shadow-lg outline-none", className)} {...props} />
      </Popover.Positioner>
    </Popover.Portal>
  );
}
