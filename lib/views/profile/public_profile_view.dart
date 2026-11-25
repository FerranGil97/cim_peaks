import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:provider/provider.dart';

class PublicProfileView extends StatefulWidget {
  final String userId;
  final String displayName;

  const PublicProfileView({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  State<PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<PublicProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Dades de l'usuari
  Map<String, dynamic>? _userData;
  List<SummitModel> _achievedSummits = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _followers = [];
  List<SummitModel> _challengeSummits = [];
  List<SummitModel> _achievedChallengeSummits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final socialViewModel = context.read<SocialViewModel>();
      if (authViewModel.currentUser != null) {
        socialViewModel.checkPendingRequest(
            authViewModel.currentUser!.uid, widget.userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadProfile(),
        _loadSummits(),
        _loadFollowData(),
      ]);
      await _loadChallengeProgress();
    } catch (e) {
      debugPrint('Error carregant perfil públic: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (doc.exists) _userData = doc.data();
  }

  Future<void> _loadSummits() async {
    final summitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('user_summits')
        .where('status', isEqualTo: 'achieved')
        .get();

    final summitIds = summitsSnapshot.docs.map((d) => d.id).toList();
    if (summitIds.isEmpty) return;

    final userSummitsMap = {
      for (var doc in summitsSnapshot.docs) doc.id: doc.data()
    };

    final List<SummitModel> summits = [];
    for (int i = 0; i < summitIds.length; i += 30) {
      final chunk = summitIds.sublist(
          i, i + 30 > summitIds.length ? summitIds.length : i + 30);
      final globalSnapshot = await FirebaseFirestore.instance
          .collection('summits')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in globalSnapshot.docs) {
        final data = doc.data();
        final userData = userSummitsMap[doc.id];
        if (userData != null) {
          data['status'] = userData['status'];
          data['achievedAt'] = userData['achievedAt'];
        }
        summits.add(SummitModel.fromFirestore(data, doc.id));
      }
    }
    summits.sort((a, b) => b.altitude.compareTo(a.altitude));
    _achievedSummits = summits;
  }

  Future<void> _loadFollowData() async {
    final followingSnap = await FirebaseFirestore.instance
        .collection('follows')
        .doc(widget.userId)
        .collection('following')
        .get();
    final followerSnap = await FirebaseFirestore.instance
        .collection('follows')
        .doc(widget.userId)
        .collection('followers')
        .get();

    final followingIds = followingSnap.docs.map((d) => d.id).toList();
    final followerIds = followerSnap.docs.map((d) => d.id).toList();

    _following = await _fetchUsers(followingIds);
    _followers = await _fetchUsers(followerIds);
  }

  Future<List<Map<String, dynamic>>> _fetchUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(
          i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result.add({'id': doc.id, ...doc.data()});
      }
    }
    return result;
  }

  Future<void> _loadChallengeProgress() async {
    final challengeSnapshot = await FirebaseFirestore.instance
        .collection('summits')
        .where('showOnMap', isEqualTo: true)
        .get();
    _challengeSummits = challengeSnapshot.docs
        .map((doc) => SummitModel.fromFirestore(doc.data(), doc.id))
        .toList();

    final achievedIds = _achievedSummits.map((s) => s.id).toSet();
    _achievedChallengeSummits =
        _challengeSummits.where((s) => achievedIds.contains(s.id)).toList();
  }

  int get _totalAchieved => _achievedSummits.length;
  int get _highestSummit => _achievedSummits.isEmpty
      ? 0
      : _achievedSummits.map((s) => s.altitude).reduce((a, b) => a > b ? a : b);

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
                      ? 'Encara no segueix ningú'
                      : 'Encara no té seguidors',
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
                  final isFollowing = socialVm.isFollowing(userId);
                  final currentUserId = authViewModel.currentUser!.uid;

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
                    trailing: userId != currentUserId
                        ? ElevatedButton(
                            onPressed: () {
                              final isPrivate = user['isPrivate'] ?? false;
                              socialVm.toggleFollow(
                                currentUserId,
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



  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final socialViewModel = context.watch<SocialViewModel>();
    final currentUserId = authViewModel.currentUser!.uid;
    final isMe = widget.userId == currentUserId;
    final isFollowing = socialViewModel.isFollowing(widget.userId);

    final isPrivate = _userData?['isPrivate'] ?? false;
    final canSeeProfile = !isPrivate || isMe || isFollowing;

    final hasPending = socialViewModel.hasPendingRequest(widget.userId);

    return Scaffold(
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : !canSeeProfile
            ? _buildPrivateProfileScreen(isFollowing, hasPending, socialViewModel,
              currentUserId, authViewModel)
          : CustomScrollView(
              slivers: [
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
                            backgroundImage: _userData?['photoUrl'] != null
                                ? NetworkImage(_userData!['photoUrl'])
                                : null,
                            child: _userData?['photoUrl'] == null
                                ? Text(
                                    widget.displayName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.displayName,
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
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ElevatedButton(
                          onPressed: () => socialViewModel.toggleFollow(
                            currentUserId,
                            authViewModel.currentUser!.displayName,
                            widget.userId,
                            isPrivate: _userData?['isPrivate'] ?? false,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? Colors.grey[200]
                                : hasPending
                                    ? Colors.orange[100]
                                    : Colors.white,
                            foregroundColor: isFollowing
                                ? Colors.black
                                : hasPending
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          child: Text(
                            isFollowing ? 'Seguint' : hasPending ? 'Sol·licitud enviada' : 'Seguir',
                          ),
                        ),
                      ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Seguits i seguidors
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showFollowList(
                                      context,
                                      title: 'Seguits',
                                      users: _following,
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${_following.length}',
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold)),
                                        const Text('Seguits',
                                            style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 40, color: Colors.grey[300]),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showFollowList(
                                      context,
                                      title: 'Seguidors',
                                      users: _followers,
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${_followers.length}',
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold)),
                                        const Text('Seguidors',
                                            style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Estadístiques
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estadístiques',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _showSummitList(context),
                                        child: _statItem(
                                            '✅', '$_totalAchieved', 'Assolits'),
                                      ),
                                    ),
                                    Expanded(
                                        child: _statItem('📏',
                                            '${_highestSummit}m', 'Màxim')),
                                    Expanded(
                                        child: _statItem(
                                            '🏔️',
                                            '${_achievedChallengeSummits.length}/${_challengeSummits.length}',
                                            'Repte')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Repte FEEC
                        if (_challengeSummits.isNotEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('🏔️',
                                          style: TextStyle(fontSize: 22)),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Repte Els 100 Cims FEEC',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.blue[200]!),
                                        ),
                                        child: Text(
                                          '${_achievedChallengeSummits.length}/${_challengeSummits.length}',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: _challengeSummits.isEmpty
                                          ? 0
                                          : _achievedChallengeSummits.length /
                                              _challengeSummits.length,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey[200],
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(_challengeSummits.isEmpty ? 0 : _achievedChallengeSummits.length / _challengeSummits.length * 100).toStringAsFixed(1)}% completat',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showChallengeSummits(context),
                                      icon: const Icon(Icons.list,
                                          color: Colors.blue),
                                      label: const Text('Veure cims del repte',
                                          style:
                                              TextStyle(color: Colors.blue)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Colors.blue),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Botó per obrir el mapa
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Text('🗺️',
                                style: TextStyle(fontSize: 28)),
                            title: Text(
                              'Veure cims assolits al mapa ($_totalAchieved)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                                'Toca per obrir el mapa interactiu'),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.green),
                            onTap: _totalAchieved == 0
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _UserSummitsMapView(
                                          summits: _achievedSummits,
                                          displayName: widget.displayName,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPrivateProfileScreen(bool isFollowing, bool hasPending,
      SocialViewModel socialViewModel, String currentUserId,
      AuthViewModel authViewModel) {
    return CustomScrollView(
      slivers: [
        // Mateix header que el perfil normal
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
                    backgroundImage: _userData?['photoUrl'] != null
                        ? NetworkImage(_userData!['photoUrl'])
                        : null,
                    child: _userData?['photoUrl'] == null
                        ? Text(
                            widget.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.displayName,
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
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: () => socialViewModel.toggleFollow(
                  currentUserId,
                  authViewModel.currentUser!.displayName,
                  widget.userId, isPrivate: true,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing ? Colors.grey[200] : hasPending 
                      ? Colors.orange[100] 
                      : Colors.white,
                  foregroundColor:
                      isFollowing ? Colors.black : hasPending
                      ? Colors.orange
                      : Colors.green,
                ),
                child: Text(isFollowing ? 'Seguint' : hasPending ? 'Sol·licitud enviada' : 'Seguir',),
              ),
            ),
          ],
        ),
        // Missatge de perfil privat
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Aquest perfil és privat',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Només les amistats poden veure\nels detalls d\'aquest perfil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (!isFollowing && !hasPending) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => socialViewModel.toggleFollow(
                      currentUserId,
                      authViewModel.currentUser!.displayName,
                      widget.userId,
                      isPrivate: true,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Seguir'),
                  ),
                ] else if (hasPending) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => socialViewModel.toggleFollow(
                      currentUserId,
                      authViewModel.currentUser!.displayName,
                      widget.userId,
                      isPrivate: true,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text('Cancel·lar sol·licitud'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSummitList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    'Cims assolits (${_achievedSummits.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_achievedSummits.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Encara no n\'hi ha cap',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _achievedSummits.length,
                  itemBuilder: (context, index) {
                    final summit = _achievedSummits[index];
                    return ListTile(
                      leading: Container(
                        width: 56,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Center(
                          child: Text(
                            summit.achievedAt != null
                                ? '${summit.achievedAt!.day.toString().padLeft(2, '0')}/${summit.achievedAt!.month.toString().padLeft(2, '0')}\n${summit.achievedAt!.year}'
                                : '—',
                            style: const TextStyle(
                              color: Colors.green,
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
                      subtitle: Text(
                        '${summit.altitude}m${summit.province != null ? ' · ${summit.province}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
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

  void _showChallengeSummits(BuildContext context) {
    final achieved = _achievedChallengeSummits.map((s) => s.id).toSet();

    final validSummits = _challengeSummits
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

                // Buscador
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
                    onChanged: (value) =>
                        setModalState(() => searchQuery = value),
                  ),
                ),

                // Llista
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (filteredAchieved.isNotEmpty) ...[
                        _sectionHeader(
                            '✅ Assolits (${filteredAchieved.length})',
                            Colors.green),
                        ...filteredAchieved
                            .map((s) => _challengeSummitTile(s, true)),
                      ],
                      if (filteredPending.isNotEmpty) ...[
                        _sectionHeader(
                            '🔵 Pendents (${filteredPending.length})',
                            Colors.blue),
                        ...filteredPending
                            .map((s) => _challengeSummitTile(s, false)),
                      ],
                      if (filteredAchieved.isEmpty &&
                          filteredPending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No s\'han trobat cims',
                                style: TextStyle(color: Colors.grey)),
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

  Widget _challengeSummitTile(SummitModel summit, bool isAchieved) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isAchieved ? Colors.green[50] : Colors.blue[50],
          shape: BoxShape.circle,
          border: Border.all(
            color: isAchieved ? Colors.green : Colors.blue[300]!,
          ),
        ),
        child: Center(
          child: Text(
            isAchieved ? '✅' : '🔵',
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

// ─── Pantalla de mapa en gran per veure els cims d'un usuari ───────────────

class _UserSummitsMapView extends StatefulWidget {
  final List<SummitModel> summits;
  final String displayName;

  const _UserSummitsMapView({
    required this.summits,
    required this.displayName,
  });

  @override
  State<_UserSummitsMapView> createState() => _UserSummitsMapViewState();
}

class _UserSummitsMapViewState extends State<_UserSummitsMapView> {
  GoogleMapController? _mapController;
  static const LatLng _initialPosition = LatLng(42.0, 1.5);

  BitmapDescriptor? _triangleIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();
  }

  Future<void> _loadMarkerIcon() async {
    final icon = await _createTriangleMarker(BitmapDescriptor.hueGreen);
    if (mounted) setState(() => _triangleIcon = icon);
  }

  Future<BitmapDescriptor> _createTriangleMarker(double hue,
      {double size = 36}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Color color = HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();

    // Ombra lleugera
    final shadowPath = Path()
      ..moveTo(size / 2, 2)
      ..lineTo(size - 2, size + 2)
      ..lineTo(2, size + 2)
      ..close();
    canvas.drawPath(
        shadowPath, Paint()..color = Colors.black.withOpacity(0.2));

    // Triangle principal
    final trianglePath = Path()
      ..moveTo(size / 2, 0)
      ..lineTo(size, size)
      ..lineTo(0, size)
      ..close();
    canvas.drawPath(trianglePath, Paint()..color = color);

    // Vora blanca
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final ui.Image image = await recorder
        .endRecording()
        .toImage(size.toInt(), (size + 4).toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Set<Marker> _buildMarkers() {
    return widget.summits.map((summit) {
      return Marker(
        markerId: MarkerId(summit.id),
        position: LatLng(summit.latitude, summit.longitude),
        icon: _triangleIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: summit.name,
          snippet: '${summit.altitude}m \u2705',
        ),
      );
    }).toSet();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cims de ${widget.displayName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.summits.length} cims \u2705',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: (c) {
          _mapController = c;
          if (widget.summits.isNotEmpty) {
            final first = widget.summits.first;
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(first.latitude, first.longitude),
                8,
              ),
            );
          }
        },
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 7,
        ),
        markers: _buildMarkers(),
        mapType: MapType.terrain,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
      ),
    );
  }
}