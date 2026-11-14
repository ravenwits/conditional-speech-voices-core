import { it, expect } from "vitest";
import { languages } from "./languages";
it("offers the requested languages and scripts with valid unique pack codes", () => {
  const codes = languages.map((l) => l.value);
  expect(new Set(codes).size).toBe(codes.length);
  for (const code of codes) expect(code).toMatch(/^[A-Z_]{2,8}$/);
  for (const name of [
    "Acehnese",
    "Acholi",
    "Alur",
    "Crimean Tatar (Cyrillic)",
    "Inuktut (Syllabics)",
    "Santali (Ol Chiki)",
    "Tamazight (Tifinagh)",
    "Punjabi (Shahmukhi)",
    "Yucatec Maya",
    "Turkish",
  ])
    expect(languages.some((l) => l.label.startsWith(name))).toBe(true);
});
