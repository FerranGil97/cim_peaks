import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/notification_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  @override
  void initState() {
    super.initState();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Fa ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Fa ${diff.inHours}h';
    if (diff.inDays < 7) return 'Fa ${diff.inDays} dies';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _notificationColor(NotificationType type) {
    return switch (type) {
      NotificationType.medal => Colors.amber,
      NotificationType.follow => Colors.blue,
      NotificationType.like => Colors.red,
      NotificationType.comment => Colors.green,
    };
  }

  @override
  Widget build(BuildContext context) {
    final notificationViewModel = context.watch<NotificationViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificacions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (notificationViewModel.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                final authViewModel = context.read<AuthViewModel>();
                notificationViewModel
                    .markAllAsRead(authViewModel.currentUser!.uid);
              },
              child: const Text('Llegir totes',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: notificationViewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green))
          : notificationViewModel.notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No tens notificacions',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notificationViewModel.notifications.length,
                  itemBuilder: (context, index) {
                    final notification =
                        notificationViewModel.notifications[index];
                    return Dismissible(
                      key: Key(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => notificationViewModel
                          .deleteNotification(notification.id),
                      child: Container(
                        color: notification.isRead
                            ? null
                            : Colors.green.withOpacity(0.05),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _notificationColor(notification.type)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(notification.icon,
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.body),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(notification.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => notificationViewModel
                              .markAsRead(notification.id),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}