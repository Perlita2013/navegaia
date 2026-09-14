import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'NavegaIA | Tu operación, en un solo rumbo',description:'Gestión documental y seguimiento de embarques para agencias de aduana e importadores en Chile.',icons:{icon:'/favicon.svg'}};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="es-CL"><body>{children}</body></html>}
