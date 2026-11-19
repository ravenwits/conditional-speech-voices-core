import {describe,it,expect} from 'vitest';
import {groupRows,filterRows,emptyFilters,isAlternate} from './model';
import type {Row} from './model';
const rows:Row[]=[{slot:'Thirst_1',context:'Thirst',family:'physical',category:'Dialogue',delivery:'normal',text:'I need water.',reference:'',direction:'',state:'missing'},{slot:'Expr_breathless_Thirst_1',context:'Thirst',family:'physical',category:'Dialogue',delivery:'normal',acting:'breathless',text:'Need a drink.',reference:'',direction:'',state:'approved'},{slot:'NativeBreath_1',context:'Exercise',family:'native',category:'Breath',delivery:'nonverbal',text:'Hah.',reference:'',direction:'',state:'pending'}];
describe('Core fields drive the recording list',()=>{
 it('keeps spoken breathless lines distinct from breathing sounds',()=>{expect(filterRows(rows,{...emptyFilters,category:'Breath'}).map(r=>r.slot)).toEqual(['NativeBreath_1']);});
 it('combines search, situation, category and missing status',()=>{expect(filterRows(rows,{...emptyFilters,search:'water',family:'physical',group:'Thirst',category:'Dialogue',state:'missing'})).toEqual([rows[0]]);expect(filterRows(rows,{...emptyFilters,state:'redo'})).toEqual([]);});
});

it('groups by Core situation and keeps filtered variation states',()=>{
 const grouped=groupRows(rows);expect(grouped).toHaveLength(2);
 expect(grouped[0].variations.map(r=>r.slot)).toEqual(['Thirst_1','Expr_breathless_Thirst_1']);
 expect(groupRows(filterRows(rows,{...emptyFilters,state:'approved'}))[0].variations).toEqual([rows[1]]);
});

it('filters trait-linked situations without including general reactions', () => {
  const linked = {...rows[0], slot: 'Whisper_TraitVigilant_1', context: 'TraitVigilant', traits: ['Deaf', 'Conspicuous']};
  const options = [...rows, linked];
  expect(filterRows(options, {...emptyFilters, trait:'Deaf'})).toEqual([linked]);
  expect(filterRows(options, {...emptyFilters, trait:'Conspicuous'})).toEqual([linked]);
  expect(filterRows(options, {...emptyFilters, trait:'Smoker'})).toEqual([]);
});

it('filters acting independently of delivery and situation',()=>{
 expect(filterRows(rows,{...emptyFilters,delivery:'normal',acting:'breathless'})).toEqual([rows[1]]);
 expect(filterRows(rows,{...emptyFilters,delivery:'whisper',acting:'breathless'})).toEqual([]);
});

 it('filters profanity independently and combines it with review status', () => {
 const explicit = {...rows[0], profanity:true};
 expect(filterRows([explicit, ...rows], {...emptyFilters, profanity:'yes'})).toEqual([explicit]);
 expect(filterRows([explicit, ...rows], {...emptyFilters, profanity:'yes', state:'approved'})).toEqual([]);
 });

it("orders primary recordings, delivery variants and alternates without changing situation order", () => {
  const primary = { ...rows[0], optional: true };
  const alternate = { ...primary, slot: "AnotherTake", alternate: true, source: primary.slot };
  const delivery = { ...primary, slot: "QuietVersion", source: primary.slot };
  const legacy = { ...primary, slot: "Alt_Whisper_Thirst_1" };
  const input = [alternate, rows[2], delivery, legacy, primary];
  const groups = groupRows(input);
  expect(groups.map((group) => group.context)).toEqual(["Thirst", "Exercise"]);
  expect(groups[0].variations).toEqual([primary, delivery, alternate, legacy]);
  expect(groups[0].variations.map(isAlternate)).toEqual([false, false, true, true]);
  expect(input[0]).toBe(alternate);
});

it('keeps optional missing takes out of the missing-audio queue', () => {
  const ordinary = rows[0];
  const optional = { ...ordinary, slot: 'Expr_slurred_Thirst_1', acting: 'drunk', optional: true };
  const choices = [ordinary, optional];

  expect(filterRows(choices, { ...emptyFilters, state: 'missing' })).toEqual([ordinary]);
  expect(filterRows(choices, { ...emptyFilters, state: 'optional-missing', search: 'drunk' })).toEqual([optional]);
  expect(filterRows(choices, { ...emptyFilters, state: 'required' }, new Set([ordinary.slot]))).toEqual([ordinary]);
});

it("finds a slot ID regardless of separator and capitalization", () => {
 const row = {...rows[0], slot:"PanicGrounding_1"};
 expect(filterRows([row], {...emptyFilters, search:"panic_grounding_1"})).toEqual([row]);
 expect(filterRows([row], {...emptyFilters, search:"PANIC-GROUNDING-1"})).toEqual([row]);
});
