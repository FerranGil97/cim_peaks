import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/auth/login_view.dart';
import 'views/auth/register_view.dart';
import 'views/map/map_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ],
      child: MaterialApp(
        title: 'Cim Peaks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        routes: {
          '/login': (context) => const LoginView(),
          '/register': (context) => const RegisterView(),
          '/map': (context) => const MapView(),
        },
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    switch (authViewModel.status) {
      case AuthStatus.authenticated:
        return const MapView();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginView();
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.green),
          ),
        );
    }
  }
}