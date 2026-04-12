import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/feed_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';
import '../social/search_users_view.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      context.read<SocialViewModel>().loadFollowing(
          authViewModel.currentUser!.uid);
      context.read<FeedViewModel>().loadFeed(
          authViewModel.currentUser!.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedViewModel = context.watch<FeedViewModel>();
    final authViewModel = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchUsersView()),
            ),
          ),
        ],
      ),
      body: feedViewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green))
          : feedViewModel.activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.terrain, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Encara no hi ha activitats',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text(
                          'Segueix amistats o marca un cim com a assolit!',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SearchUsersView()),
                        ),
                        icon: const Icon(Icons.person_search),
                        label: const Text('Buscar amistats'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: feedViewModel.activities.length,
                  itemBuilder: (context, index) {
                    final activity = feedViewModel.activities[index];
                    return _ActivityCard(
                      activity: activity,
                      currentUserId: authViewModel.currentUser?.uid ?? '',
                    );
                  },
                ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final String currentUserId;
  final ActivityRepository _repository = ActivityRepository();

  _ActivityCard({
    required this.activity,
    required this.currentUserId,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Fa ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Fa ${diff.inHours}h';
    if (diff.inDays < 7) return 'Fa ${diff.inDays} dies';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(
        activityId: activity.id,
        currentUserId: currentUserId,
        currentUserName:
            context.read<AuthViewModel>().currentUser?.displayName ??
                'Usuari',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = activity.isLikedBy(currentUserId);
    final isOwner = activity.userId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                activity.userName[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(activity.userName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatDate(activity.createdAt)),
            trailing: isOwner
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar activitat'),
                          content: const Text(
                              'Estàs segur que vols eliminar aquesta activitat?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel·lar'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        context
                            .read<FeedViewModel>()
                            .deleteActivity(activity.id);
                      }
                    },
                  )
                : null,
          ),

          // Cim assolit + esport
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('🏔️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity.summitName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text('${activity.altitude}m · Assolit ✅',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (activity.sport != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(activity.sport!.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            activity.sport!.label,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Títol
          if (activity.title != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                activity.title!,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),

          // Foto
          if (activity.photoUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  activity.photoUrl!,
                  fit: BoxFit.cover,
                  height: 200,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.green)),
                    );
                  },
                ),
              ),
            ),

          // Descripció
          if (activity.description != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Text(activity.description!),
            ),

          // Etiquetes
          if (activity.taggedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: activity.taggedUsers.map((user) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      '@${user['name']}',
                      style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Accions
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    final authViewModel = context.read<AuthViewModel>();
                    context.read<FeedViewModel>().toggleLike(
                          activity.id,
                          currentUserId,
                          authViewModel.currentUser?.displayName ??
                              'Usuari',
                        );
                  },
                ),
                Text('${activity.likesCount}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),

                // Comentaris
                IconButton(
                  icon: const Icon(Icons.comment_outlined,
                      color: Colors.grey),
                  onPressed: () => _showComments(context),
                ),
                Text('${activity.commentsCount}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String activityId;
  final String currentUserId;
  final String currentUserName;

  const _CommentsSheet({
    required this.activityId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final ActivityRepository _repository = ActivityRepository();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    final comment = CommentModel(
      id: '',
      userId: widget.currentUserId,
      userName: widget.currentUserName,
      text: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    await _repository.addComment(widget.activityId, comment);
    _commentController.clear();
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text('Comentaris',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _repository.getComments(widget.activityId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Colors.green));
                }
                final comments = snapshot.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('Sigues el primer en comentar!',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 16,
                        child: Text(
                          comment.userName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(comment.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: Text(comment.text),
                    );
                  },
                );
              },
            ),
          ),

          // Camp de comentari
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Escriu un comentari...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.green))
                      : const Icon(Icons.send, color: Colors.green),
                  onPressed: _isSending ? null : _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}