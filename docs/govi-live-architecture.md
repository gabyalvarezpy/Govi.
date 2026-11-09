# GOVI LIVE — arquitectura inicial

## Objetivo
Módulo de transmisiones en directo independiente del feed, perfiles, historias y mensajes privados de GOVI.

## Experiencia prevista
- Emisión desde móvil: cámara y micrófono del dispositivo mediante WebRTC.
- Emisión desde PC: OBS mediante RTMP/RTMPS hacia LiveKit Ingress.
- Audiencia: usuarios autenticados de GOVI.
- Reproducción: WebRTC dentro de GOVI.
- Chat: mensajes en tiempo real mediante Supabase Realtime.
- Presencia/espectadores: presencia de la sala multimedia; no confiar en un contador enviado por el navegador.
- Moderación: anfitrión puede finalizar la sala y eliminar mensajes; siguiente fase añadirá moderadores, bloqueo y reportes.

## Servicios
- Supabase: autenticación, catálogo de directos, chat y políticas RLS.
- LiveKit Cloud: transporte de vídeo en tiempo real, ingreso RTMP para OBS y conexiones WebRTC.
- Backend seguro pendiente: Supabase Edge Function o servicio backend para emitir tokens LiveKit y crear/administrar Ingress. La API secret de LiveKit nunca se coloca en HTML, JavaScript público ni Git.

## Esquema inicial
La migración `supabase/govi-live.sql` crea únicamente:
- `govi_live_sessions`
- `govi_live_messages`

Ambas tablas tienen RLS. Solo usuarios autenticados pueden ver directos activos y participar en el chat. El anfitrión solo puede modificar su propia sesión. El chat solo acepta mensajes de usuarios autenticados mientras la sesión esté activa y el chat habilitado.

## Costes y decisión de proveedor
LiveKit documenta RTMP/RTMPS y WHIP Ingress para OBS, convirtiendo la entrada a WebRTC para los espectadores. LiveKit Cloud mide conexiones WebRTC, transferencia de datos y minutos de importación/transcodificación. Antes de habilitar emisión pública hay que revisar el coste real esperado y configurar límites/alertas.

## Fases
1. Base de datos aislada (esta entrega).
2. Backend seguro para tokens e Ingress.
3. Interfaz GOVI LIVE: listado, sala, cámara móvil, OBS y chat.
4. Pruebas con dos cuentas y móvil/OBS; después despliegue controlado.

## Estado
La migración y el documento son preparación de backend. No activan todavía transmisiones reales ni cambian la interfaz de GOVI.
