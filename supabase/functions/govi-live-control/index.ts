import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken, IngressInput, LiveKitAPI, EncodedFileOutput, S3Upload, EncodedFileType } from "npm:livekit-server-sdk@2.19.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
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
    const s3AccessKey = Deno.env.get("S3_ACCESS_KEY_ID");
    const s3SecretKey = Deno.env.get("S3_SECRET_ACCESS_KEY");
    const s3Endpoint = Deno.env.get("S3_ENDPOINT") ?? "https://ennfigjdboxpkmfhttze.storage.supabase.co/storage/v1/s3";
    const s3Region = Deno.env.get("S3_REGION") ?? "eu-west-1";
    const recordingsBucket = "govi-live-recordings";

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
    const participantIdentity = authData.user.id;

    if (action === "create-session") {
      const title = String(body?.title || "Directo GOVI").trim().slice(0, 100);
      const description = String(body?.description || "").trim().slice(0, 500);
      const category = String(body?.category || "General").trim().slice(0, 40);
      // The existing database constraint permits only "irl" or "obs".
      const requestedType = String(body?.stream_type || "irl").toLowerCase();
      if (requestedType !== "irl" && requestedType !== "obs") {
        return reply(400, { error: "Tipo de directo no válido. Usa irl u obs." });
      }
      const roomName = "govi-" + authData.user.id + "-" + crypto.randomUUID();
      const { data: created, error: createError } = await admin.from("govi_live_sessions").insert({
        streamer_id: authData.user.id, host_id: authData.user.id, provider_room_id: roomName, room_name: roomName,
        title, description, category, stream_type: requestedType, status: "live", chat_enabled: true, started_at: new Date().toISOString(),
      }).select("id,host_id,room_name,title,description,category,status,started_at").single();
      if (createError) throw createError;
      return reply(200, { session: created });
    }

    if (action === "list-recordings") {
      const { data: rows, error: rowsError } = await admin.from("govi_live_recordings")
        .select("id,session_id,object_path,status,started_at,ended_at,created_at")
        .eq("host_id", authData.user.id).order("created_at", { ascending: false }).limit(50);
      if (rowsError) throw rowsError;
      const recordings = [];
      for (const row of rows ?? []) {
        let downloadUrl = null;
        const signed = await admin.storage.from("govi-live-recordings").createSignedUrl(row.object_path, 3600);
        if (!signed.error && signed.data?.signedUrl) {
          downloadUrl = signed.data.signedUrl;
          if (row.status !== "ready") await admin.from("govi_live_recordings").update({ status: "ready" }).eq("id", row.id);
        }
        recordings.push({ ...row, status: downloadUrl ? "ready" : row.status === "recording" ? "recording" : "processing", download_url: downloadUrl });
      }
      return reply(200, { recordings });
    }
    if (action === "delete-recording") {
      const recordingId = typeof body?.recording_id === "string" ? body.recording_id : "";
      if (!recordingId) return reply(400, { error: "Falta recording_id" });
      const { data: row, error: rowError } = await admin.from("govi_live_recordings").select("id,host_id,bucket,object_path").eq("id", recordingId).maybeSingle();
      if (rowError) throw rowError;
      if (!row || row.host_id !== authData.user.id) return reply(404, { error: "Grabación no encontrada" });
      const { error: removeError } = await admin.storage.from(row.bucket).remove([row.object_path]);
      if (removeError) throw removeError;
      const { error: deleteError } = await admin.from("govi_live_recordings").delete().eq("id", row.id).eq("host_id", authData.user.id);
      if (deleteError) throw deleteError;
      return reply(200, { ok: true });
    }

    if (!sessionId) return reply(400, { error: "Falta session_id" });
    const { data: session, error: sessionError } = await admin.from("govi_live_sessions")
      .select("id, host_id, room_name, title, status, ingress_id").eq("id", sessionId).maybeSingle();
    if (sessionError) throw sessionError;
    if (!session || session.status !== "live") return reply(404, { error: "Este directo ya no está disponible" });
    const isHost = session.host_id === authData.user.id;

    if (action === "start-recording") {
      if (!isHost) return reply(403, { error: "Solo el anfitrión puede iniciar la grabación" });
      if (!s3AccessKey || !s3SecretKey) return reply(503, { error: "Faltan las credenciales S3 en el servidor" });
      const { data: existing } = await admin.from("govi_live_recordings").select("id,egress_id,status,object_path").eq("session_id", session.id).maybeSingle();
      if (existing) return reply(200, { ok: true, egress_id: existing.egress_id, status: existing.status, object_path: existing.object_path });
      const apiHost = livekitUrl.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:");
      const api = new LiveKitAPI({ host: apiHost, apiKey: livekitApiKey, secret: livekitApiSecret });
      const objectPath = `${authData.user.id}/${session.id}/directo.mp4`;
      const output = new EncodedFileOutput({
        fileType: EncodedFileType.MP4,
        filepath: objectPath,
        output: { case: "s3", value: new S3Upload({
          accessKey: s3AccessKey,
          secret: s3SecretKey,
          bucket: recordingsBucket,
          region: s3Region,
          endpoint: s3Endpoint,
          forcePathStyle: true,
        }) },
      });
      const egress = await api.egress.startRoomCompositeEgress(session.room_name, output, { layout: "speaker" });
      const { error: saveRecordingError } = await admin.from("govi_live_recordings").insert({
        session_id: session.id, host_id: authData.user.id, egress_id: egress.egressId,
        bucket: recordingsBucket, object_path: objectPath, status: "recording",
      });
      if (saveRecordingError) {
        try { await api.egress.stopEgress(egress.egressId); } catch { /* best effort */ }
        throw saveRecordingError;
      }
      return reply(200, { ok: true, egress_id: egress.egressId, object_path: objectPath, status: "recording" });
    }

    if (action === "end-session") {
      if (!isHost) return reply(403, { error: "Solo el anfitrión puede finalizar este directo" });
      const apiHost = livekitUrl.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:");
      const api = new LiveKitAPI({ host: apiHost, apiKey: livekitApiKey, secret: livekitApiSecret });
      if (session.ingress_id) {
        try { await api.ingress.deleteIngress(session.ingress_id); } catch (cleanupError) { console.warn("No se pudo eliminar ingress OBS:", cleanupError); }
      }
      const { data: recording } = await admin.from("govi_live_recordings").select("id,egress_id").eq("session_id", session.id).maybeSingle();
      if (recording?.egress_id) {
        try {
          await api.egress.stopEgress(recording.egress_id);
          await admin.from("govi_live_recordings").update({ status: "processing", ended_at: new Date().toISOString() }).eq("id", recording.id);
        } catch (recordingError) {
          console.warn("No se pudo detener la grabación GOVI LIVE:", recordingError);
          await admin.from("govi_live_recordings").update({ status: "failed", ended_at: new Date().toISOString() }).eq("id", recording.id);
        }
      }
      const { error: endError } = await admin.from("govi_live_sessions").update({ status: "ended", ended_at: new Date().toISOString() })
        .eq("id", session.id).eq("host_id", authData.user.id).eq("status", "live");
      if (endError) throw endError;
      return reply(200, { ok: true });
    }

    const profileName = String(authData.user.user_metadata?.full_name || authData.user.user_metadata?.name || "Usuario GOVI").slice(0, 80);
    if (action === "token") {
      const token = new AccessToken(livekitApiKey, livekitApiSecret, {
        identity: participantIdentity,
        name: profileName,
        ttl: 600,
      });
      token.addGrant({
        roomJoin: true,
        room: session.room_name,
        canSubscribe: true,
        canPublish: isHost,
        canPublishData: true,
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
