import {describe,it,expect} from 'vitest';
import {groupRows,filterRows,emptyFilters} from './model';
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
  const linked = {...rows[0], slot: 'Whisper_TraitVigilant_1', context: 'TraitVigilant'};
  const options = [...rows, linked];
  expect(filterRows(options, {...emptyFilters, trait:'Deaf'})).toEqual([linked]);
  expect(filterRows(options, {...emptyFilters, trait:'Conspicuous'})).toEqual([linked]);
  expect(filterRows(options, {...emptyFilters, trait:'Smoker'})).toEqual([]);
});

it('filters acting independently of delivery and situation',()=>{
 expect(filterRows(rows,{...emptyFilters,delivery:'normal',acting:'breathless'})).toEqual([rows[1]]);
 expect(filterRows(rows,{...emptyFilters,delivery:'whisper',acting:'breathless'})).toEqual([]);
});
