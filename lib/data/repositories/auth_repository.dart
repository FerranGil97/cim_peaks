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
}