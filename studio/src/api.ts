let token=document.querySelector<HTMLMetaElement>('meta[name="voice-session"]')?.content||'';
export let revision='';
export function setRevision(value:string){revision=value;}
export class RequestError extends Error { constructor(message:string,public status:number){super(message);} }
export async function request<T>(path:string,data?:unknown,extra:Record<string,string>={},retry=true,trackRevision=true):Promise<T>{
  const binary=data instanceof File;
  const response=await fetch(path,{method:data===undefined?'GET':'POST',headers:{'X-Voice-Token':token,...(data!==undefined?{'X-Revision':revision,'Content-Type':binary?'application/octet-stream':'application/json'}:{}),...extra},body:data===undefined?undefined:binary?data:JSON.stringify(data)});
  if(response.status===403&&retry){
    const session=await fetch('/session',{headers:{'X-Voice-Request':'local-editor'}});
    if(session.ok){token=(await session.json()).token;return request<T>(path,data,extra,false,trackRevision);}
  }
  if(!response.ok){let message='Request failed';try{message=(await response.json()).error||message;}catch{ /* preserve status */ }
    throw new RequestError(message,response.status);
  }
  if(path.startsWith('/audio'))return await response.blob() as T;
  const result=await response.json();if(trackRevision && result.revision)revision=result.revision;return result as T;
}
export async function action(path:string,data:unknown={}){return (await request<{result:Record<string,unknown>}>(path,data)).result;}
