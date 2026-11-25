const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');
const summitsData = require('./summits_new.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addSummits() {
  console.log(`📦 Afegint ${summitsData.length} cims nous...`);
  const now = new Date().toISOString();
  let uploaded = 0;
  let skipped = 0;

  // Obtenir IDs existents per evitar duplicats
  console.log('🔍 Comprovant cims existents...');
  const existingSnapshot = await db.collection('summits').get();
  const existingIds = new Set(existingSnapshot.docs.map(doc => doc.id));
  console.log(`   Cims existents: ${existingIds.size}`);

  // Filtrar els que ja existeixen
  const newSummits = summitsData.filter(s => {
    if (existingIds.has(s.id)) {
      skipped++;
      return false;
    }
    return true;
  });

  console.log(`   Cims a afegir: ${newSummits.length}`);
  console.log(`   Cims ignorats (ja existeixen): ${skipped}`);
  console.log('');

  // Pujar en grups de 500
  for (let i = 0; i < newSummits.length; i += 500) {
    const chunk = newSummits.slice(i, i + 500);
    const batch = db.batch();

    for (const summit of chunk) {
      const ref = db.collection('summits').doc(summit.id);
      batch.set(ref, {
        name: summit.name,
        latitude: summit.latitude,
        longitude: summit.longitude,
        altitude: summit.altitude,
        province: summit.province || null,
        massif: summit.massif || null,
        description: null,
        createdAt: now,
      });
    }

    await batch.commit();
    uploaded += chunk.length;
    console.log(`  ⬆️  ${uploaded}/${newSummits.length} cims pujats...`);
  }

  console.log('');
  console.log('✅ Importació completada!');
  console.log(`   Cims nous afegits: ${uploaded}`);
  console.log(`   Cims ignorats: ${skipped}`);
  console.log(`   Total cims a Firestore: ${existingIds.size + uploaded}`);
}

async function main() {
  try {
    await addSummits();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
