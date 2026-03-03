# 1. Installer Supabase CLI si pas présent
npm install -g supabase

# 2. Login Supabase
supabase login

# 3. Lier au projet LeadQualif
supabase link --project-ref [TON-PROJECT-REF]

# 4. Configurer les secrets en production
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=[ta-clé]
supabase secrets set NEXAPRO_API_KEY=[ta-clé-api]

# 5. Déployer la Edge Function
supabase functions deploy add-lead --no-verify-jwt

# 6. Vérifier le déploiement
supabase functions list

# 7. Tester en local avant déploiement
supabase functions serve add-lead --env-file ./supabase/functions/add-lead/.env.local

# 8. Test curl rapide
curl -i --location --request POST \
  'http://localhost:54321/functions/v1/add-lead' \
  --header 'Content-Type: application/json' \
  --header 'x-api-key: [NEXAPRO_API_KEY]' \
  --header 'Origin: https://nexapro.tech' \
  --data '{
    "firstName": "Jean",
    "lastName": "Test",
    "email": "jean@test.com",
    "company": "TestCorp",
    "profile": "CEO",
    "message": "Ceci est un test de formulaire NexaPro."
  }'
