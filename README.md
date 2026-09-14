# NavegaIA · MVP

Landing y app Next.js + TypeScript, Supabase/Postgres, Tailwind y componentes shadcn/Radix. Destino de despliegue: Vercel. Interfaz es-CL, fechas operativas America/Santiago.

## Estado de entrega

Construido y compilado localmente. No publicado: esta sesión no dispone de conexiones activadas a Vercel o Supabase. Tampoco dispone de dominio registrado, claves OCR/LLM, remitente de correo o Stripe test. Ninguna cuenta real ni contraseña fue creada. No introducir expedientes reales en la demo.

- `/`: landing NavegaIA.
- `/app?demo=1`: demostración con datos ficticios en memoria. Permite filtros, nuevo embarque, estados, detalle, revisión manual de ejemplo, exportación CSV y cambio de perspectiva de rol. Los datos se reinician al recargar. No finge extracción IA, pagos ni carga persistente.
- `/login`: alta y confirmación de correo, contraseña, recuperación y segundo factor TOTP.
- `/app`: cuenta real; exige Supabase y sesión AAL2. Creación del espacio de empresa; embarques, documentos, asignación del importador, auditoría y control Pro.
- Documentos: PDF/PNG/JPG hasta 4 MB por archivo por límites del endpoint de Vercel. Storage privado, ruta por empresa/documento, comprobación de MIME y firma, enlaces de descarga de 60 segundos, sin vista PDF embebida.
- OCR Azure Document Intelligence Read + LLM configurable: extrae JSON y exige confirmación humana. Pro y límite de 30 solicitudes/hora/empresa.
- Alertas: días libres desde ETA, fecha de vencimiento documental y cambios de estado; cola durable, reintentos e idempotencia con Resend.
- Semáforo: capítulo 93, puerto marcado internamente e incidentes registrados. No representa normas oficiales, fiscalización ni probabilidad de selectividad. La primera UI permite indicar partida; editar flags de puerto/incidentes requiere ampliar el formulario.
- Stripe **test exclusivamente**: checkout recurrente, cantidad de usuarios actual y webhook firmado. No acepta claves de producción.
- Integraciones SICEX / SNA / Aduanas / Editrade / AduanaNet: `TODO-INTEGRACIÓN`. No se transmiten DUS/DIN.

## Validación ejecutada

`npm run build` completó compilación y TypeScript. `npm test` pasó 21 pruebas: 6 de demurrage, 6 del contrato de extracción y 8 escenarios de RLS dentro de una prueba padre. Se ejecutaron las migraciones reales sobre PostgreSQL embebido (PGlite), con esquemas Auth/Storage mínimos de prueba.

RLS verifica lectura/escritura cruzada, importador restringido, falta de AAL2, escalamiento de roles, plan protegido, auditoría no modificable, enlaces entre tenants, Storage y generación automática de eventos/auditoría.

**No se han ejecutado pruebas sobre Supabase remoto, proveedores OCR/LLM, entrega de emails, checkout/webhook reales ni navegador.** Las pruebas de extracción verifican validación del contrato, no precisión del modelo. La meta ≥90% sigue sin demostrar: se debe medir con un corpus chileno etiquetado, por campo y por tipo de documento. No usar 90% como promesa comercial hasta esa medición.

## Ejecutar localmente

Node.js 22 o posterior.

```sh
npm ci
cp .env.example .env.local
npm run dev
```

Sin credenciales, abre la demo; los endpoints reales fallan de forma cerrada. Para validar:

```sh
npm test
npm run build
```

## Activación en Supabase

1. Crear un proyecto nuevo para NavegaIA. Aplicar en orden `supabase/migrations/001_core.sql` y `002_jobs.sql` con el SQL editor o el flujo de migraciones. No ejecutar sobre un proyecto que ya tenga tablas de igual nombre.
2. Configurar Authentication: email y contraseña, confirmación de correo obligatoria, contraseña mínima de 12 caracteres, protección contra contraseñas filtradas cuando esté disponible, TOTP habilitado, límites de intento y SMTP para emails de autenticación. Configurar CAPTCHA antes de alta pública masiva (su UI no está incluida todavía).
3. Definir Site URL y URLs permitidas para `/login` y `/login?recovery=1`, primero con la URL Vercel y después con `https://navegaia.cl`.
4. Guardar URL y anon key públicas como `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY`. La service-role key va **solo en el servidor** y se usa exclusivamente para las RPC limitadas de cron y facturación.
5. Crear tu cuenta desde la app, confirmar email y escanear TOTP. Al crear empresa quedas como **owner de esa empresa**, no como superadministradora de todas las agencias.
6. Gerente, ejecutivo e importador crean y confirman sus cuentas; el owner agrega sus correos exactos desde Equipo. Una identidad pertenece a una empresa en este MVP. El importador no debe crear una empresa: espera asignación y pulsa Actualizar acceso.
7. Asignar el usuario importador en el embarque y marcar solo los documentos que deseas compartir. El nombre de la empresa importadora por sí solo no concede acceso.

