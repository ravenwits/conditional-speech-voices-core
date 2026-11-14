import {beforeEach,expect,it,vi} from 'vitest';
import {request,setRevision,RequestError} from './api';
beforeEach(()=>{vi.restoreAllMocks();setRevision('saved-revision');});
it('renews an expired local token once and retains the write revision',async()=>{
 const fetch=vi.spyOn(globalThis,'fetch').mockResolvedValueOnce(new Response('{}',{status:403})).mockResolvedValueOnce(new Response('{"token":"new-token"}')).mockResolvedValueOnce(new Response('{"revision":"next","result":{}}'));
 await request('/save',{slot:'Thirst_1'});
 expect(fetch).toHaveBeenCalledTimes(3);
 const headers=fetch.mock.calls[2][1]?.headers as Record<string,string>;
 expect(headers['X-Voice-Token']).toBe('new-token');expect(headers['X-Revision']).toBe('saved-revision');
});
it('never retries conflicting writes',async()=>{
 const fetch=vi.spyOn(globalThis,'fetch').mockResolvedValue(new Response('{"error":"Project changed"}',{status:409}));
 await expect(request('/save',{slot:'Thirst_1'})).rejects.toMatchObject({status:409,message:'Project changed'});
 expect(fetch).toHaveBeenCalledTimes(1);
});
it('does not loop forever if session renewal also fails authorization',async()=>{
 const fetch=vi.spyOn(globalThis,'fetch').mockResolvedValueOnce(new Response('{}',{status:403})).mockResolvedValueOnce(new Response('{"token":"new-token"}')).mockResolvedValueOnce(new Response('{"error":"Unauthorized"}',{status:403}));
 await expect(request('/project')).rejects.toBeInstanceOf(RequestError);expect(fetch).toHaveBeenCalledTimes(3);
});
