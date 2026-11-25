import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estat actual de l'usuari
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Registre amb email i contrasenya
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    final userModel = UserModel(
      uid: user.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toFirestore());
    return userModel;
  }

  // Login amb email i contrasenya
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();
    return UserModel.fromFirestore(doc.data()!, credential.user!.uid);
  }

  // Tancar sessió
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Re-autenticar l'usuari (necessari abans d'esborrar)
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser!;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // Esborrar compte i totes les dades de l'usuari
  Future<void> deleteAccount(String userId) async {
    final user = _auth.currentUser!;

    // Esborrar subcoleccions de l'usuari a Firestore
    final batch = _firestore.batch();

    // Esborrar user_summits
    final userSummits = await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .get();
    for (final doc in userSummits.docs) {
      batch.delete(doc.reference);
    }

    // Esborrar notificacions
    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    // Esborrar activitats
    final activities = await _firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in activities.docs) {
      batch.delete(doc.reference);
    }

    // Esborrar document de l'usuari
    batch.delete(_firestore.collection('users').doc(userId));

    await batch.commit();

    // Esborrar el compte de Firebase Auth
    await user.delete();
  }
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}