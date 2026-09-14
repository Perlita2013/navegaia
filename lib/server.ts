import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
export class HttpError extends Error {constructor(message:string,public status=400){super(message)}}
export async function context(request:Request,allowUnassigned=false){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 if(!url||!key)throw new HttpError('Conexión Supabase pendiente de activación.',503);
 const token=request.headers.get('authorization')?.match(/^Bearer ([\w.-]+)$/)?.[1];if(!token)throw new HttpError('Inicia sesión para continuar.',401);
 const db=createClient(url,key,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await db.auth.getUser(token);if(error||!data.user)throw new HttpError('Sesión inválida o vencida.',401);
 // Token authenticity verified by getUser; RLS independently checks JWT AAL for every table.
 const claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString());if(claims.aal!=='aal2')throw new HttpError('Verifica tu segundo factor para acceder.',403);
 const result=await db.from('usuarios').select('*').eq('id',data.user.id).maybeSingle();if(result.error)throw new HttpError('No se pudo consultar tu acceso.',503);
 if(!result.data&&!allowUnassigned)throw new HttpError('Aún no perteneces a una empresa.',403);
 return {db,user:data.user,profile:result.data};
}
export function requireStaff(profile:{rol:string}){if(!['owner','gerente','ejecutivo'].includes(profile.rol))throw new HttpError('Tu rol permite solo lectura.',403)}
export function failure(e:unknown){if(e instanceof HttpError)return Response.json({error:e.message},{status:e.status});if(e instanceof z.ZodError)return Response.json({error:'Revisa los campos: '+e.issues.map(i=>i.path.join('.')+': '+i.message).join(';')},{status:400});console.error('NavegaIA request failed',e instanceof Error?e.name:'UnknownError');return Response.json({error:'No se pudo completar la operación. Intenta nuevamente.'},{status:500})}
export function check(error:{message:string}|null){if(error)throw new HttpError('Operación rechazada. Revisa los datos, permisos o duplicados.',400)}
export async function json(request:Request){if(Number(request.headers.get('content-length')??0)>100000)throw new HttpError('Solicitud demasiado grande.',413);const text=await request.text();if(text.length>100000)throw new HttpError('Solicitud demasiado grande.',413);try{return JSON.parse(text)}catch{throw new HttpError('JSON inválido.')}}
export async function audit(db:Awaited<ReturnType<typeof context>>['db'],accion:string,tabla:string,registro?:string){const r=await db.rpc('log_action',{accion,tabla,registro:registro??null});check(r.error)}
