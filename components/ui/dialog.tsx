'use client';
import * as D from '@radix-ui/react-dialog';
import {X} from 'lucide-react';
export const Dialog=D.Root;export const DialogTrigger=D.Trigger;export const DialogTitle=D.Title;export const DialogDescription=D.Description;
export function DialogContent({children}: {children:React.ReactNode}){return <D.Portal><D.Overlay className="overlay"/><D.Content className="dialog"><D.Close className="close" aria-label="Cerrar"><X size={20}/></D.Close>{children}</D.Content></D.Portal>}
