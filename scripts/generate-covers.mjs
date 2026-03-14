#!/usr/bin/env node
/**
 * Générateur de pages de couverture — Quiz Buzzer
 * Utilise Puppeteer pour rendre des pages HTML en PNG.
 * Charte graphique : vert forestier + motifs triangulaires.
 *
 * Usage : node scripts/generate-covers.mjs
 */

import { createRequire } from 'module';
import { accessSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

// Résolution de puppeteer depuis le node_modules local ou global
let puppeteerPath;
try {
  // Tenter d'abord une résolution locale (node_modules du projet)
  puppeteerPath = join(ROOT, 'node_modules/puppeteer/lib/esm/puppeteer/puppeteer.js');
  accessSync(puppeteerPath);
} catch {
  // Fallback : résolution depuis @mermaid-js/mermaid-cli installé globalement
  const { execSync } = await import('child_process');
  puppeteerPath = join(
    execSync('npm root -g').toString().trim(),
    '@mermaid-js/mermaid-cli/node_modules/puppeteer/lib/esm/puppeteer/puppeteer.js'
  );
}
const { default: puppeteer } = await import(puppeteerPath);

// ---------------------------------------------------------------------------
// Données des US
// ---------------------------------------------------------------------------
const US_LIST = [
  {
    num: '001',
    title: 'Démarrage du serveur\nQuiz Buzzer',
    subtitle: 'Startup',
  },
  {
    num: '002',
    title: 'Seed des comptes\nutilisateurs',
    subtitle: 'Seed Users',
  },
  {
    num: '003',
    title: 'Authentification et\némission du token JWT',
    subtitle: 'Authentication',
  },
  {
    num: '004',
    title: 'CRUD des thèmes\nde questions',
    subtitle: 'Themes CRUD',
  },
  {
    num: '005',
    title: 'CRUD de base\ndes questions',
    subtitle: 'Questions CRUD',
  },
  {
    num: '006',
    title: 'Filtrage avancé\ndes questions',
    subtitle: 'Questions Filter',
  },
  {
    num: '007',
    title: 'Modification partielle\ndes questions (PATCH)',
    subtitle: 'Questions PATCH',
  },
  {
    num: '008',
    title: 'CRUD des quiz',
    subtitle: 'Quizzes CRUD',
  },
  {
    num: '009',
    title: 'Connexion WebSocket\ndes buzzers et d\'Angular',
    subtitle: 'WebSocket',
  },
];

// ---------------------------------------------------------------------------
// Génération du motif triangulaire (tessellation équilatérale)
// ---------------------------------------------------------------------------
function generateTrianglePattern(width, height) {
  const W = 90;                              // base du triangle
  const H = Math.round(W * Math.sqrt(3) / 2); // hauteur ≈ 78px

  // Palette de verts forestiers
  const palette = [
    '#1a472a', // vert très sombre
    '#1b4332', // vert sombre variante
    '#2d6a4f', // vert sombre moyen
    '#236440', // vert moyen-sombre
    '#1e5631', // vert foncé variante
    '#2a5f45', // vert medium
  ];

  const cols = Math.ceil(width  / (W / 2)) + 3;
  const rows = Math.ceil(height / H)       + 3;

  const polygons = [];

  for (let row = -1; row < rows; row++) {
    for (let col = -1; col < cols; col++) {
      const x = col * (W / 2);
      const y = row * H;

      let points;
      if ((col + row) % 2 === 0) {
        // Triangle pointant vers le haut
        points = `${x},${y + H} ${x + W},${y + H} ${x + W / 2},${y}`;
      } else {
        // Triangle pointant vers le bas
        points = `${x},${y} ${x + W},${y} ${x + W / 2},${y + H}`;
      }

      // Sélection déterministe de la couleur (pseudo-aléatoire par position)
      const idx = Math.abs((col * 3 + row * 7) * 17 + col - row * 2) % palette.length;
      polygons.push(`<polygon points="${points}" fill="${palette[idx]}" />`);
    }
  }

  return polygons.join('\n    ');
}

// ---------------------------------------------------------------------------
// Génération du HTML de la couverture
// ---------------------------------------------------------------------------
function generateCoverHtml(num, title, subtitle) {
  const W = 1200;
  const H = 480;
  const triangles = generateTrianglePattern(W, H);

  // Conversion des sauts de ligne en spans HTML
  const titleHtml = title
    .split('\n')
    .map(line => `<span class="title-line">${line}</span>`)
    .join('');

  // Taille de police adaptée selon la longueur du titre
  const maxLineLen = Math.max(...title.split('\n').map(l => l.length));
  const fontSize = maxLineLen > 30 ? 44 : maxLineLen > 20 ? 52 : 58;

  return /* html */`<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    html, body {
      width: ${W}px;
      height: ${H}px;
      overflow: hidden;
    }

    .cover {
      position: relative;
      width: ${W}px;
      height: ${H}px;
      background: #1a472a;
      font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
    }

    /* Motif de triangles en arrière-plan */
    .bg-triangles {
      position: absolute;
      top: 0; left: 0;
      width: 100%; height: 100%;
    }

    /* Dégradé pour assombrir le motif et garantir la lisibilité */
    .overlay {
      position: absolute;
      top: 0; left: 0;
      width: 100%; height: 100%;
      background: linear-gradient(
        160deg,
        rgba(26, 71, 42, 0.72) 0%,
        rgba(26, 71, 42, 0.45) 40%,
        rgba(26, 71, 42, 0.72) 100%
      );
    }

    /* Contenu centré */
    .content {
      position: relative;
      z-index: 10;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100%;
      padding: 48px 80px;
      text-align: center;
      gap: 0;
    }

    /* Badge "USER STORY — US-XXX" */
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: rgba(64, 145, 108, 0.35);
      border: 1.5px solid #52b788;
      color: #b7e4c7;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 5px;
      text-transform: uppercase;
      padding: 7px 22px;
      border-radius: 3px;
      margin-bottom: 28px;
    }

    /* Triangle décoratif dans le badge */
    .badge-tri {
      display: inline-block;
      width: 0; height: 0;
      border-left: 5px solid transparent;
      border-right: 5px solid transparent;
      border-bottom: 9px solid #52b788;
    }

    /* Titre de l'US */
    .title {
      font-size: ${fontSize}px;
      font-weight: 700;
      color: #ffffff;
      line-height: 1.3;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-shadow: 0 2px 16px rgba(0, 0, 0, 0.6);
      margin-bottom: 28px;
    }

    .title-line {
      display: block;
    }

    /* Séparateur triangulaire */
    .divider {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 24px;
    }

    .divider-line {
      width: 50px;
      height: 2px;
      background: linear-gradient(90deg, transparent, #52b788);
    }

    .divider-line.right {
      background: linear-gradient(90deg, #52b788, transparent);
    }

    .divider-tri {
      width: 0; height: 0;
      border-left: 9px solid transparent;
      border-right: 9px solid transparent;
      border-bottom: 16px solid #52b788;
    }

    /* Nom du projet */
    .project {
      font-size: 15px;
      color: #95d5b2;
      letter-spacing: 5px;
      text-transform: uppercase;
      font-weight: 500;
    }

    /* Barre verte en bas avec motif de petits triangles */
    .bottom-bar {
      position: absolute;
      bottom: 0; left: 0; right: 0;
      height: 7px;
      background: linear-gradient(
        90deg,
        #2d6a4f, #40916c, #52b788, #74c69d,
        #52b788, #40916c, #2d6a4f
      );
    }

    /* Lignes décoratives sur les côtés */
    .side-accent {
      position: absolute;
      top: 0; bottom: 0;
      width: 4px;
    }

    .side-accent.left  { left: 0;  background: linear-gradient(180deg, #40916c, #2d6a4f, #40916c); }
    .side-accent.right { right: 0; background: linear-gradient(180deg, #40916c, #2d6a4f, #40916c); }

    /* Grand triangle décoratif en coin supérieur droit */
    .corner-tri-tr {
      position: absolute;
      top: 0; right: 0;
      width: 0; height: 0;
      border-top: 160px solid rgba(64, 145, 108, 0.18);
      border-left: 160px solid transparent;
    }

    /* Grand triangle décoratif en coin inférieur gauche */
    .corner-tri-bl {
      position: absolute;
      bottom: 0; left: 0;
      width: 0; height: 0;
      border-bottom: 120px solid rgba(64, 145, 108, 0.18);
      border-right: 120px solid transparent;
    }
  </style>
</head>
<body>
  <div class="cover">
    <!-- Motif triangulaire en arrière-plan -->
    <svg class="bg-triangles" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
      ${triangles}
    </svg>

    <!-- Dégradé de lisibilité -->
    <div class="overlay"></div>

    <!-- Triangles décoratifs en coins -->
    <div class="corner-tri-tr"></div>
    <div class="corner-tri-bl"></div>

    <!-- Accents latéraux -->
    <div class="side-accent left"></div>
    <div class="side-accent right"></div>

    <!-- Contenu principal -->
    <div class="content">
      <div class="badge">
        <span class="badge-tri"></span>
        User Story — US-${num}
        <span class="badge-tri"></span>
      </div>
      <div class="title">${titleHtml}</div>
      <div class="divider">
        <div class="divider-line"></div>
        <div class="divider-tri"></div>
        <div class="divider-line right"></div>
      </div>
      <div class="project">Quiz Buzzer</div>
    </div>

    <!-- Barre de bas de page -->
    <div class="bottom-bar"></div>
  </div>
</body>
</html>`;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const outDir = join(ROOT, 'diagrams', 'covers');
  mkdirSync(outDir, { recursive: true });

  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  for (const { num, title, subtitle } of US_LIST) {
    const page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 480, deviceScaleFactor: 2 });

    const html = generateCoverHtml(num, title, subtitle);
    await page.setContent(html, { waitUntil: 'networkidle0' });

    const outputPath = join(outDir, `US-${num}-cover.png`);
    await page.screenshot({ path: outputPath, type: 'png' });
    await page.close();

    console.log(`✅ Couverture générée : ${outputPath}`);
  }

  await browser.close();
  console.log('\n🎉 Toutes les couvertures ont été générées dans diagrams/covers/');
}

main().catch(err => {
  console.error('❌ Erreur :', err);
  process.exit(1);
});
