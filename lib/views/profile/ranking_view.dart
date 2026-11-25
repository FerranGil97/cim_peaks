import 'package:flutter/material.dart';
import '../profile/public_profile_view.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';

class RankingView extends StatefulWidget {
  const RankingView({super.key});

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _globalRanking = [];
  List<Map<String, dynamic>> _friendsRanking = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRankings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRankings() async {
    setState(() => _isLoading = true);

    final authViewModel = context.read<AuthViewModel>();
    final socialViewModel = context.read<SocialViewModel>();
    final currentUserId = authViewModel.currentUser!.uid;

    try {
      // Ranking global — obtenir tots els usuaris ordenats per cims assolits
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalSummits', descending: true)
          .limit(100)
          .get();

      _globalRanking = usersSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'displayName': doc.data()['displayName'] ?? 'Usuari',
          'photoUrl': doc.data()['photoUrl'],
          'totalSummits': doc.data()['totalSummits'] ?? 0,
          'isMe': doc.id == currentUserId,
        };
      }).toList();

      // Ranking d'amics — filtrar pel ranking global
      final followingIds =
          await socialViewModel.loadFollowingIds(currentUserId);
      final friendIds = {...followingIds, currentUserId};

      _friendsRanking = _globalRanking
          .where((u) => friendIds.contains(u['id']))
          .toList();

    } catch (e) {
      debugPrint('Error carregant rankings: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rànquing'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Amics'),
            Tab(icon: Icon(Icons.public), text: 'Global'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRankingList(_friendsRanking, isFriends: true),
                _buildRankingList(_globalRanking, isFriends: false),
              ],
            ),
    );
  }

  Widget _buildRankingList(List<Map<String, dynamic>> ranking,
      {required bool isFriends}) {
    if (ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFriends ? Icons.people_outline : Icons.public,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isFriends
                  ? 'Segueix altres usuaris\nper veure el rànquing d\'amics'
                  : 'Encara no hi ha dades',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRankings,
      color: Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: ranking.length,
        itemBuilder: (context, index) {
          final user = ranking[index];
          final position = index + 1;
          final isMe = user['isMe'] == true;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isMe ? Colors.green[50] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe ? Colors.green[200]! : Colors.grey[200]!,
                width: isMe ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              onTap: isMe ? null : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicProfileView(
                    userId: user['id'],
                    displayName: user['displayName'],
                  ),
                ),
              ),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Posició
                  SizedBox(
                    width: 32,
                    child: Text(
                      _positionEmoji(position),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: position <= 3 ? 22 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green,
                    backgroundImage: user['photoUrl'] != null
                        ? NetworkImage(user['photoUrl'])
                        : null,
                    child: user['photoUrl'] == null
                        ? Text(
                            (user['displayName'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              title: Row(
                children: [
                  Text(
                    user['displayName'],
                    style: TextStyle(
                      fontWeight:
                          isMe ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Tu',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user['totalSummits']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    'cims',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _positionEmoji(int position) {
    return switch (position) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '#$position',
    };
  }
}