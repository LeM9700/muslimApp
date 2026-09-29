// Remplit Firestore (hadiths + quiz_questions) depuis assets/data/*.json
// avec le SDK Admin, qui ignore les règles de sécurité (écriture interdite
// côté app). Même format que lib/services/firebase_data_seeder.dart.
//
// Usage (depuis ce dossier) :
//   npm install
//   node seed.mjs              → simulation, n'écrit rien
//   node seed.mjs --write      → écrit dans Firestore
//
// Authentification : service-account.json dans ce dossier (ignoré par git),
// ou la variable GOOGLE_APPLICATION_CREDENTIALS.

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const dataDir = join(here, '..', '..', 'assets', 'data');
const write = process.argv.includes('--write');

const keyPath = join(here, 'service-account.json');
const credential = existsSync(keyPath)
  ? cert(JSON.parse(readFileSync(keyPath, 'utf8')))
  : applicationDefault();

initializeApp({ credential });
const db = getFirestore();

const readJson = (name) => JSON.parse(readFileSync(join(dataDir, name), 'utf8'));

function hadithDocs() {
  return readJson('nawawi_hadiths_fr.json').map((h) => {
    const id = `nawawi_${h.number}`;
    return [id, {
      id,
      text: `${h.textArabic}\n\n${h.textFrench}`,
      source: `${h.source} — Rapporté par ${h.narrator}`,
      number: String(h.number),
      theme: h.theme ?? '',
      title: h.title ?? '',
      reviewed: true,
      createdAt: FieldValue.serverTimestamp(),
    }];
  });
}

function quizDocs() {
  return readJson('quizzes.json').map((q, i) => {
    const id = `quiz_${i + 1}`;
    return [id, {
      id,
      question: q.question,
      options: q.options,
      correctIndex: q.correctIndex,
      difficulty: q.difficulty ?? 'novice',
      points: q.points ?? 1,
      explanation: q.explanation ?? '',
      tags: q.tags ?? [],
      language: q.language ?? 'fr',
      reviewed: true, // validé pour usage immédiat, comme le seeder de l'app
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }];
  });
}

async function seed(collection, docs) {
  if (!write) {
    console.log(`[simulation] ${collection}: ${docs.length} documents (ex: ${docs[0][0]})`);
    return;
  }
  // 450 par batch (limite Firestore : 500 écritures)
  for (let start = 0; start < docs.length; start += 450) {
    const batch = db.batch();
    for (const [id, data] of docs.slice(start, start + 450)) {
      batch.set(db.collection(collection).doc(id), data); // idempotent : écrase par id
    }
    await batch.commit();
  }
  console.log(`✅ ${collection}: ${docs.length} documents écrits`);
}

await seed('hadiths', hadithDocs());
await seed('quiz_questions', quizDocs());
if (!write) console.log('\nRien n\'a été écrit. Relance avec --write pour remplir Firestore.');
