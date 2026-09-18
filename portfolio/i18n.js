const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Upgradeable Proxies UUPS + Transparent — Rolando Strahm',
    'meta.description':
      'Proxies upgradeables EIP-1967 (UUPS y Transparent), optimización de gas y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 11 · PORTFOLIO WEB3',
    'hero.title': 'UPGRADEABLE<br>PROXIES',
    'hero.role': 'UUPS · Transparent · EIP-1967 · Foundry',
    'hero.sub':
      'Proxies upgradeables con storage seguro, control de upgrades, optimización de gas documentada y auditoría defensiva SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'En producción casi nadie redeploya desde cero: se <strong>upgradear</strong>. Este módulo implementa UUPS y Transparent (EIP-1967) con Foundry para entender <strong>dónde vive el estado</strong>, quién puede cambiar la lógica y cómo no romper el storage — cerrando con <strong>gas</strong> y <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'UUPS + Transparent',
    'p1.desc':
      'ERC-1967 con delegatecall, ProxyAdmin Ownable2Step, Initializable y Box V1→V2 con __gap.',
    'p1.l1': 'Slots EIP-1967 de impl / admin',
    'p1.l2': 'Clash admin vs usuario resuelto',
    'p1.l3': 'proxiableUUID (ERC-1822)',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Hot path del fallback sin SLOAD de admin ni extcodesize; slots precomputados y upgrades en calldata.',
    'p2.l1': 'Admin immutable (Transparent)',
    'p2.l2': 'Sin extcodesize en cada call',
    'p2.l3': 'Gas report + snapshot Foundry',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136 con foco en delegatecall (SWC-112), auth de upgrades y layout de storage.',
    'p3.l1': '31 mitigados / N/A · 5 informativos',
    'p3.l2': '0 vulnerabilidades explotables',
    'p3.l3': 'Attack + fuzz 1000 runs',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, seguridad intacta',
    'gas.lead':
      'Fase 6: cada optimización está en <code>doc/GAS.md</code> con su <strong>tradeoff</strong>. Priorizamos el <strong>fallback</strong> (cada call de usuario) sobre el coste de deploy: admin immutable, sin <code>extcodesize</code> por llamada y slots EIP-1967 precomputados.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'Admin immutable (TransparentProxy)',
    'gas.r1b': 'Sin SLOAD de admin en cada call de usuario (~−2.5k en path típico)',
    'gas.r2a': 'Sin extcodesize en hot path del fallback',
    'gas.r2b': 'Validación de código solo al setear la implementación',
    'gas.r3a': 'Slots EIP-1967 precomputados (constants)',
    'gas.r3b': 'Sin keccak256 en runtime al leer/escribir el slot',
    'gas.r4a': 'delegatecall en assembly (_delegate / _delegateCall)',
    'gas.r4b': 'Menos overhead que high-level + manejo compacto de returndata',
    'gas.r5a': 'bytes calldata en upgradeToAndCall / ProxyAdmin',
    'gas.r5b': 'Evita copiar el payload de migración a memory',
    'gas.r6a': 'Sin changeAdmin on-proxy (rotar via Ownable2Step)',
    'gas.r6b': 'Bytecode más chico; mismo modelo que OZ v5 Transparent',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo del fallback; deploy un poco más caro',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra proxies EIP-1967, UUPS, Transparent y Box. Informe en <code>doc/SWC-AUDIT.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong>; el <code>delegatecall</code> (SWC-112) es intencional y está acotado.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'delegatecall chequea success; bubble returndata o DelegateCallFailed',
    'swc.r112': 'delegatecall solo a impl del slot EIP-1967 + auth + proxiableUUID',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / attack',
    'swc.r124': 'Assembly solo en slots EIP-1967; negocio tipado + __gap',
    'swc.r115': 'Auth por msg.sender (owner / ProxyAdmin), sin tx.origin',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'delegatecall (diseño)',
    'swc.i1d':
      'El patrón proxy depende de delegatecall. Mitigado con slots EIP-1967, validación de código, auth de upgrade y _disableInitializers.',
    'swc.i2t': 'Front-run de upgrade',
    'swc.i2d':
      'upgradeToAndCall en mempool puede competir. Mitigación operativa: multisig, private relay o Timelock (fuera de v1).',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–6 cerradas',
    'pr.lead':
      'Desarrollo por gates: setup Foundry, ERC-1967, Transparent, UUPS, Box+gaps, suite e2e/fuzz/attack y deploy + gas.',
    'ph.0': 'Bootstrap Foundry',
    'ph.12': 'ERC-1967 + Transparent',
    'ph.34': 'UUPS + Box V1/V2',
    'ph.5': 'E2E · fuzz · attack · SWC',
    'ph.6': 'Deploy + gas opts',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/11-upgradeable-proxies',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 60 passed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 5 · Mitigados/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_11_CLOSED · GAS_OPTS_APPLIED',

    'at.eyebrow': '// 06 — CAMPAÑAS DE ATAQUE',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'Suite test/attack y fuzz: el “éxito” del ataque es que revierta. Sin PoCs de exploit — unauthorized upgrade, double init, non-UUPS e integridad de storage.',
    'cA.t': 'Unauthorized',
    'cA.d': 'Stranger / non-owner no puede upgradeToAndCall.',
    'cB.t': 'Double init',
    'cB.d': 'AlreadyInitialized en proxy e implementación.',
    'cC.t': 'Non-UUPS',
    'cC.d': 'Impl sin proxiableUUID → InvalidImplementation.',
    'cD.t': 'Clash',
    'cD.d': 'Admin no ejecuta lógica usuario; usuario no escribe slot.',
    'cE.t': 'Storage',
    'cE.d': 'Fuzz pre/post upgrade: slots 0/1 intactos.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'El mismo código está en GitHub y GitLab: proxies, tests, gas, auditoría SWC y diagramas.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Upgradeable Proxies · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Upgradeable Proxies UUPS + Transparent — Rolando Strahm',
    'meta.description':
      'EIP-1967 upgradeable proxies (UUPS and Transparent), gas optimization, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 11 · WEB3 PORTFOLIO',
    'hero.title': 'UPGRADEABLE<br>PROXIES',
    'hero.role': 'UUPS · Transparent · EIP-1967 · Foundry',
    'hero.sub':
      'Upgradeable proxies with safe storage, upgrade access control, documented gas optimization, and defensive SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'In production almost nobody redeploys from scratch — they <strong>upgrade</strong>. This module implements UUPS and Transparent (EIP-1967) with Foundry to understand <strong>where state lives</strong>, who can change logic, and how not to break storage — closing with <strong>gas</strong> and <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module delivers',
    'p1.num': '// PILLAR_01',
    'p1.title': 'UUPS + Transparent',
    'p1.desc':
      'EIP-1967 with delegatecall, Ownable2Step ProxyAdmin, Initializable, and Box V1→V2 with __gap.',
    'p1.l1': 'EIP-1967 impl / admin slots',
    'p1.l2': 'Admin vs user clash resolved',
    'p1.l3': 'proxiableUUID (ERC-1822)',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Fallback hot path without admin SLOAD or extcodesize; precomputed slots and calldata upgrades.',
    'p2.l1': 'Immutable admin (Transparent)',
    'p2.l2': 'No extcodesize on every call',
    'p2.l3': 'Foundry gas report + snapshot',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix focused on delegatecall (SWC-112), upgrade auth, and storage layout.',
    'p3.l1': '31 mitigated / N/A · 5 informational',
    'p3.l2': '0 exploitable vulnerabilities',
    'p3.l3': 'Attack suite + fuzz 1000 runs',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, security intact',
    'gas.lead':
      'Phase 6: every optimization is in <code>doc/GAS.md</code> with its <strong>tradeoff</strong>. We prioritize the <strong>fallback</strong> (every user call) over deploy cost: immutable admin, no per-call <code>extcodesize</code>, and precomputed EIP-1967 slots.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'Immutable admin (TransparentProxy)',
    'gas.r1b': 'No admin SLOAD on every user call (~−2.5k on typical path)',
    'gas.r2a': 'No extcodesize on fallback hot path',
    'gas.r2b': 'Code validation only when setting the implementation',
    'gas.r3a': 'Precomputed EIP-1967 slots (constants)',
    'gas.r3b': 'No runtime keccak256 when reading/writing the slot',
    'gas.r4a': 'delegatecall in assembly (_delegate / _delegateCall)',
    'gas.r4b': 'Less overhead than high-level + compact returndata handling',
    'gas.r5a': 'bytes calldata in upgradeToAndCall / ProxyAdmin',
    'gas.r5b': 'Avoids copying migration payload to memory',
    'gas.r6a': 'No on-proxy changeAdmin (rotate via Ownable2Step)',
    'gas.r6b': 'Smaller bytecode; same model as OZ v5 Transparent',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive fallback inlining; slightly costlier deploy',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full <strong>SWC-100 → SWC-136</strong> matrix against EIP-1967 proxies, UUPS, Transparent, and Box. Report in <code>doc/SWC-AUDIT.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong>; <code>delegatecall</code> (SWC-112) is intentional and constrained.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'delegatecall checks success; bubble returndata or DelegateCallFailed',
    'swc.r112': 'delegatecall only to EIP-1967 impl slot + auth + proxiableUUID',
    'swc.r123': 'Custom errors + unit / e2e / fuzz / attack',
    'swc.r124': 'Assembly only on EIP-1967 slots; typed business layout + __gap',
    'swc.r115': 'Auth via msg.sender (owner / ProxyAdmin), no tx.origin',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'delegatecall (by design)',
    'swc.i1d':
      'The proxy pattern depends on delegatecall. Mitigated with EIP-1967 slots, code validation, upgrade auth, and _disableInitializers.',
    'swc.i2t': 'Upgrade front-running',
    'swc.i2d':
      'upgradeToAndCall in the mempool can race. Operational mitigation: multisig, private relay, or Timelock (out of v1).',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–6 closed',
    'pr.lead':
      'Gated development: Foundry setup, EIP-1967, Transparent, UUPS, Box+gaps, e2e/fuzz/attack suite, then deploy + gas.',
    'ph.0': 'Foundry bootstrap',
    'ph.12': 'EIP-1967 + Transparent',
    'ph.34': 'UUPS + Box V1/V2',
    'ph.5': 'E2E · fuzz · attack · SWC',
    'ph.6': 'Deploy + gas opts',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWC',
    'st.4': 'Fuzz runs',
    'term.label': 'rolando@strahm:~/11-upgradeable-proxies',
    'term.1': 'forge test --summary',
    'term.2': '[PASS] suite · 60 passed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 5 · Mitigated/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_11_CLOSED · GAS_OPTS_APPLIED',

    'at.eyebrow': '// 06 — ATTACK CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'test/attack and fuzz suites: a successful “attack” means it reverts. No exploit PoCs — unauthorized upgrade, double init, non-UUPS, and storage integrity.',
    'cA.t': 'Unauthorized',
    'cA.d': 'Stranger / non-owner cannot upgradeToAndCall.',
    'cB.t': 'Double init',
    'cB.d': 'AlreadyInitialized on proxy and implementation.',
    'cC.t': 'Non-UUPS',
    'cC.d': 'Impl without proxiableUUID → InvalidImplementation.',
    'cD.t': 'Clash',
    'cD.d': 'Admin cannot run user logic; user cannot write the slot.',
    'cE.t': 'Storage',
    'cE.d': 'Fuzz pre/post upgrade: slots 0/1 intact.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'The same codebase is on GitHub and GitLab: proxies, tests, gas, SWC audit, and diagrams.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Upgradeable Proxies · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('proxies-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('proxies-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
