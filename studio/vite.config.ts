import {defineConfig} from 'vite';
import tailwindcss from '@tailwindcss/vite';
import {fileURLToPath, URL} from 'node:url';
import {existsSync} from 'node:fs';
const root=fileURLToPath(new URL('..',import.meta.url));
const core=existsSync(root+'/Contents/mods')?'../Contents/mods':'../mods';
export default defineConfig({
 plugins:[tailwindcss()],
 resolve:{alias:{'@':fileURLToPath(new URL('./src',import.meta.url))}},
 base:'/studio/',
 build:{outDir:core+'/ConditionalSpeechVoicesCore/authoring/tools/studio',emptyOutDir:true,assetsInlineLimit:0},
});
