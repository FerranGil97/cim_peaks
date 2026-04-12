import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';

class BusinessRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir totes les empreses
  Stream<List<BusinessModel>> getBusinesses() {
    return _firestore
        .collection('businesses')
        .orderBy('isPro', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                BusinessModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Obtenir empreses per tipus
  Stream<List<BusinessModel>> getBusinessesByType(BusinessType type) {
    return _firestore
        .collection('businesses')
        .where('type', isEqualTo: type.name)
        .orderBy('isPro', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                BusinessModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Obtenir empreses associades a un cim
  Future<List<BusinessModel>> getBusinessesForSummit(
      String summitId) async {
    final snapshot = await _firestore
        .collection('businesses')
        .where('linkedSummitIds', arrayContains: summitId)
        .get();
    return snapshot.docs
        .map((doc) => BusinessModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // Buscar empreses per nom o comarca
  Future<List<BusinessModel>> searchBusinesses(String query) async {
    final snapshot = await _firestore.collection('businesses').get();
    final all = snapshot.docs
        .map((doc) => BusinessModel.fromFirestore(doc.data(), doc.id))
        .toList();
    return all
        .where((b) =>
            b.name.toLowerCase().contains(query.toLowerCase()) ||
            (b.comarca?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .toList();
  }
}