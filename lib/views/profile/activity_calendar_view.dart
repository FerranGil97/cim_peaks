import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ActivityCalendarView extends StatefulWidget {
  const ActivityCalendarView({super.key});

  @override
  State<ActivityCalendarView> createState() => _ActivityCalendarViewState();
}

class _ActivityCalendarViewState extends State<ActivityCalendarView> {
  final ActivityRepository _repository = ActivityRepository();
  List<ActivityModel> _activities = [];
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    _repository
        .getUserActivities(authViewModel.currentUser!.uid)
        .listen((activities) {
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    });
  }

  // Obtenir activitats d'un dia concret
  List<ActivityModel> _getActivitiesForDay(DateTime day) {
    return _activities.where((a) {
      return a.createdAt.year == day.year &&
          a.createdAt.month == day.month &&
          a.createdAt.day == day.day;
    }).toList();
  }

  // Obtenir activitats del mes actual
  Map<int, List<ActivityModel>> _getMonthActivities() {
    final map = <int, List<ActivityModel>>{};
    for (final activity in _activities) {
      if (activity.createdAt.year == _currentMonth.year &&
          activity.createdAt.month == _currentMonth.month) {
        final day = activity.createdAt.day;
        map[day] = [...(map[day] ?? []), activity];
      }
    }
    return map;
  }

  int get _totalActivities => _activities.length;

  int get _currentStreak {
    if (_activities.isEmpty) return 0;
    final sorted = _activities.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int streak = 0;
    DateTime? lastDate;

    for (final activity in sorted) {
      final actDate = DateTime(activity.createdAt.year,
          activity.createdAt.month, activity.createdAt.day);
      if (lastDate == null) {
        lastDate = actDate;
        streak = 1;
      } else {
        final diff = lastDate.difference(actDate).inDays;
        if (diff <= 7) {
          streak++;
          lastDate = actDate;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  void _showDayDetail(BuildContext context, DateTime day,
      List<ActivityModel> activities) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'ca').format(day),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ...activities.map((activity) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Center(
                      child: Text(
                        activity.sport?.emoji ?? '🏔️',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  title: Text(
                    activity.summitName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${activity.altitude}m · Assolit ✅'),
                      if (activity.sport != null)
                        Text(
                          activity.sport!.label,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                      if (activity.title != null)
                        Text(
                          '"${activity.title}"',
                          style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthActivities = _getMonthActivities();
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    // Dilluns = 0
    int startWeekday = firstDayOfMonth.weekday - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Les meves activitats'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          '🏔️',
                          '$_totalActivities',
                          'Activitats totals',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Calendari
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Navegació de mes
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => setState(() {
                                  _currentMonth = DateTime(
                                      _currentMonth.year,
                                      _currentMonth.month - 1);
                                }),
                              ),
                              Text(
                                DateFormat('MMMM yyyy', 'ca')
                                    .format(_currentMonth)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentMonth.year ==
                                            DateTime.now().year &&
                                        _currentMonth.month ==
                                            DateTime.now().month
                                    ? null
                                    : () => setState(() {
                                          _currentMonth = DateTime(
                                              _currentMonth.year,
                                              _currentMonth.month + 1);
                                        }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Dies de la setmana
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: ['Dl', 'Dt', 'Dc', 'Dj', 'Dv', 'Ds', 'Dg']
                                .map((d) => SizedBox(
                                      width: 36,
                                      child: Text(
                                        d,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),

                          // Graella del calendari
                          GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1,
                            ),
                            itemCount:
                                startWeekday + daysInMonth,
                            itemBuilder: (context, index) {
                              if (index < startWeekday) {
                                return const SizedBox();
                              }

                              final day = index - startWeekday + 1;
                              final date = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month,
                                  day);
                              final dayActivities =
                                  monthActivities[day] ?? [];
                              final hasActivity =
                                  dayActivities.isNotEmpty;
                              final isToday = date.year ==
                                      DateTime.now().year &&
                                  date.month == DateTime.now().month &&
                                  date.day == DateTime.now().day;
                              final isFuture =
                                  date.isAfter(DateTime.now());

                              return GestureDetector(
                                onTap: hasActivity
                                    ? () => _showDayDetail(
                                        context, date, dayActivities)
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: hasActivity
                                        ? Colors.black
                                        : isToday
                                            ? Colors.transparent
                                            : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: isToday
                                        ? Border.all(
                                            color: Colors.green,
                                            width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: hasActivity
                                        ? Text(
                                            dayActivities.first.sport
                                                    ?.emoji ??
                                                '🏔️',
                                            style: const TextStyle(
                                                fontSize: 18),
                                          )
                                        : Text(
                                            '$day',
                                            style: TextStyle(
                                              color: isFuture
                                                  ? Colors.grey[300]
                                                  : isToday
                                                      ? Colors.green
                                                      : Colors
                                                          .grey[600],
                                              fontSize: 13,
                                              fontWeight: isToday
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Llista d'activitats del mes
                  if (monthActivities.isNotEmpty) ...[
                    Text(
                      'Activitats del mes (${monthActivities.values.fold(0, (sum, list) => sum + list.length)})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...monthActivities.entries
                        .toList()
                        .reversed
                        .expand((entry) => entry.value)
                        .map((activity) => _activityListTile(activity)),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.terrain,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'No hi ha activitats aquest mes',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
      String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _activityListTile(ActivityModel activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Center(
            child: Text(
              activity.sport?.emoji ?? '🏔️',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          activity.summitName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${activity.altitude}m · ${DateFormat('d MMM yyyy', 'ca').format(activity.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: activity.title != null
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : null,
      ),
    );
  }
}