No se almacenan contraseñas en tablas de negocio, ni se incluyen credenciales comunes. La pérdida del autenticador requiere un procedimiento verificado de recuperación por administración de Supabase; no se ofrece un bypass por correo del segundo factor.

## Publicación en Vercel

1. Subir este directorio a un repositorio privado e importarlo en Vercel como Next.js. Raíz: este directorio, sin anidar accidentalmente el proyecto.
2. Cargar variables desde `.env.example` en el gestor seguro de Vercel. Las variables `NEXT_PUBLIC_*` requieren recompilar después de modificarlas.
3. Configurar `APP_URL` con el dominio temporal HTTPS. Desplegar. El landing y demo funcionan sin proveedores, pero las cuentas necesitan Supabase.
4. Comprobar los flujos reales de dos empresas independientes, 2FA, importador, carga/descarga y auditoría contra Supabase antes de admitir documentos reales de pilotos.
5. Agregar `navegaia.cl` y `www.navegaia.cl` cuando se compre el dominio; usar los registros DNS que indique Vercel. Actualizar `APP_URL` y redirects de Supabase.

No cambiar los destinos DNS existentes sin confirmar titularidad. Registrar dominio o marca no se ha ejecutado aquí.

## Proveedores opcionales y controles

### IA documental

`AZURE_DOCUMENT_ENDPOINT`: endpoint HTTPS de Azure Document Intelligence; `AZURE_DOCUMENT_KEY`: su clave. Read API `2024-11-30`. `LLM_BASE_URL`: endpoint HTTPS compatible con chat completions; `LLM_API_KEY` y `LLM_MODEL`: completar con modelo contratado que admita JSON mode. El servidor valida la salida con Zod, rechaza pesos inconsistentes, campos inesperados y números ambiguos expresados como cadenas. No se infiere RUT de un emisor extranjero ni partida ausente.

No se ocultan errores del proveedor tras datos simulados. Antes de pilotos, acordar el tratamiento y retención de documentos con cada proveedor. La validación de firma de archivos no reemplaza un antivirus; no hay antivirus ni DLP en esta entrega.

### Correos y cron

Configurar `RESEND_API_KEY`, `EMAIL_FROM` con dominio verificado y `CRON_SECRET` aleatorio. `vercel.json` programa ejecución diaria a las 12:00 UTC (08:00 o 09:00 Santiago según horario estacional). No es alerta instantánea: los cambios de estado entran a la cola y se despachan por ese proceso. Cada llamada envía hasta 5 mensajes y reintenta hasta 5 veces, con lease e idempotencia del proveedor. Para pilotos con más destinatarios, configurar ejecución frecuente en un plan que lo permita o un scheduler externo con el mismo secreto. Requiere monitorear filas en estado error/intentos agotados; no hay consola de reintentos aún.

### Stripe test

Configurar `sk_test_*`, precio recurrente Pro (`STRIPE_PRO_PRICE_ID`) y firma del webhook `STRIPE_WEBHOOK_SECRET`. Registrar `/api/webhook` para eventos de suscripción created/updated/deleted. El precio se define fuera de la app; no se inventaron valores. La app usa el número de miembros al iniciar checkout. La conciliación automática de cambios posteriores en el número de asientos y autoservicio de cancelación **quedan pendientes antes de vender suscripciones reales**. El webhook vuelve a consultar el estado actual de Stripe para evitar regresión por eventos fuera de orden.

## Seguridad y límites conocidos

