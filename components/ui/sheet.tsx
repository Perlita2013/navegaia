'use client';
import * as D from '@radix-ui/react-dialog';
import {X} from 'lucide-react';
export const Sheet=D.Root;export const SheetTrigger=D.Trigger;export const SheetTitle=D.Title;export const SheetDescription=D.Description;
export function SheetContent({children}: {children:React.ReactNode}){return <D.Portal><D.Overlay className="overlay"/><D.Content className="sheet"><D.Close className="close" aria-label="Cerrar"><X size={20}/></D.Close>{children}</D.Content></D.Portal>}
