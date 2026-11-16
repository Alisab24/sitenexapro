import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = ["https://nexapro.dev"];
const MAX_PER_HOUR = 5;

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin)
    ? origin
    : ALLOWED_ORIGINS[0],
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
  "Vary": "Origin",
  "Content-Type": "application/json",
});

function validatePayload(data: Record<string, unknown>) {
  const errors: string[] = [];

  const firstName = String(data.firstName || "").trim();
  const lastName = String(data.lastName || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const company = String(data.company || "").trim();
  const profile = String(data.profile || "").trim().slice(0, 50);
  const message = String(data.message || "").trim();

  if (firstName.length < 2 || firstName.length > 50) errors.push("Prénom invalide");
  if (lastName.length < 2 || lastName.length > 50) errors.push("Nom invalide");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 100) errors.push("Email invalide");
  if (company.length < 2 || company.length > 100) errors.push("Entreprise invalide");
  if (message.length < 10) errors.push("Message trop court (10 caractères minimum)");
  if (message.length > 2000) errors.push("Message trop long (2000 caractères maximum)");

  return { errors, sanitized: { firstName, lastName, email, company, profile, message } };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") || "";
  const headers = corsHeaders(origin);
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), { status, headers });

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return json(405, { success: false, error: "Méthode non autorisée" });
  if (!ALLOWED_ORIGINS.includes(origin)) return json(403, { success: false, error: "Origine non autorisée" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { success: false, error: "Requête invalide" });
  }

  // Honeypot: bots fill the hidden field. Answer as if it worked so they do not adapt.
  if (body.website) return json(200, { success: true });

  const { errors, sanitized } = validatePayload(body);
  if (errors.length > 0) return json(422, { success: false, error: errors.join(". ") });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from("nexapro_contact_messages")
    .select("id", { count: "exact", head: true })
    .eq("ip_address", clientIp)
    .gte("created_at", oneHourAgo);

  if ((count ?? 0) >= MAX_PER_HOUR) {
    return json(429, { success: false, error: "Trop de demandes. Réessayez dans une heure." });
  }

  const { error } = await supabase.from("nexapro_contact_messages").insert({
    first_name: sanitized.firstName,
    last_name: sanitized.lastName,
    email: sanitized.email,
    company: sanitized.company,
    profile: sanitized.profile || null,
    message: sanitized.message,
    ip_address: clientIp,
  });

  if (error) {
    console.error("insert nexapro_contact_messages:", error);
    return json(500, {
      success: false,
      error: "Erreur serveur. Écrivez-nous à contact@nexapro.dev.",
    });
  }

  return json(201, { success: true });
});
