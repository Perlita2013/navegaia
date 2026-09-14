export const plans=[
 {id:'emprende',name:'Emprende',price:49900,shipments:25,documents:100,seats:2,copy:'Para comenzar a ordenar tu operación.'},
 {id:'crece',name:'Crece',price:129900,shipments:100,documents:500,seats:5,copy:'Para equipos que mueven más carga.'},
 {id:'empresa',name:'Empresa',price:279900,shipments:300,documents:1500,seats:12,copy:'Para supervisar una operación de mayor volumen.'},
 {id:'corporativo',name:'Corporativo',price:null,shipments:null,documents:null,seats:null,copy:'Capacidad y acompañamiento a medida.'}
] as const;
export const clp=(n:number)=>new Intl.NumberFormat('es-CL',{style:'currency',currency:'CLP',maximumFractionDigits:0}).format(n);
