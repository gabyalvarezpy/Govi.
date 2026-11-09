# GOVI CONTROL CENTER — diseño funcional

## Decisiones aprobadas
- Acceso: cuenta de fundador exclusivamente (sin alta automática de moderadores).
- Grabación: desactivada por defecto; conservar métricas y expedientes de denuncias, no grabar todos los directos.
- Privacidad: panel de gestión y métricas; no acceso encubierto a cámara, micrófono ni mensajes privados.

## Navegación del panel
1. Resumen: espectadores simultáneos, directos activos, horas emitidas, usuarios activos y alertas.
2. Directos: sala, streamer, modalidad IRL/OBS, inicio, duración, espectadores actuales y pico; acciones de moderación auditadas.
3. Analítica: espectadores simultáneos (serie temporal), espectadores únicos, sesiones, minutos vistos, retención y consumo de vídeo. Diferenciar visitas, usuarios únicos y concurrencia.
4. Creadores: perfil público, seguidores, horas emitidas, audiencia y estado de monetización.
5. Derechos de autor: cola de reclamaciones, obra protegida, titular, URL y marca temporal, declaración de buena fe/autoridad, pruebas aportadas, estado, decisión motivada y apelación.
6. Seguridad: denuncias de comunidad, reincidencias, bloqueos temporales y registro de acciones administrativas.
7. Costes: minutos de emisión, ancho de banda, costes del proveedor y comparación con ingresos.

## Flujo de reclamación de derechos
1. Formulario accesible desde GOVI con identidad y contacto del reclamante, titularidad/representación, identificación de la obra, URL exacta del directo/contenido, minuto aproximado y explicación.
2. Crear expediente con estado recibido y acuse de recibo.
3. Revisión humana; comprobar jurisdicción, legitimación, precisión y pruebas. No retirar automáticamente por una denuncia no verificada.
4. Si procede, limitar/retirar el contenido concreto y notificar al creador con motivos y vía de respuesta.
5. Tramitar contra-notificación/apelación y revisión humana. Registrar cada cambio, responsable y fecha.
6. Reclamaciones manifiestamente abusivas pueden rechazarse; reincidencia se evalúa con criterios publicados.
7. Preservar solo datos necesarios para gestionar la reclamación, con plazos de conservación, acceso restringido y borrado programado.

## Arquitectura y seguridad
- Supabase Auth identifica usuarios; tabla govi_admins define permisos. El fundador se aprovisiona manualmente por UUID desde Supabase SQL Editor.
- RLS en todas las tablas; nunca confiar en ocultar un botón en frontend como control de acceso.
- LiveKit para media; tokens de sala se generan en una función backend autenticada. Nunca exponer API secret/service_role en JavaScript cliente.
- Webhooks firmados del proveedor alimentan sesiones y métricas. No aceptar contadores enviados libremente por el navegador.
- Las tablas de este primer esquema guardan metadatos y métricas, no audio/video.
- Auditoría de acciones de moderación y administración antes de habilitar acciones destructivas.
- No grabar por defecto. Si en el futuro se añade grabación voluntaria, requerirá información clara, base jurídica, controles de acceso, retención y borrado.
- Revisar cumplimiento con asesoría especializada en DSA, normativa española de propiedad intelectual y RGPD antes del lanzamiento público.

## Alcance de esta entrega
Este documento y la migración SQL preparan el modelo de datos y las políticas RLS. No activan todavía el panel visual, el formulario público, los webhooks, las Edge Functions ni el streaming LiveKit. No se debe anunciar el panel como operativo hasta completar esos componentes y probar los permisos con cuentas distintas.
