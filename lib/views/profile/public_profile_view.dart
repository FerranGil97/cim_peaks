import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      // Carregar en paral·lel el que no té dependències
      await Future.wait([
        _loadProfile(),
        _loadSummits(),
        _loadFollowData(),
      ]);
      // Challenge progress depèn de _achievedSummits, va després
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

    final achievedIds =
        _achievedSummits.map((s) => s.id).toSet();
    _achievedChallengeSummits =
        _challengeSummits.where((s) => achievedIds.contains(s.id)).toList();
  }

  int get _totalAchieved => _achievedSummits.length;
  int get _highestSummit => _achievedSummits.isEmpty
      ? 0
      : _achievedSummits.map((s) => s.altitude).reduce((a, b) => a > b ? a : b);

  int get _level {
    if (_totalAchieved >= 50) return 5;
    if (_totalAchieved >= 25) return 4;
    if (_totalAchieved >= 10) return 3;
    if (_totalAchieved >= 5) return 2;
    return 1;
  }

  String get _levelName => switch (_level) {
        1 => 'Principiant',
        2 => 'Excursionista',
        3 => 'Muntanyenc',
        4 => 'Alpinista',
        5 => 'Llegenda',
        _ => 'Principiant',
      };

  double get _levelProgress {
    final thresholds = [0, 5, 10, 25, 50];
    final current = thresholds[_level - 1];
    final next = _level < 5 ? thresholds[_level] : 50;
    return ((_totalAchieved - current) / (next - current)).clamp(0.0, 1.0);
  }

  List<Map<String, dynamic>> get _allBadges => [
        {
          'icon': '🏔️',
          'name': 'Primer Cim',
          'desc': 'Assoleix el teu primer cim',
          'earned': _totalAchieved >= 1,
        },
        {
          'icon': '⭐',
          'name': 'Explorador',
          'desc': 'Assoleix 5 cims',
          'earned': _totalAchieved >= 5,
        },
        {
          'icon': '🦅',
          'name': 'Àguila',
          'desc': 'Assoleix 10 cims',
          'earned': _totalAchieved >= 10,
        },
        {
          'icon': '🏆',
          'name': 'Campió',
          'desc': 'Assoleix 25 cims',
          'earned': _totalAchieved >= 25,
        },
        {
          'icon': '❄️',
          'name': 'Tres Mil',
          'desc': 'Assoleix un cim de +3000m',
          'earned': _highestSummit >= 3000,
        },
        {
          'icon': '👑',
          'name': 'Llegenda',
          'desc': 'Assoleix 50 cims',
          'earned': _totalAchieved >= 50,
        },
        {
          'icon': '🗺️',
          'name': 'Cartògraf',
          'desc': 'Guarda 10 cims per fer',
          'earned': false, // No tenim accés als guardats públicament
        },
        {
          'icon': '🌄',
          'name': 'Pirenaic',
          'desc': 'Assoleix 3 cims del Pirineu',
          'earned': _achievedSummits
                  .where((s) => (s.massif ?? '').contains('Pirineu'))
                  .length >=
              3,
        },
        {
          'icon': '🧗',
          'name': 'Escalador',
          'desc': 'Assoleix 5 cims de +2500m',
          'earned':
              _achievedSummits.where((s) => s.altitude >= 2500).length >= 5,
        },
      ];

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final socialViewModel = context.watch<SocialViewModel>();
    final currentUserId = authViewModel.currentUser!.uid;
    final isMe = widget.userId == currentUserId;
    final isFollowing = socialViewModel.isFollowing(widget.userId);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : CustomScrollView(
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
                          Text(
                            '$_levelName · Nivell $_level',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
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
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isFollowing ? Colors.grey[200] : Colors.white,
                            foregroundColor:
                                isFollowing ? Colors.black : Colors.green,
                          ),
                          child: Text(isFollowing ? 'Seguint' : 'Seguir'),
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
                                  child: Column(
                                    children: [
                                      Text('${_following.length}',
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold)),
                                      const Text('Seguits',
                                          style:
                                              TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300]),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('${_followers.length}',
                                          style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold)),
                                      const Text('Seguidors',
                                          style:
                                              TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Progrés de nivell
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Nivell $_level — $_levelName',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Text('$_totalAchieved cims',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _levelProgress,
                                    minHeight: 10,
                                    backgroundColor: Colors.grey[200],
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.green),
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
                                        child: _statItem('✅', '$_totalAchieved', 'Assolits'),
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
                                      onPressed: () => _showChallengeSummits(context),
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

                        // Medalles
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Medalles (${_allBadges.where((b) => b['earned'] == true).length}/${_allBadges.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _allBadges.length,
                                  itemBuilder: (context, index) {
                                    final badge = _allBadges[index];
                                    final earned = badge['earned'] == true;
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: earned
                                            ? Colors.green[50]
                                            : Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: earned
                                              ? Colors.green[200]!
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ColorFiltered(
                                            colorFilter: earned
                                                ? const ColorFilter.mode(
                                                    Colors.transparent,
                                                    BlendMode.multiply)
                                                : const ColorFilter.matrix([
                                                    0.2126, 0.7152, 0.0722,
                                                    0, 0,
                                                    0.2126, 0.7152, 0.0722,
                                                    0, 0,
                                                    0.2126, 0.7152, 0.0722,
                                                    0, 0,
                                                    0, 0, 0, 1, 0,
                                                  ]),
                                            child: Text(
                                              badge['icon'],
                                              style: const TextStyle(
                                                  fontSize: 32),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            earned ? badge['name'] : '???',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: earned
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (earned)
                                            const Icon(Icons.check_circle,
                                                size: 14,
                                                color: Colors.green),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                          style: const TextStyle(fontWeight: FontWeight.w500)),
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
          final filteredAchieved = achievedSummits.where((s) {
            return s.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (s.province ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
                (s.massif ?? '').toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          final filteredPending = pendingSummits.where((s) {
            return s.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (s.province ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
                (s.massif ?? '').toLowerCase().contains(searchQuery.toLowerCase());
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                        ...filteredAchieved.map(
                            (s) => _challengeSummitTile(s, true)),
                      ],
                      if (filteredPending.isNotEmpty) ...[
                        _sectionHeader(
                            '🔵 Pendents (${filteredPending.length})',
                            Colors.blue),
                        ...filteredPending.map(
                            (s) => _challengeSummitTile(s, false)),
                      ],
                      if (filteredAchieved.isEmpty && filteredPending.isEmpty)
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

// Pantalla de mapa en gran per veure els cims d'un usuari
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

  Set<Marker> _buildMarkers() {
    return widget.summits.map((summit) {
      return Marker(
        markerId: MarkerId(summit.id),
        position: LatLng(summit.latitude, summit.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
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
          // Centrar al primer cim si n'hi ha
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