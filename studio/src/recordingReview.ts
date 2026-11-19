import { filterRows, groupRows, type Filters, type Project, type Row } from "./model";

type SavedRecording = Pick<Row, "slot" | "text" | "speechScript" | "direction" | "state">;
type ReviewSnapshot = Pick<Project, "rows" | "coverage" | "buildCoverage">;

/** Apply the confirmed recording once, including coverage shared by several takes. */
export function applySavedReview(project: Project, previous: Row, saved?: SavedRecording): ReviewSnapshot | undefined {
  if (saved?.slot !== previous.slot) return;
  const approvalChanged = (previous.state === "approved") !== (saved.state === "approved");
  // Older workbenches only report missing groups. They cannot tell us which groups reopen.
  if (approvalChanged && project.buildCoverage && !project.buildCoverage.pools) return;
  const rows = project.rows.map((row) => row.slot === saved.slot ? { ...row, ...saved } : row);
  const coverage = { ...project.coverage };
  coverage[previous.state]--;
  coverage[saved.state]++;
  const pools = project.buildCoverage?.pools;
  if (!approvalChanged || !pools) return { rows, coverage, buildCoverage: project.buildCoverage };

  const approved = new Set(rows.filter((row) => row.state === "approved").map((row) => row.slot));
  const missingSlots = Object.fromEntries(
    Object.entries(pools).filter(([, slots]) => !slots.some((slot) => approved.has(slot))),
  );
  const missing = Object.keys(missingSlots);
  const required = Object.keys(pools).length;
  return { rows, coverage, buildCoverage: { pools, required, covered: required - missing.length, missing, missingSlots } };
}

/** Keep the reviewer's place even when approval removes several takes from the filter. */
export function selectionAfterReview(snapshot: ReviewSnapshot, filters: Filters, previousOrder: Row[], slot: string, advance: boolean) {
  const requiredSlots = new Set(Object.values(snapshot.buildCoverage?.missingSlots ?? {}).flat());
  const groups = groupRows(filterRows(snapshot.rows, filters, requiredSlots));
  const matches = new Map(groups.flatMap((group) => group.variations).map((row) => [row.slot, row]));
  const reviewed = matches.get(slot);
  let row = reviewed;
  const index = previousOrder.findIndex((item) => item.slot === slot);
  if (index >= 0 && (advance || !reviewed)) {
    const following = previousOrder.slice(index + 1).find((item) => matches.has(item.slot));
    if (following) row = matches.get(following.slot);
    else if (!reviewed) {
      const preceding = previousOrder.slice(0, index).reverse().find((item) => matches.has(item.slot));
      if (preceding) row = matches.get(preceding.slot);
    }
  }
  row ??= groups[0]?.variations[0];
  const groupIndex = groups.findIndex((group) => group.context === row?.context);
  return { row, groupIndex };
}
