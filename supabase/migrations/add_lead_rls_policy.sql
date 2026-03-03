-- Activer RLS sur la table leads
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- La Edge Function utilise service_role qui bypass RLS (sécurisé côté serveur)
-- Les utilisateurs authentifiés ne voient que leurs propres leads (multi-tenant ready)
CREATE POLICY "Users see own tenant leads" ON leads
  FOR SELECT
  USING (
    auth.role() = 'authenticated' 
    AND tenant_id = current_setting('app.tenant_id', true)
  );

-- Seul service_role peut insérer (via Edge Function)
-- Aucun accès INSERT direct depuis le frontend
CREATE POLICY "Service role only insert" ON leads
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Appliquer la migration
-- supabase db push
