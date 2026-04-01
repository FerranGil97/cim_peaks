import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cim Peaks'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authViewModel.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terrain, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Mapa principal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí anirà el mapa interactiu',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}