import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _authRepository.authStateChanges.listen((User? user) {
      if (user == null) {
        _status = AuthStatus.unauthenticated;
      } else {
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authRepository.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authRepository.loginWithEmail(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _parseError(String error) {
    if (error.contains('user-not-found')) return 'Usuari no trobat';
    if (error.contains('wrong-password')) return 'Contrasenya incorrecta';
    if (error.contains('email-already-in-use')) return 'Aquest email ja està registrat';
    if (error.contains('weak-password')) return 'La contrasenya és massa feble';
    if (error.contains('invalid-email')) return 'Email no vàlid';
    if (error.contains('network-request-failed')) return 'Error de connexió';
    return 'Ha ocorregut un error. Torna-ho a intentar';
  }
}