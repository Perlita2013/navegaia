'use client';
import {useEffect,useState} from 'react';
import Link from 'next/link';
import {api} from '@/lib/supabase';
import {plans,clp} from '@/lib/plans';
type Usage={plan:string;estado:string;precio:number;limite_embarques:number;limite_documentos:number;limite_usuarios:number;embarques:number;documentos:number;usuarios:number};
export function Subscription({demo}:{demo:boolean}){const [usage,setUsage]=useState<Usage|null>(null),[error,setError]=useState('');
useEffect(()=>{if(demo){setUsage({plan:'crece',estado:'piloto',precio:129900,limite_embarques:100,limite_documentos:500,limite_usuarios:5,embarques:6,documentos:3,usuarios:3});return}api('usage').then(setUsage).catch(e=>setError((e as Error).message))},[demo]);
return <section className="card"><h2>Plan y consumo</h2>{error&&<p role="alert">{error}</p>}{usage?<><h3>{plans.find(p=>p.id===usage.plan)?.name} · {clp(usage.precio)} / mes + IVA</h3><p>Contrato anual · pago mensual. Estado: {usage.estado}.{demo?' Consumo de ejemplo.':''}</p>{[['Embarques nuevos',usage.embarques,usage.limite_embarques],['Documentos',usage.documentos,usage.limite_documentos],['Usuarios internos',usage.usuarios,usage.limite_usuarios]].map(([label,used,limit])=><div className="usage-meter" key={label}><span>{label}: {used} / {limit}</span><progress max={Number(limit)} value={Math.min(Number(used),Number(limit))} aria-label={String(label)}/></div>)}<p>Los cupos de documentos y embarques se renuevan cada mes calendario, hora de Chile. Las consultas no consumen nuevos cupos.</p></>:!error&&<p>Cargando consumo…</p>}<Link href="/#planes">Comparar planes y solicitar ampliación →</Link></section>}
