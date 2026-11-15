import {defineConfig} from 'vitest/config';
import {fileURLToPath,URL} from 'node:url';
import {existsSync} from 'node:fs';
const core = existsSync(fileURLToPath(new URL('../Contents/mods', import.meta.url))) ? '../Contents/mods' : '../mods';
export default defineConfig({resolve:{alias:{'@':fileURLToPath(new URL('./src',import.meta.url)), '@studio-languages': fileURLToPath(new URL(core + '/ConditionalSpeechVoicesCore/authoring/tools/artwork/language-names.json', import.meta.url))}},test:{environment:'jsdom',setupFiles:['./src/test-setup.ts'],include:['src/**/*.test.ts','src/**/*.test.tsx']}});
