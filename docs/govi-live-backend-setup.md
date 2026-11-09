# Configuración del backend GOVI LIVE

La función `govi-live-control` valida la sesión de Supabase antes de emitir tokens LiveKit o crear el Ingress RTMP de OBS.

## Secretos necesarios en Supabase Edge Functions

Configurar en Supabase > Edge Functions > Secrets (nunca en el HTML ni en Git):
- `LIVEKIT_URL`: URL HTTPS/WSS del proyecto LiveKit.
- `LIVEKIT_API_KEY`: API key del proyecto LiveKit.
- `LIVEKIT_API_SECRET`: API secret del proyecto LiveKit.

Supabase proporciona `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` al runtime de Edge Functions. No copiar la service role key al navegador.

## Migración adicional
Ejecutar `supabase/govi-live-ingress.sql` en SQL Editor después de `govi-live.sql`. Añade el identificador de Ingress; nunca guarda la clave RTMP.

## Despliegue
Desde la raíz del proyecto Supabase CLI:
```sh
supabase functions deploy govi-live-control
```

La función espera POST JSON:
- `{"action":"token","session_id":"UUID"}`: entrega token LiveKit de 10 minutos. El anfitrión puede publicar cámara/micrófono; los demás solo suscribirse.
- `{"action":"obs-ingress","session_id":"UUID"}`: solo el anfitrión puede crear el Ingress RTMP de OBS. La URL y la stream key se devuelven una vez y no se guardan en la base de datos.

Todas las peticiones requieren `Authorization: Bearer <supabase access token>`. La función vuelve a validar el usuario con Supabase Auth y comprueba que la sesión esté activa. El endpoint no crea sesiones; estas deben crearse mediante la política RLS de la tabla.

## Antes de probar
1. Crear un proyecto LiveKit Cloud y copiar sus credenciales a Supabase Edge Function Secrets.
2. Ejecutar las dos migraciones SQL, en orden.
3. Desplegar la función.
4. Integrar el cliente LiveKit en la interfaz GOVI y probar con cuentas separadas.
5. Configurar OBS con la URL RTMP y stream key devueltas por la función; no enviar la clave a chats ni capturas públicas.

La función por sí sola no añade botones ni activa emisión en la interfaz.
