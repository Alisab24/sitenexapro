<?php
/**
 * BNLsoft — Suivi des activations & révocation à distance (NexaPro)
 * =================================================================
 * À DÉPOSER sur votre site dans  /bnlsoft/activation.php
 * (même dossier que version.json).
 *
 * IMPORTANT : remplacez la valeur de $ADMIN ci-dessous par le contenu
 * EXACT de votre fichier nexapro_maitre.key (une seule ligne).
 * C'est ce secret qui protège la liste et la révocation.
 *
 * Fichiers créés automatiquement à côté du script :
 *   activations.json  — postes ayant activé/utilisé chaque clé
 *   revocations.json  — signatures révoquées (lu par les BNLsoft clients)
 *
 * Actions :
 *   ?action=ping&sig=..&poste=..&org=..&ver=..     (les clients, auto)
 *   ?action=liste&cle=SECRET                        (votre console)
 *   ?action=revoquer&sig=..&cle=SECRET
 *   ?action=retablir&sig=..&cle=SECRET
 */

$ADMIN = 'BNLSOFT-9f4c71e2ab8d4306b5e7d210c3af8854';  // <=== MODIFIEZ ICI AVEC VOTRE CLE PRIVEE

$dir = __DIR__;
$fichier_act = $dir . '/activations.json';
$fichier_rev = $dir . '/revocations.json';
header('Content-Type: application/json; charset=utf-8');

function lire($f) {
    if (!file_exists($f)) return array();
    $d = json_decode(file_get_contents($f), true);
    return is_array($d) ? $d : array();
}
function ecrire($f, $d) {
    file_put_contents($f,
        json_encode($d, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE),
        LOCK_EX);
}

$action = isset($_GET['action']) ? $_GET['action'] : 'ping';

/* ── Ping des clients (aucune authentification, données minimales) ── */
if ($action === 'ping') {
    $sig   = strtoupper(preg_replace('/[^A-F0-9]/i', '',
                        isset($_GET['sig']) ? $_GET['sig'] : ''));
    $poste = strtoupper(preg_replace('/[^A-F0-9]/i', '',
                        isset($_GET['poste']) ? $_GET['poste'] : ''));
    if ($sig !== '' && $poste !== '' && strlen($sig) <= 24
            && strlen($poste) <= 16) {
        $a = lire($fichier_act);
        $k = $sig . '|' . $poste;
        if (!isset($a[$k])) {
            $a[$k] = array('sig' => $sig, 'poste' => $poste,
                           'premiere' => date('Y-m-d'));
        }
        $a[$k]['derniere'] = date('Y-m-d');
        if (isset($_GET['org']))
            $a[$k]['org'] = mb_substr($_GET['org'], 0, 60);
        if (isset($_GET['ver']))
            $a[$k]['ver'] = substr($_GET['ver'], 0, 12);
        ecrire($fichier_act, $a);
    }
    echo json_encode(array('ok' => true));
    exit;
}

/* ── Actions protégées (console NexaPro) ── */
if (!isset($_GET['cle']) || $_GET['cle'] !== $ADMIN) {
    http_response_code(403);
    echo json_encode(array('err' => 'acces refuse'));
    exit;
}

if ($action === 'liste') {
    echo json_encode(array(
        'activations' => array_values(lire($fichier_act)),
        'revoquees'   => lire($fichier_rev),
    ));
    exit;
}

if ($action === 'revoquer' || $action === 'retablir') {
    $sig = strtoupper(preg_replace('/[^A-F0-9]/i', '',
                      isset($_GET['sig']) ? $_GET['sig'] : ''));
    $r = lire($fichier_rev);
    if (!is_array($r)) $r = array();
    if ($action === 'revoquer' && $sig !== '' && !in_array($sig, $r))
        $r[] = $sig;
    if ($action === 'retablir')
        $r = array_values(array_diff($r, array($sig)));
    ecrire($fichier_rev, $r);
    echo json_encode(array('ok' => true, 'revoquees' => $r));
    exit;
}

echo json_encode(array('err' => 'action inconnue'));
