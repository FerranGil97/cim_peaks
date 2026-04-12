const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');
const summitsData = require('./summits_data.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteAllSummits() {
  console.log('🗑️  Eliminant cims antics...');
  const snapshot = await db.collection('summits').get();
  const batches = [];
  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    count++;
    if (count % 500 === 0) {
      batches.push(batch.commit());
      batch = db.batch();
    }
  }
  if (count % 500 !== 0) {
    batches.push(batch.commit());
  }

  await Promise.all(batches);
  console.log(`✅ ${count} cims antics eliminats`);
}

async function seedSummits() {
  console.log(`📦 Pujant ${summitsData.length} cims nous...`);
  const now = new Date().toISOString();
  let uploaded = 0;

  // Pujar en grups de 500 (límit de Firestore)
  for (let i = 0; i < summitsData.length; i += 500) {
    const chunk = summitsData.slice(i, i + 500);
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
    console.log(`  ⬆️  ${uploaded}/${summitsData.length} cims pujats...`);
  }

  console.log(`✅ Tots els cims pujats correctament!`);
}

async function main() {
  try {
    await deleteAllSummits();
    await seedSummits();
    console.log('\n🎉 Importació completada!');
    console.log(`   Total cims: ${summitsData.length}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
