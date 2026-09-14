import {createClient} from '@supabase/supabase-js';
import {HttpError} from './server';
// Only for bounded machine RPCs. All browser/user requests use JWT + RLS in server.ts.
export function jobs(){if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.SUPABASE_SERVICE_ROLE_KEY)throw new HttpError('Procesos automáticos pendientes de configuración.',503);return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}})}
