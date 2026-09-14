import {createClient} from '@supabase/supabase-js';
let browser:ReturnType<typeof createClient>|null=null;
export const configured=()=>Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL&&process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
export function supabase(){if(!configured())throw Error('Conexión de cuentas pendiente de activación.');return browser??=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)}
export async function api(path:string,body?:unknown,method?:string){const {data}=await supabase().auth.getSession();const response=await fetch('/api/'+path,{method:method??(body?'POST':'GET'),headers:{Authorization:`Bearer ${data.session?.access_token??''}`,...(!(body instanceof FormData)?{'Content-Type':'application/json'}:{})},body:body instanceof FormData?body:body?JSON.stringify(body):undefined});const json=await response.json();if(!response.ok)throw Error(json.error??'No se pudo completar la operación.');return json}
