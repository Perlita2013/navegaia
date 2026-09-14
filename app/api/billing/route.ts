import {context,failure,HttpError} from '@/lib/server';
// El antiguo checkout por usuario no corresponde a los contratos por empresa.
export async function POST(request:Request){try{await context(request);throw new HttpError('Contratación asistida: solicita tu plan desde la sección Planes. El cobro automático aún no está habilitado.',503)}catch(e){return failure(e)}}
