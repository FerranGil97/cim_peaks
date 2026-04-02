import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      if (authViewModel.currentUser != null) {
        context.read<ProfileViewModel>().loadProfile(authViewModel.currentUser!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileViewModel = context.watch<ProfileViewModel>();
    final authViewModel = context.read<AuthViewModel>();

    if (profileViewModel.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.green,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        (profileViewModel.user?.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileViewModel.user?.displayName ?? 'Usuari',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${profileViewModel.levelName} · Nivell ${profileViewModel.level}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => authViewModel.signOut(),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progrés de nivell
                  _buildLevelCard(profileViewModel),
                  const SizedBox(height: 16),

                  // Estadístiques
                  _buildStatsCard(profileViewModel),
                  const SizedBox(height: 16),

                  // Medalles
                  _buildBadgesCard(profileViewModel),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(ProfileViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nivell ${vm.level} — ${vm.levelName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${vm.totalAchieved} cims',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vm.levelProgress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vm.level < 5
                  ? 'Proper nivell: ${vm.levelName}'
                  : '🏆 Nivell màxim assolit!',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ProfileViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadístiques',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _statItem('✅', '${vm.totalAchieved}', 'Assolits')),
                Expanded(child: _statItem('⭐', '${vm.totalSaved}', 'Guardats')),
                Expanded(child: _statItem('🔴', '${vm.totalPending}', 'Pendents')),
                Expanded(child: _statItem('📏', '${vm.highestSummit}m', 'Màxim')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildBadgesCard(ProfileViewModel vm) {
    final earnedCount = vm.allBadges.where((b) => b['earned'] == true).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medalles ($earnedCount/${vm.allBadges.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: vm.allBadges.length,
              itemBuilder: (context, index) {
                final badge = vm.allBadges[index];
                final bool earned = badge['earned'] == true;

                return GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Row(
                        children: [
                          Text(earned ? badge['icon'] : '🔒'),
                          const SizedBox(width: 8),
                          Text(badge['name']),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(badge['desc']),
                          if (!earned) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 16, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text('Medalla bloquejada',
                                      style: TextStyle(
                                          color: Colors.orange, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tancar'),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: earned ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: earned ? Colors.green[200]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ColorFiltered(
                          colorFilter: earned
                              ? const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply)
                              : const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ]),
                          child: Text(
                            badge['icon'],
                            style: TextStyle(
                              fontSize: 32,
                              color: earned ? null : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          earned ? badge['name'] : '???',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: earned ? Colors.black : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (earned)
                          const Icon(Icons.check_circle,
                              size: 14, color: Colors.green),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}