- RLS habilitada en todas las tablas públicas. La identidad y rol se consultan desde membresía de servidor, nunca desde un selector o metadata editable del usuario.
- Toda petición de usuario usa su JWT con anon key; no hay service-role en frontend. Los trabajos automáticos requieren privilegios de sistema y están limitados a tres RPC explícitas; son la excepción de sistema al aislamiento por sesión de usuario.
- Auditoría de mutaciones mediante triggers, registros de lectura/descarga/exportación desde API. Los accesos de autenticación se encuentran en Auth Audit Logs de Supabase. La auditoría de **todo SELECT ejecutado fuera de la API**, por ejemplo directamente vía PostgREST con un token, no está implementada; habilitar auditoría de base adicional si es un requisito contractual.
- Encabezados de seguridad, bloqueo de marcos, descargas privadas de vida corta y validación de datos. CSP conserva `unsafe-inline` para compatibilidad con Next.js; migrar a nonces si el nivel de riesgo del piloto lo requiere. No se certifica seguridad ni cumplimiento normativo por estos controles.
- Primera bandeja: hasta 1.000 embarques, 2.000 documentos, 300 eventos y 200 registros de auditoría. Añadir paginación de servidor antes de superar esos volúmenes.
- No hay borrado de embarques ni de documentos revisados desde UI. No hay administración de bajas/cambio de rol en UI aún: altas con rol fijo en esta versión. No hay integración automática de navieras ni obtención de ETA externa.
- Owner está limitado a su empresa; si se desea un portal global de Stardesign para administrar suscriptores, debe implementarse como capacidad separada y auditada.

## Avance y decisiones · entrega inicial

**Avance:** landing, demo, cuenta/MFA, schema/RLS, auditoría, embarques, documentos y revisión, portal limitado, reglas, integraciones de proveedores y test Stripe en código. Compilación y 21 pruebas completadas.

**Decisiones:** Next.js real y Vercel según lo pedido; demo explícita mientras faltan conexiones; owner por empresa; importador por ID de usuario; ninguna transmisión aduanera; precios sin inventar; 2FA obligatorio; archivos de hasta 4 MB para mantener simple el endpoint inicial.

**Siguiente paso:** conectar Supabase y Vercel, aplicar migraciones y publicar en URL temporal. Después conectar proveedores, confirmar 2FA con dispositivos reales y completar validación de precisión documental y entrega de correos. La publicación en `navegaia.cl` depende de la compra y configuración del dominio.

Referencias técnicas consultadas: [Supabase TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp), [Azure Read](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/read?view=doc-intel-4.0.0), documentación local instalada de Next.js 16.3.5.

## Actualización comercial · septiembre 2026

Landing con cuatro planes, FAQ desplegable y navegación móvil. Precios de lanzamiento definidos para revisión comercial (no investigación de mercado): Emprende $49.900, Crece $129.900, Empresa $279.900 CLP/mes + IVA; Corporativo por cotización. Contrato de 12 meses, pago mensual; contratación asistida mediante contacto@stardesign.cl. No se generan cobros ni contratos legalmente aceptados al cambiar una fila en Owner. La IA y los emails requieren activación y cotización adicional. El antiguo checkout por usuario está deshabilitado.

Aplicar migraciones **001, 002 y 003** en Supabase, en ese orden. Las variables de conexión de cuentas continúan siendo necesarias. La nueva migración agrega cupos comerciales, acceso comercial de plataforma y auditoría. El mes se calcula en America/Santiago; los registros de documentos cancelados conservan consumo. La suspensión comercial bloquea altas nuevas; conserva consultas y el trabajo sobre registros existentes. Los contratos se gestionan manualmente; las fechas no ejecutan renovación, suspensión ni cobros automáticos.

- `/owner`: panel real; requiere contraseña, MFA y una fila administrativa en `platform_owners`.
- `/owner?demo=1`: empresas ficticias y cambios solo en memoria, jamás llama a la API de Owner.
- `/login?next=owner`: entrada directa al panel después de MFA.
- Gerente: supervisión y altas de ejecutivos/importadores de su empresa; el administrador de empresa (`owner` heredado) también puede agregar gerentes.

Para activar a la dueña, crear/confirmar su cuenta en Supabase Auth y verificar personalmente su UUID. Luego ejecutar en el SQL Editor administrativo (sustituir el marcador):

```sql
insert into public.platform_owners(user_id)
select id from auth.users
where id = 'UUID_CONFIRMADO_DE_LA_DUENA'::uuid
  and email_confirmed_at is not null;
```

Nunca asignar Owner de plataforma mediante registro público o metadatos editables. Esta identidad puede permanecer sin empresa. No usar service_role en las rutas de usuario. El panel comercial expone resúmenes de consumo y nombres/roles de usuarios mediante RPC restringida y auditada; no otorga lectura transversal de BL, documentos ni Storage. El registro de empresas se completa desde el onboarding del administrador de cada empresa. Aplicar `003` antes de activar el panel; un despliegue en Render por sí solo no ejecuta SQL en Supabase.

Validación: `npm test` (RLS, extracción y demurrage), `npm run typecheck`, `npm run build`. Los tests de RLS ejecutan PostgreSQL embebido PGlite, no el proyecto Supabase real. No confundir compilación con validación de credenciales o pagos.
