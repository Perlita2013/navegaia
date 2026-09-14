import {context,check,failure} from '@/lib/server';
export async function GET(request:Request){try{const {db}=await context(request);const r=await db.rpc('company_usage');check(r.error);return Response.json(r.data,{headers:{'Cache-Control':'no-store'}})}catch(e){return failure(e)}}
