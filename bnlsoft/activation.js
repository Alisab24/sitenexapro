// BNLsoft — Suivi des activations & révocation à distance (NexaPro)
// =================================================================
// Version VERCEL (le site nexapro.tech étant statique, pas de PHP).
//
// INSTALLATION (une seule fois) :
//  1. Dans le projet Vercel : onglet  Storage → Create Database →
//     Upstash Redis (gratuit) → Connect to Project.
//     (Les variables KV_REST_API_URL / KV_REST_API_TOKEN sont créées
//      automatiquement.)
//  2. Copiez CE fichier dans votre dépôt du site :  api/activation.js
//     (le dossier « api » à la racine, à côté de index.html).
//  3. Poussez / redéployez. Test :
//     https://nexapro.tech/api/activation?action=ping  →  {"ok":true}
//
// Actions :
//   ?action=ping&sig=..&poste=..&org=..&ver=..   (clients, automatique)
//   ?action=revocations                          (clients : clés révoquées)
//   ?action=liste&cle=SECRET                     (console NexaPro)
//   ?action=revoquer&sig=..&cle=SECRET
//   ?action=retablir&sig=..&cle=SECRET

const ADMIN = 'BNLSOFT-9f4c71e2ab8d4306b5e7d210c3af8854'; // = nexapro_console.key

const KV_URL =
  process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
const KV_TOKEN =
  process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;

async function kvGet(key) {
  const r = await fetch(`${KV_URL}/get/${key}`, {
    headers: { Authorization: `Bearer ${KV_TOKEN}` },
  });
  const j = await r.json().catch(() => null);
  if (!j || j.result == null) return null;
  try {
    return JSON.parse(j.result);
  } catch {
    return null;
  }
}

async function kvSet(key, value) {
  await fetch(`${KV_URL}/set/${key}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${KV_TOKEN}` },
    body: JSON.stringify(value),
  });
}

const nettoie = (s, n) =>
  String(s || '')
    .toUpperCase()
    .replace(/[^A-F0-9]/g, '')
    .slice(0, n);

export default async function handler(req, res) {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (!KV_URL || !KV_TOKEN) {
    res.status(500).json({
      err:
        'Base non connectée : Vercel → Storage → Upstash Redis → ' +
        'Connect to Project, puis redéployez.',
    });
    return;
  }
  const q = req.query || {};
  const action = q.action || 'ping';

  // ── Ping des clients (aucune authentification, données minimales) ──
  if (action === 'ping') {
    const sig = nettoie(q.sig, 24);
    const poste = nettoie(q.poste, 16);
    if (sig && poste) {
      const a = (await kvGet('bnl:act')) || {};
      const k = `${sig}|${poste}`;
      const jour = new Date().toISOString().slice(0, 10);
      if (!a[k]) a[k] = { sig, poste, premiere: jour };
      a[k].derniere = jour;
      if (q.org) a[k].org = String(q.org).slice(0, 60);
      if (q.ver) a[k].ver = String(q.ver).slice(0, 12);
      await kvSet('bnl:act', a);
    }
    res.status(200).json({ ok: true });
    return;
  }

  // ── Liste des clés révoquées (publique : lue par les BNLsoft) ──
  if (action === 'revocations') {
    res.status(200).json((await kvGet('bnl:rev')) || []);
    return;
  }

  // ── Actions protégées (console NexaPro) ──
  if (q.cle !== ADMIN) {
    res.status(403).json({ err: 'acces refuse' });
    return;
  }

  if (action === 'liste') {
    const a = (await kvGet('bnl:act')) || {};
    res.status(200).json({
      activations: Object.values(a),
      revoquees: (await kvGet('bnl:rev')) || [],
    });
    return;
  }

  if (action === 'revoquer' || action === 'retablir') {
    const sig = nettoie(q.sig, 24);
    let r = (await kvGet('bnl:rev')) || [];
    if (!Array.isArray(r)) r = [];
    if (action === 'revoquer' && sig && !r.includes(sig)) r.push(sig);
    if (action === 'retablir') r = r.filter((s) => s !== sig);
    await kvSet('bnl:rev', r);
    res.status(200).json({ ok: true, revoquees: r });
    return;
  }

  res.status(200).json({ err: 'action inconnue' });
}
