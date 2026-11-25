const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Cim més alt de cada comarca de Catalunya (43 comarques)
const cimComarcaIds = [
  "punta-de-barrina",        // Alt Camp
  "roc-del-comptador-roc-de-france-roc-de-frausa",        // Alt Empordà
  "puig-de-les-agulles-1",     // Alt Penedès
  "pic-de-saloria",          // Alt Urgell
  "pic-de-comaloforno",      // Alta Ribagorça
  "sant-jeroni",             // Anoia
  "sant-jeroni",             // Bages
  "tossal-de-la-baltasana",  // Baix Camp
  "caro",                    // Baix Ebre
  "puig-d-aiguabona-puig-d-aiguaro",        // Baix Empordà
  "l-albarda-castellana",      // Baix Llobregat
  "puig-de-la-talaia-la-talaia-del-montmell",       // Baix Penedès
  "el-tibidabo",                // Barcelonès
  "pic-de-costa-cabirolera-roca-punxenta", // Berguedà
  "puigpedros",              // Cerdanya
  "tossal-de-la-baltasana",  // Conca de Barberà
  "puig-de-la-mola",         // Garraf
  "la-cucurulla",            // Garrigues
  "comanegra",               // Garrotxa
  "puigsou-muntanya-de-rocacorba",          // Gironès
  "puigdon",                 // Lluçanès
  "turo-d-en-vives",          // Maresme
  "serrat-de-sant-joan-1",   // Moianès        (serrat-de-sant-joan si no existeix)
  "tossal-dels-tres-reis-tossal-del-rei",   // Montsià
  "tossal-de-les-torretes",  // Noguera
  "matagalls",               // Osona
  "pic-de-peguera",          // Pallars Jussà
  "pica-d-estats",           // Pallars Sobirà
  "tossal-de-l-infern",      // Pla d'Urgell   (tossal-de-l-infern o pic-de-l-infern)
  "comaestremer",            // Pla de l'Estany
  "roca-corbatera",          // Priorat
  "la-creu-de-santos", // Ribera d'Ebre
  "puigmal-puigmal-d-er",                 // Ripollès
  "turo-del-galutxo",        // Segarra
  "puntal-dels-escabrons",  // Segrià
  "les-agudes",              // Selva
  "pedro-dels-quatre-batlles", // Solsonès
  "la-mola-la-mola-de-sant-llorenc-del-munt",                 // Tarragonès
  "tosseta-rasa",            // Terra Alta
  "tossal-gros-de-vallbona", // Urgell
  "la-mola",                 // Vallès Occidental
  "turo-de-l-home",          // Vallès Oriental
  "tuc-de-molieres",         // Vall d'Aran
];

// IDs únics (alguns cims són el cim de més d'una comarca)
const uniqueIds = [...new Set(cimComarcaIds)];

async function resetAllShowOnMapComarca() {
  console.log('🔄 Posant showOnMapComarca: false a tots els cims...');
  const snapshot = await db.collection('summits').get();
  let count = 0;
  for (let i = 0; i < snapshot.docs.length; i += 500) {
    const chunk = snapshot.docs.slice(i, i + 500);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.update(doc.ref, { showOnMapComarca: false });
    }
    await batch.commit();
    count += chunk.length;
    console.log(`  🔁 ${count}/${snapshot.docs.length} resetejats...`);
  }
  console.log('✅ Tots els cims resetejats a showOnMapComarca: false');
}

async function updateShowOnMapComarca() {
  console.log(`🗺️  Marcant ${uniqueIds.length} cims com showOnMapComarca: true...`);
  const batch = db.batch();
  for (const id of uniqueIds) {
    const ref = db.collection('summits').doc(id);
    batch.set(ref, { showOnMapComarca: true }, { merge: true });
  }
  await batch.commit();
  console.log(`✅ ${uniqueIds.length} cims marcats com showOnMapComarca: true`);

  // Verificar quins IDs no s'han trobat a Firestore
  console.log('\n🔍 Verificant que existeixen a Firestore...');
  let notFound = 0;
  for (const id of uniqueIds) {
    const doc = await db.collection('summits').doc(id).get();
    if (!doc.exists) {
      console.log(`  ⚠️  NO TROBAT: "${id}"`);
      notFound++;
    }
  }
  if (notFound === 0) {
    console.log('  ✅ Tots els cims existeixen a Firestore!');
  } else {
    console.log(`  ❌ ${notFound} cims no trobats. Revisa els IDs marcats amb ⚠️`);
  }
}

async function main() {
  try {
    await resetAllShowOnMapComarca();
    await updateShowOnMapComarca();
    console.log('\n🎉 Actualització completada!');
    console.log(`   Total comarques: 43`);
    console.log(`   Cims únics marcats: ${uniqueIds.length}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
