import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken, IngressInput, LiveKitAPI } from "npm:livekit-server-sdk@2.19.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "Método no permitido" });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const bearer = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!bearer) return reply(401, { error: "Inicia sesión en GOVI" });

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
    const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");

    if (!supabaseUrl || !anonKey || !serviceRoleKey || !livekitUrl || !livekitApiKey || !livekitApiSecret) {
      return reply(503, { error: "GOVI LIVE todavía no está configurado en el servidor" });
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${bearer}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await authClient.auth.getUser(bearer);
    if (authError || !authData.user) return reply(401, { error: "Sesión no válida" });

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json().catch(() => ({}));
    const action = body?.action;
    const sessionId = typeof body?.session_id === "string" ? body.session_id : "";
    if (!sessionId) return reply(400, { error: "Falta session_id" });

    const { data: session, error: sessionError } = await admin
      .from("govi_live_sessions")
      .select("id, host_id, room_name, title, status, ingress_id")
      .eq("id", sessionId)
      .maybeSingle();

    if (sessionError) throw sessionError;
    if (!session || session.status !== "live") return reply(404, { error: "Este directo ya no está disponible" });

    const isHost = session.host_id === authData.user.id;
    const participantIdentity = authData.user.id;

    if (action === "token") {
      const token = new AccessToken(livekitApiKey, livekitApiSecret, {
        identity: participantIdentity,
        name: "Usuario GOVI",
        ttl: 600,
      });
      token.addGrant({
        roomJoin: true,
        room: session.room_name,
        canSubscribe: true,
        canPublish: isHost,
        canPublishData: true,
        ...(isHost ? { canPublishSources: ["camera", "microphone"] } : {}),
      });
      return reply(200, {
        server_url: livekitUrl,
        token: await token.toJwt(),
        role: isHost ? "host" : "viewer",
      });
    }

    if (action === "obs-ingress") {
      if (!isHost) return reply(403, { error: "Solo el anfitrión puede configurar OBS" });
      if (session.ingress_id) return reply(409, { error: "Esta transmisión ya tiene una clave OBS creada. No generes otra." });

      // LiveKit server SDK management APIs use HTTP(S); client playback uses WS(S).
      const livekitApiHost = livekitUrl.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:");
      const api = new LiveKitAPI({
        host: livekitApiHost,
        apiKey: livekitApiKey,
        secret: livekitApiSecret,
      });
      const ingress = await api.ingress.createIngress(IngressInput.RTMP_INPUT, {
        name: `GOVI LIVE ${session.id}`,
        roomName: session.room_name,
        participantIdentity: `obs-${session.id}`,
        participantName: "GOVI OBS",
        enableTranscoding: true,
      });

      const { error: saveError } = await admin
        .from("govi_live_sessions")
        .update({ ingress_id: ingress.ingressId })
        .eq("id", session.id)
        .eq("host_id", authData.user.id)
        .eq("status", "live");
      if (saveError) {
        try { await api.ingress.deleteIngress(ingress.ingressId); } catch { /* cleanup best effort */ }
        throw saveError;
      }

      return reply(200, {
        ingress_id: ingress.ingressId,
        url: ingress.url,
        stream_key: ingress.streamKey,
        note: "La clave OBS es secreta. No la compartas ni la publiques.",
      });
    }

    return reply(400, { error: "Acción no reconocida" });
  } catch (error) {
    console.error("GOVI LIVE function error:", error);
    return reply(500, { error: "No se pudo completar la operación de GOVI LIVE" });
  }
});
