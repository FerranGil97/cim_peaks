const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const summits = [

  { id: 'pica-destats', name: 'Pica d\'Estats', altitude: 3143, latitude: 42.6711, longitude: 1.3975, province: 'Lleida', massif: 'Pirineu', description: 'Punt més alt de Catalunya' },
  { id: 'puigmal', name: 'Puigmal', altitude: 2909, latitude: 42.3833, longitude: 2.1167, province: 'Girona', massif: 'Pirineu', description: 'Cim fronterer amb França' },
  { id: 'bastiments', name: 'Bastiments', altitude: 2881, latitude: 42.4167, longitude: 2.2333, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
  { id: 'canigou', name: 'Canigó', altitude: 2784, latitude: 42.5196, longitude: 2.4567, province: 'Girona', massif: 'Pirineu', description: 'Símbol de Catalunya Nord' },
  { id: 'pic-de-la-vaca', name: 'Pic de la Vaca', altitude: 2824, latitude: 42.5833, longitude: 1.5167, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Vall d\'Aran' },
  { id: 'montcalm', name: 'Montcalm', altitude: 3077, latitude: 42.6636, longitude: 1.4058, province: 'Lleida', massif: 'Pirineu', description: 'Segon pic més alt de Catalunya' },
  { id: 'pic-de-comapedrosa', name: 'Pic de Comapedrosa', altitude: 2942, latitude: 42.5667, longitude: 1.4333, province: 'Lleida', massif: 'Pirineu', description: 'Cim fronterer amb Andorra' },
  { id: 'pic-de-certascan', name: 'Pic de Certascan', altitude: 2853, latitude: 42.6500, longitude: 1.3167, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Sobirà' },
  { id: 'pic-de-sotllo', name: 'Pic de Sotllo', altitude: 2886, latitude: 42.6333, longitude: 1.2833, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Sobirà' },
  { id: 'pic-de-baiau', name: 'Pic de Baiau', altitude: 2756, latitude: 42.5833, longitude: 1.7167, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Alt Urgell' },

  // 2000-3000m
  { id: 'pedraforca', name: 'Pedraforca', altitude: 2506, latitude: 42.2397, longitude: 1.7025, province: 'Berguedà', massif: 'Prepirineu', description: 'Cim emblemàtic del Berguedà' },
  { id: 'port-del-comte', name: 'Port del Comte', altitude: 2466, latitude: 42.0833, longitude: 1.5833, province: 'Lleida', massif: 'Prepirineu', description: 'Cim del Solsonès' },
  { id: 'tosa-d-alp', name: 'Tosa d\'Alp', altitude: 2531, latitude: 42.3167, longitude: 1.9833, province: 'Girona', massif: 'Prepirineu', description: 'Cim de la Cerdanya' },
  { id: 'pic-de-l-infern', name: 'Pic de l\'Infern', altitude: 2859, latitude: 42.4500, longitude: 2.0500, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
  { id: 'gra-de-fajol', name: 'Gra de Fajol', altitude: 2714, latitude: 42.3667, longitude: 2.2167, province: 'Girona', massif: 'Pirineu', description: 'Cim de la Garrotxa' },
  { id: 'pic-de-noufonts', name: 'Pic de Noufonts', altitude: 2861, latitude: 42.4000, longitude: 2.1500, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
  { id: 'sant-amand', name: 'Sant Amand', altitude: 2425, latitude: 42.1500, longitude: 1.6333, province: 'Lleida', massif: 'Prepirineu', description: 'Cim del Alt Urgell' },
  { id: 'comanegra', name: 'Comanegra', altitude: 1714, latitude: 42.2000, longitude: 2.5833, province: 'Girona', massif: 'Garrotxa', description: 'Cim de les Guilleries' },
  { id: 'pic-de-finestrelles', name: 'Pic de Finestrelles', altitude: 2826, latitude: 42.4333, longitude: 2.1000, province: 'Girona', massif: 'Pirineu', description: 'Cim fronterer amb França' },
  { id: 'puig-de-la-canal-baridana', name: 'Puig de la Canal Baridana', altitude: 2647, latitude: 42.4167, longitude: 1.7500, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Jussà' },

  // Prepirineu i Serres
  { id: 'montseny', name: 'Turó de l\'Home', altitude: 1706, latitude: 41.7697, longitude: 2.4411, province: 'Girona', massif: 'Montseny', description: 'Punt més alt del Montseny' },
  { id: 'matagalls', name: 'Matagalls', altitude: 1697, latitude: 41.8167, longitude: 2.4333, province: 'Barcelona', massif: 'Montseny', description: 'Segon cim del Montseny' },
  { id: 'sant-llorenç-del-munt', name: 'Sant Llorenç del Munt', altitude: 1104, latitude: 41.6333, longitude: 1.9500, province: 'Barcelona', massif: 'Sant Llorenç del Munt', description: 'Cim emblemàtic del Vallès' },
  { id: 'mont-caro', name: 'Mont Caro', altitude: 1441, latitude: 40.8833, longitude: 0.3500, province: 'Tarragona', massif: 'Ports', description: 'Punt més alt dels Ports de Tortosa' },
  { id: 'prades', name: 'Tossal de la Baltasana', altitude: 1202, latitude: 41.3333, longitude: 1.0167, province: 'Tarragona', massif: 'Prades', description: 'Punt més alt de les Muntanyes de Prades' },
  { id: 'montsant', name: 'Montsant', altitude: 1163, latitude: 41.2833, longitude: 0.8500, province: 'Tarragona', massif: 'Montsant', description: 'Cim de la Serra del Montsant' },
  { id: 'montserrat', name: 'Sant Jeroni', altitude: 1236, latitude: 41.5939, longitude: 1.8333, province: 'Barcelona', massif: 'Montserrat', description: 'Punt més alt de Montserrat' },
  { id: 'cavall-bernat', name: 'Cavall Bernat', altitude: 1099, latitude: 41.6000, longitude: 1.8167, province: 'Barcelona', massif: 'Montserrat', description: 'Agulla emblemàtica de Montserrat' },
  { id: 'puig-de-la-force', name: 'Puig de la Force', altitude: 2092, latitude: 42.2167, longitude: 2.4500, province: 'Girona', massif: 'Alta Garrotxa', description: 'Cim de l\'Alta Garrotxa' },
  { id: 'pic-de-bassegoda', name: 'Pic de Bassegoda', altitude: 1373, latitude: 42.2833, longitude: 2.5667, province: 'Girona', massif: 'Alta Garrotxa', description: 'Cim de l\'Alta Garrotxa' },

  // Més cims del Pirineu
  { id: 'pic-de-saloria', name: 'Pic de Salòria', altitude: 2789, latitude: 42.5500, longitude: 1.5667, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Alt Urgell' },
  { id: 'pic-negre-de-juclar', name: 'Pic Negre de Juclar', altitude: 2724, latitude: 42.5667, longitude: 1.6500, province: 'Lleida', massif: 'Pirineu', description: 'Cim fronterer amb Andorra' },
  { id: 'pic-de-la-cabaneta', name: 'Pic de la Cabaneta', altitude: 2755, latitude: 42.5333, longitude: 1.6000, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Alt Urgell' },
  { id: 'pic-de-coma-pedrosa', name: 'Pic de Coma Pedrosa', altitude: 2942, latitude: 42.5667, longitude: 1.4333, province: 'Lleida', massif: 'Pirineu', description: 'Cim fronterer amb Andorra' },
  { id: 'pic-de-rulhe', name: 'Pic de Rulhe', altitude: 2783, latitude: 42.6667, longitude: 1.5500, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },
  { id: 'pic-de-maubermе', name: 'Pic de Mauberme', altitude: 2880, latitude: 42.7167, longitude: 0.9667, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },
  { id: 'tuc-de-molières', name: 'Tuc de Molières', altitude: 3010, latitude: 42.7333, longitude: 0.9000, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },
  { id: 'tuc-de-la-mulassa', name: 'Tuc de la Mulassa', altitude: 2928, latitude: 42.7500, longitude: 0.8500, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },
  { id: 'era-pique-rouge', name: 'Era Pique Rouge', altitude: 2888, latitude: 42.7667, longitude: 0.8167, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },
  { id: 'pic-de-perdiguere', name: 'Pic de Perdiguère', altitude: 3222, latitude: 42.7167, longitude: 0.5833, province: 'Lleida', massif: 'Pirineu', description: 'Cim de la Val d\'Aran' },

  // Cims del Pallars
  { id: 'pic-de-peguera', name: 'Pic de Peguera', altitude: 2982, latitude: 42.5167, longitude: 0.9167, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Sobirà' },
  { id: 'pic-de-cabut', name: 'Pic de Cabut', altitude: 2996, latitude: 42.5333, longitude: 0.8833, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Sobirà' },
  { id: 'pic-de-saboredo', name: 'Pic de Saboredo', altitude: 2829, latitude: 42.5667, longitude: 0.9500, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Sobirà' },
  { id: 'pic-de-mainera', name: 'Pic de Mainera', altitude: 2669, latitude: 42.4833, longitude: 1.0167, province: 'Lleida', massif: 'Pirineu', description: 'Cim del Pallars Jussà' },
  { id: 'pic-de-campcardos', name: 'Pic de Campcardós', altitude: 2853, latitude: 42.4500, longitude: 1.8500, province: 'Girona', massif: 'Pirineu', description: 'Cim de la Cerdanya' },
  { id: 'puig-cerda', name: 'Puig de Cerda', altitude: 2670, latitude: 42.4333, longitude: 1.9167, province: 'Girona', massif: 'Pirineu', description: 'Cim de la Cerdanya' },
  { id: 'pic-de-eina', name: 'Pic d\'Eina', altitude: 2786, latitude: 42.4667, longitude: 2.0000, province: 'Girona', massif: 'Pirineu', description: 'Cim de la Cerdanya' },
  { id: 'pic-de-freser', name: 'Pic de Freser', altitude: 2789, latitude: 42.3833, longitude: 2.1500, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
  { id: 'pic-de-la-dona', name: 'Pic de la Dona', altitude: 2702, latitude: 42.3500, longitude: 2.2000, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
  { id: 'pic-dels-gallinaires', name: 'Pic dels Gallinaires', altitude: 2624, latitude: 42.3167, longitude: 2.2500, province: 'Girona', massif: 'Pirineu', description: 'Cim del Ripollès' },
];

async function seedSummits() {
  console.log('Pujant cims a Firestore...');
  const batch = db.batch();

  summits.forEach((summit) => {
    const ref = db.collection('summits').doc(summit.id);
    batch.set(ref, {
      name: summit.name,
      altitude: summit.altitude,
      latitude: summit.latitude,
      longitude: summit.longitude,
      province: summit.province,
      massif: summit.massif,
      description: summit.description,
      createdAt: new Date().toISOString(),
    });
  });

  await batch.commit();
  console.log(`✅ ${summits.length} cims pujats correctament!`);
  process.exit(0);
}

seedSummits().catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});