import 'package:flutter/material.dart';
import 'public_profile_view.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';
import '../../data/models/summit_model.dart';
import '../../data/services/storage_service.dart';
import 'activity_calendar_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ranking_view.dart';
import '../summit/summit_detail_view.dart';


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
        final uid = authViewModel.currentUser!.uid;
        context.read<ProfileViewModel>().loadProfile(uid);
        context.read<SocialViewModel>().loadFollowing(uid); // 👈 afegeix això
      }
    });
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('⚠️ Esborrar compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aquesta acció és irreversible. S\'esborraran totes les teves dades, activitats i medalles.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Introdueix la teva contrasenya per confirmar:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contrasenya',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel·lar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;
                      setDialogState(() => isLoading = true);

                      final authViewModel = context.read<AuthViewModel>();

                      // Re-autenticar primer
                      final reauthed = await authViewModel
                          .reauthenticate(passwordController.text);

                      if (!reauthed) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contrasenya incorrecta'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }

                      // Esborrar compte
                      final deleted = await authViewModel.deleteAccount();

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (!deleted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error en esborrar el compte'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        // Si deleted == true, AuthGate redirigeix sol a LoginView
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Esborrar compte'),
            ),
          ],
        ),
      ),
    );
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
                    GestureDetector(
                      onTap: () async {
                        final authViewModel = context.read<AuthViewModel>();
                        final profileViewModel = context.read<ProfileViewModel>();
                        final storageService = StorageService();
                        final file = await storageService.pickAndCropImage(fromCamera: false);
                        if (file != null && authViewModel.currentUser != null) {
                          await profileViewModel.updateProfilePhoto(
                              authViewModel.currentUser!.uid, file);
                          await profileViewModel
                              .loadProfile(authViewModel.currentUser!.uid);
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            backgroundImage: profileViewModel.photoUrl != null
                                ? NetworkImage(profileViewModel.photoUrl!)
                                : null,
                            child: profileViewModel.photoUrl == null
                                ? Text(
                                    (profileViewModel.user?.displayName ?? 'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.green),
                            ),
                          ),
                        ],
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
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.leaderboard, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RankingView()),
                ),
                tooltip: 'Rànquing',
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivityCalendarView()),
                ),
                tooltip: 'Les meves activitats',
              ),
            ],
            
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Seguidors i seguits
                  _buildFollowCard(context, profileViewModel),
                  const SizedBox(height: 16),

                  // Estadístiques
                  _buildStatsCard(profileViewModel),
                  const SizedBox(height: 16),

                  // Repte 100 cims FEEC
                  _buildChallengeCard(context, profileViewModel),
                  const SizedBox(height: 16),

                  // Repte Cim de Comarca
                  _buildComarcaChallengeCard(context, profileViewModel),
                  const SizedBox(height: 16),

                  // Configuració del compte
                  _buildAccountCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final profileViewModel = context.watch<ProfileViewModel>();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline, color: Colors.grey),
            title: const Text('Perfil privat'),
            subtitle: const Text(
              'Només els teus seguidors podran veure el teu perfil',
              style: TextStyle(fontSize: 12),
            ),
            value: profileViewModel.isPrivate,
            activeColor: Colors.green,
            onChanged: (val) {
              final authViewModel = context.read<AuthViewModel>();
              if (authViewModel.currentUser != null) {
                profileViewModel.setPrivate(
                    authViewModel.currentUser!.uid, val);
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: Colors.grey),
            title: const Text('Termes i condicions'),
            trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: () => launchUrl(Uri.parse(
              'https://ferrangil97.github.io/cim-peaks-legal/terms_conditions.html',
            )),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('Tancar sessió'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.read<AuthViewModel>().signOut(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Esborrar compte',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Esborra el teu compte i totes les dades',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowCard(
      BuildContext context, ProfileViewModel profileViewModel) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showFollowList(
                  context,
                  title: 'Seguits',
                  users: profileViewModel.following,
                ),
                child: Column(
                  children: [
                    Text(
                      '${profileViewModel.following.length}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Seguits',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFollowList(
                  context,
                  title: 'Seguidors',
                  users: profileViewModel.followers,
                ),
                child: Column(
                  children: [
                    Text(
                      '${profileViewModel.followers.length}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Seguidors',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFollowList(BuildContext context,
      {required String title,
      required List<Map<String, dynamic>> users}) {
    final authViewModel = context.read<AuthViewModel>();
    final socialViewModel = context.read<SocialViewModel>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<SocialViewModel>(),
        child: Consumer<SocialViewModel>(
          builder: (ctx, socialVm, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (users.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  title == 'Seguits'
                      ? 'Encara no segueixes ningú'
                      : 'Encara no tens seguidors',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final userId = user['id'] as String;
                  final isFollowing =
                      socialVm.isFollowing(userId);

                  return ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicProfileView(
                          userId: userId,
                          displayName: user['displayName'] ?? 'Usuari',
                        ),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        (user['displayName'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['displayName'] ?? 'Usuari'),
                    subtitle: Text(
                        '${user['totalSummits'] ?? 0} cims assolits'),
                    trailing: userId != authViewModel.currentUser!.uid
                        ? ElevatedButton(
                            onPressed: () {
                              final isPrivate = user['isPrivate'] ?? false;
                              socialVm.toggleFollow(
                                authViewModel.currentUser!.uid,
                                authViewModel.currentUser!.displayName,
                                userId,
                                isPrivate: isPrivate,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? Colors.grey[200]
                                  : socialVm.hasPendingRequest(userId)
                                    ? Colors.orange[100]
                                    : Colors.green,
                              foregroundColor: isFollowing
                                  ? Colors.black
                                  : socialVm.hasPendingRequest(userId)
                                    ? Colors.orange
                                    : Colors.white,
                            ),
                            child: Text(
                              isFollowing
                                  ? 'Seguint'
                                  : socialVm.hasPendingRequest(userId)
                                      ? 'Sol·licitada'
                                      : 'Seguir',
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
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
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showSummitList(
                      context,
                      title: 'Cims assolits',
                      summits: vm.achievedSummits,
                      emoji: '✅',
                      color: Colors.green,
                    ),
                    child: _statItem('✅', '${vm.totalAchieved}', 'Assolits'),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showSummitList(
                      context,
                      title: 'Cims guardats',
                      summits: vm.savedSummits,
                      emoji: '⭐',
                      color: Colors.orange,
                    ),
                    child: _statItem('⭐', '${vm.totalSaved}', 'Guardats'),
                  ),
                ),
                Expanded(
                  child: _statItem('📏', '${vm.highestSummit}m', 'Màxim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSummitList(
    BuildContext context, {
    required String title,
    required List<SummitModel> summits,
    required String emoji,
    required Color color,
  }) {
    // Ordenació per defecte: altitud descendent
    String searchQuery = '';
    String sortOrder = 'altitudeDesc'; // altitudeDesc | altitudeAsc | ratingDesc | ratingAsc

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filtre amb normalització
          final q = _normalize(searchQuery);
          var filtered = summits.where((s) {
            if (q.isEmpty) return true;
            return _normalize(s.name).contains(q) ||
                _normalize(s.province ?? '').contains(q) ||
                _normalize(s.massif ?? '').contains(q);
          }).toList();

          // Ordenació
          switch (sortOrder) {
            case 'altitudeDesc':
              filtered.sort((a, b) => b.altitude.compareTo(a.altitude));
            case 'altitudeAsc':
              filtered.sort((a, b) => a.altitude.compareTo(b.altitude));
            case 'ratingDesc':
              filtered.sort((a, b) => (b.userRating  ?? 0).compareTo(a.userRating  ?? 0));
            case 'ratingAsc':
              filtered.sort((a, b) => (a.userRating  ?? 0).compareTo(b.userRating  ?? 0));
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Capçalera
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title (${filtered.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      // Botó ordenació
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, color: Colors.grey),
                        tooltip: 'Ordenar',
                        onSelected: (value) =>
                            setModalState(() => sortOrder = value),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'altitudeDesc',
                            child: Row(children: [
                              Icon(Icons.arrow_downward,
                                  size: 16,
                                  color: sortOrder == 'altitudeDesc'
                                      ? Colors.green
                                      : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Altitud (↓)',
                                  style: TextStyle(
                                      color: sortOrder == 'altitudeDesc'
                                          ? Colors.green
                                          : null,
                                      fontWeight: sortOrder == 'altitudeDesc'
                                          ? FontWeight.bold
                                          : null)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'altitudeAsc',
                            child: Row(children: [
                              Icon(Icons.arrow_upward,
                                  size: 16,
                                  color: sortOrder == 'altitudeAsc'
                                      ? Colors.green
                                      : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Altitud (↑)',
                                  style: TextStyle(
                                      color: sortOrder == 'altitudeAsc'
                                          ? Colors.green
                                          : null,
                                      fontWeight: sortOrder == 'altitudeAsc'
                                          ? FontWeight.bold
                                          : null)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'ratingDesc',
                            child: Row(children: [
                              Icon(Icons.star,
                                  size: 16,
                                  color: sortOrder == 'ratingDesc'
                                      ? Colors.green
                                      : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Rating (↓)',
                                  style: TextStyle(
                                      color: sortOrder == 'ratingDesc'
                                          ? Colors.green
                                          : null,
                                      fontWeight: sortOrder == 'ratingDesc'
                                          ? FontWeight.bold
                                          : null)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'ratingAsc',
                            child: Row(children: [
                              Icon(Icons.star_border,
                                  size: 16,
                                  color: sortOrder == 'ratingAsc'
                                      ? Colors.green
                                      : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Rating (↑)',
                                  style: TextStyle(
                                      color: sortOrder == 'ratingAsc'
                                          ? Colors.green
                                          : null,
                                      fontWeight: sortOrder == 'ratingAsc'
                                          ? FontWeight.bold
                                          : null)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Buscador
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar cim...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) =>
                        setModalState(() => searchQuery = value),
                  ),
                ),

                // Llista
                if (summits.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Encara no n\'hi ha cap',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else if (filtered.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No s\'han trobat cims',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final summit = filtered[index];
                        final rating = summit.userRating ;
                        return ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SummitDetailView(summit: summit),
                            ),
                          ),
                          leading: Container(
                            width: 56,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color),
                            ),
                            child: Center(
                              child: Text(
                                summit.achievedAt != null
                                    ? '${summit.achievedAt!.day.toString().padLeft(2, '0')}/${summit.achievedAt!.month.toString().padLeft(2, '0')}\n${summit.achievedAt!.year}'
                                    : '—',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          title: Text(summit.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${summit.altitude}m${summit.province != null ? ' · ${summit.province}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (rating != null && rating > 0)
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < rating.round() ? Icons.star : Icons.star_border,
                                      size: 14,
                                      color: Colors.amber,
                                    );
                                  }),
                                ),
                            ],
                          ),
                          isThreeLine: rating != null && rating > 0,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, ProfileViewModel vm) {
    if (vm.challengeLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: Colors.green)),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Títol i badge
            Row(
              children: [
                const Text('🏔️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Repte Els 100 Cims FEEC',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    '${vm.totalChallengeAchieved}/100',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de progrés
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vm.challengeProgress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(vm.challengeProgress * 100).toStringAsFixed(1)}% completat',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Botó veure cims
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showChallengeSummits(context, vm),
                icon: const Icon(Icons.list, color: Colors.blue),
                label: const Text('Veure cims del repte',
                    style: TextStyle(color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildComarcaChallengeCard(BuildContext context, ProfileViewModel vm) {
    if (vm.comarcaChallengeLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: Colors.orange)),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🗺️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Repte Cim de Comarca',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    '${vm.totalComarcaAchieved}/${vm.totalComarcaCount}',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vm.comarcaChallengeProgress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(vm.comarcaChallengeProgress * 100).toStringAsFixed(1)}% completat',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showComarcaChallengeSummits(context, vm),
                icon: const Icon(Icons.list, color: Colors.orange),
                label: const Text('Veure cims del repte',
                    style: TextStyle(color: Colors.orange)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComarcaChallengeSummits(BuildContext context, ProfileViewModel vm) {
    final achieved = vm.achievedComarcaChallengeSummits.map((s) => s.id).toSet();
    final validSummits = vm.comarcaChallengeSummits
        .where((s) => s.name.isNotEmpty && s.altitude > 0)
        .toList();

    final achievedSummits = validSummits
        .where((s) => achieved.contains(s.id))
        .toList()
      ..sort((a, b) => b.altitude.compareTo(a.altitude));

    final pendingSummits = validSummits
        .where((s) => !achieved.contains(s.id))
        .toList()
      ..sort((a, b) => b.altitude.compareTo(a.altitude));

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final q = _normalize(searchQuery);
          final filteredAchieved = achievedSummits.where((s) =>
              _normalize(s.name).contains(q) ||
              _normalize(s.province ?? '').contains(q) ||
              _normalize(s.massif ?? '').contains(q)).toList();
          final filteredPending = pendingSummits.where((s) =>
              _normalize(s.name).contains(q) ||
              _normalize(s.province ?? '').contains(q) ||
              _normalize(s.massif ?? '').contains(q)).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text('🗺️', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Cim de Comarca',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Text(
                          '${achievedSummits.length}/${validSummits.length}',
                          style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar cim...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) => setModalState(() => searchQuery = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (filteredAchieved.isNotEmpty) ...[
                        _sectionHeader(
                            '✅ Assolits (${filteredAchieved.length})',
                            Colors.green),
                        ...filteredAchieved.map(
                            (s) => _challengeSummitTile(s, true)),
                      ],
                      if (filteredPending.isNotEmpty) ...[
                        _sectionHeader(
                            '🟠 Pendents (${filteredPending.length})',
                            Colors.orange),
                        ...filteredPending.map(
                            (s) => _challengeSummitTile(s, false,
                                pendingColor: Colors.orange)),
                      ],
                      if (filteredAchieved.isEmpty && filteredPending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: Text("'No s'han trobat cims'",
                                  style: TextStyle(color: Colors.grey))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _normalize(String text) {
    const accents    = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    const normalized = 'aaaaaaeeeeiiiioooooуuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    var result = text.toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], normalized[i]);
    }
    return result;
  }

  void _showChallengeSummits(BuildContext context, ProfileViewModel vm) {
    final achieved = vm.achievedChallengeSummits.map((s) => s.id).toSet();

    // Filtrar cims sense nom o sense altitud vàlida
    final validSummits = vm.challengeSummits
        .where((s) => s.name.isNotEmpty && s.altitude > 0)
        .toList();

    // Separar en assolits i pendents
    final achievedSummits = validSummits
        .where((s) => achieved.contains(s.id))
        .toList()
      ..sort((a, b) => b.altitude.compareTo(a.altitude));

    final pendingSummits = validSummits
        .where((s) => !achieved.contains(s.id))
        .toList()
      ..sort((a, b) => b.altitude.compareTo(a.altitude));

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          // 🔍 FILTRE
          final q = _normalize(searchQuery);
          final filteredAchieved = achievedSummits.where((s) {
            return _normalize(s.name).contains(q) ||
                _normalize(s.province ?? '').contains(q) ||
                _normalize(s.massif ?? '').contains(q);
          }).toList();

          final filteredPending = pendingSummits.where((s) {
            return _normalize(s.name).contains(q) ||
                _normalize(s.province ?? '').contains(q) ||
                _normalize(s.massif ?? '').contains(q);
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Capçalera
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Text('🏔️', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Els 100 Cims FEEC',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          '${achievedSummits.length}/${validSummits.length}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 🔍 BUSCADOR
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar cim...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),

                // Llista
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Assolits
                      if (filteredAchieved.isNotEmpty) ...[
                        _sectionHeader(
                          '✅ Assolits (${filteredAchieved.length})',
                          Colors.green,
                        ),
                        ...filteredAchieved.map((summit) =>
                            _challengeSummitTile(summit, true)),
                      ],

                      // Pendents
                      if (filteredPending.isNotEmpty) ...[
                        _sectionHeader(
                          '🔵 Pendents (${filteredPending.length})',
                          Colors.blue,
                        ),
                        ...filteredPending.map((summit) =>
                            _challengeSummitTile(summit, false)),
                      ],

                      // Cas sense resultats
                      if (filteredAchieved.isEmpty &&
                          filteredPending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No s\'han trobat cims',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.08),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }

  Widget _challengeSummitTile(SummitModel summit, bool isAchieved,
      {Color pendingColor = Colors.blue}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isAchieved ? Colors.green[50] : pendingColor.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isAchieved ? Colors.green : pendingColor,
          ),
        ),
        child: Center(
          child: Text(
            isAchieved ? '✅' : (pendingColor == Colors.orange ? '🟠' : '🔵'),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      title: Text(
        summit.name,
        style: TextStyle(
          fontWeight: isAchieved ? FontWeight.bold : FontWeight.w500,
          color: isAchieved ? Colors.black : Colors.grey[700],
        ),
      ),
      subtitle: Text(
        '${summit.altitude}m${summit.province != null ? ' · ${summit.province}' : ''}${summit.massif != null ? ' · ${summit.massif}' : ''}',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isAchieved
          ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
          : null,
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }


}