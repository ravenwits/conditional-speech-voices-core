import {afterEach,vi} from 'vitest';
import {cleanup} from '@testing-library/react';
afterEach(()=>cleanup());
globalThis.ResizeObserver=class {observe(){}unobserve(){}disconnect(){}};
Object.defineProperty(window,'matchMedia',{value:()=>({matches:false,addEventListener(){},removeEventListener(){}})});
window.confirm=vi.fn(()=>true);
Element.prototype.getAnimations=()=>[];
