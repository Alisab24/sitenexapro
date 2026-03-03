import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://nexapro.tech",
  "https://www.nexapro.tech",
];

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) 
    ? origin 
    : ALLOWED_ORIGINS[0],
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-api-key",
  "Content-Type": "application/json",
});

// Anti-spam : rate limiting par IP (in-memory, remplacer par Redis en prod)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const windowMs = 60 * 60 * 1000; // 1 heure
  const maxRequests = 5;

  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= maxRequests) return false;
  entry.count++;
  return true;
}

// Validation stricte des données entrantes
function validatePayload(data: Record<string, unknown>): {
  valid: boolean;
  errors: string[];
  sanitized?: Record<string, unknown>;
} {
  const errors: string[] = [];

  const firstName = String(data.firstName || "").trim();
  const lastName = String(data.lastName || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const company = String(data.company || "").trim();
  const profile = String(data.profile || "").trim();
  const message = String(data.message || "").trim();

  if (!firstName || firstName.length < 2) errors.push("Prénom invalide");
  if (!lastName || lastName.length < 2) errors.push("Nom invalide");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) errors.push("Email invalide");
  if (!company || company.length < 2) errors.push("Entreprise invalide");
  if (!message || message.length < 10) errors.push("Message trop court (min 10 caractères)");

  // Anti-spam honeypot check
  if (data.website) errors.push("Spam détecté");

  // Longueurs maximales
  if (firstName.length > 50) errors.push("Prénom trop long");
  if (lastName.length > 50) errors.push("Nom trop long");
  if (email.length > 100) errors.push("Email trop long");
  if (company.length > 100) errors.push("Entreprise trop longue");
  if (message.length > 2000) errors.push("Message trop long (max 2000 caractères)");

  if (errors.length > 0) return { valid: false, errors };

  return {
    valid: true,
    errors: [],
    sanitized: { firstName, lastName, email, company, profile, message },
  };
}

serve(async (req: Request) => {
  const origin = req.headers.get("origin") || "";

  // Preflight CORS
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Méthode non autorisée" }),
      { status: 405, headers: corsHeaders(origin) }
    );
  }

  // Vérification origin
  if (!ALLOWED_ORIGINS.includes(origin)) {
    return new Response(
      JSON.stringify({ success: false, error: "Origin non autorisée" }),
      { status: 403, headers: corsHeaders(origin) }
    );
  }

  // Vérification API key custom (optionnel mais recommandé)
  const apiKey = req.headers.get("x-api-key");
  if (apiKey !== Deno.env.get("NEXAPRO_API_KEY")) {
    return new Response(
      JSON.stringify({ success: false, error: "Non autorisé" }),
      { status: 401, headers: corsHeaders(origin) }
    );
  }

  // Rate limiting par IP
  const clientIp =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  if (!checkRateLimit(clientIp)) {
    return new Response(
      JSON.stringify({
        success: false,
        error: "Trop de demandes. Réessayez dans 1 heure.",
      }),
      { status: 429, headers: corsHeaders(origin) }
    );
  }

  // Parse body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ success: false, error: "Corps de requête invalide" }),
      { status: 400, headers: corsHeaders(origin) }
    );
  }

  // Validation
  const validation = validatePayload(body);
  if (!validation.valid) {
    return new Response(
      JSON.stringify({ success: false, errors: validation.errors }),
      { status: 422, headers: corsHeaders(origin) }
    );
  }

  const { firstName, lastName, email, company, profile, message } =
    validation.sanitized!;

  // Connexion Supabase avec service_role (côté serveur uniquement)
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  );

  // Vérifier si le lead existe déjà (deduplication par email)
  const { data: existing } = await supabase
    .from("leads")
    .select("id, email")
    .eq("email", email)
    .maybeSingle();

  if (existing) {
    // Lead déjà existant — mettre à jour updated_at sans erreur visible
    await supabase
      .from("leads")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", existing.id);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Demande bien reçue. Nous vous répondons sous 24h.",
      }),
      { status: 200, headers: corsHeaders(origin) }
    );
  }

  // Insertion du nouveau lead avec enrichissement automatique
  const { error: insertError } = await supabase.from("leads").insert({
    // Données du formulaire
    first_name: firstName,
    last_name: lastName,
    name: `${firstName} ${lastName}`,
    email: email,
    company: company,
    profile: profile,
    message: message,

    // Enrichissement automatique NexaPro
    source: "nexapro-website",
    status: "new",
    score: 20,
    priority: "high",

    // Métadonnées
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    ip_address: clientIp,
    tenant_id: "nexapro-default", // Préparation multi-tenant
  });

  if (insertError) {
    console.error("Supabase insert error:", insertError);

    // Si colonne inexistante, adapter les champs selon le schéma réel
    // Logger l'erreur sans l'exposer au client
    return new Response(
      JSON.stringify({
        success: false,
        error: "Erreur serveur. Veuillez réessayer ou nous contacter directement.",
      }),
      { status: 500, headers: corsHeaders(origin) }
    );
  }

  // Succès
  return new Response(
    JSON.stringify({
      success: true,
      message: "Demande bien reçue. Nous vous répondons sous 24h ouvrées.",
    }),
    { status: 201, headers: corsHeaders(origin) }
  );
});
