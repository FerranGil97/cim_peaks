import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ActivityCalendarView extends StatefulWidget {
  const ActivityCalendarView({super.key});

  @override
  State<ActivityCalendarView> createState() => _ActivityCalendarViewState();
}

class _ActivityCalendarViewState extends State<ActivityCalendarView> {
  List<SummitModel> _achievedSummits = [];
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAchievedSummits();
  }

  Future<void> _loadAchievedSummits() async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    final userId = authViewModel.currentUser!.uid;

    // Obtenir tots els cims assolits de l'usuari
    final userSummitsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .where('status', isEqualTo: 'achieved')
        .get();

    final summitIds = userSummitsSnapshot.docs.map((d) => d.id).toList();
    if (summitIds.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final userSummitsMap = {
      for (var doc in userSummitsSnapshot.docs) doc.id: doc.data()
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
        final summit = SummitModel.fromFirestore(data, doc.id);
        // Només afegir si té data d'assoliment
        if (summit.achievedAt != null) {
          summits.add(summit);
        }
      }
    }

    // Ordenar per data descendent
    summits.sort((a, b) => b.achievedAt!.compareTo(a.achievedAt!));

    setState(() {
      _achievedSummits = summits;
      _isLoading = false;
    });
  }

  // Obtenir cims assolits d'un dia concret
  List<SummitModel> _getSummitsForDay(DateTime day) {
    return _achievedSummits.where((s) {
      final d = s.achievedAt!;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  // Obtenir cims del mes actual agrupats per dia
  Map<int, List<SummitModel>> _getMonthSummits() {
    final map = <int, List<SummitModel>>{};
    for (final summit in _achievedSummits) {
      if (summit.achievedAt!.year == _currentMonth.year &&
          summit.achievedAt!.month == _currentMonth.month) {
        final day = summit.achievedAt!.day;
        map[day] = [...(map[day] ?? []), summit];
      }
    }
    return map;
  }

  int get _totalAchieved => _achievedSummits.length;

  void _showDayDetail(BuildContext context, DateTime day,
      List<SummitModel> summits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: summits.length <= 2 ? 0.4 : 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                DateFormat('EEEE, d MMMM yyyy', 'ca').format(day),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: summits.length,
                itemBuilder: (context, index) {
                  final summit = summits[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: const Center(
                        child: Text('🏔️',
                            style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    title: Text(
                      summit.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${summit.altitude}m · Assolit ✅'
                      '${summit.province != null ? ' · ${summit.province}' : ''}',
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

  @override
  Widget build(BuildContext context) {
    final monthSummits = _getMonthSummits();
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
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
                          '$_totalAchieved',
                          'Cims assolits',
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
                            itemCount: startWeekday + daysInMonth,
                            itemBuilder: (context, index) {
                              if (index < startWeekday) {
                                return const SizedBox();
                              }

                              final day = index - startWeekday + 1;
                              final date = DateTime(
                                  _currentMonth.year,
                                  _currentMonth.month,
                                  day);
                              final daySummits =
                                  monthSummits[day] ?? [];
                              final hasSummit = daySummits.isNotEmpty;
                              final isToday = date.year ==
                                      DateTime.now().year &&
                                  date.month == DateTime.now().month &&
                                  date.day == DateTime.now().day;
                              final isFuture =
                                  date.isAfter(DateTime.now());

                              return GestureDetector(
                                onTap: hasSummit
                                    ? () => _showDayDetail(
                                        context, date, daySummits)
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: hasSummit
                                        ? Colors.black
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: isToday
                                        ? Border.all(
                                            color: Colors.green,
                                            width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: hasSummit
                                        ? const Text('🏔️',
                                            style: TextStyle(fontSize: 18))
                                        : Text(
                                            '$day',
                                            style: TextStyle(
                                              color: isFuture
                                                  ? Colors.grey[300]
                                                  : isToday
                                                      ? Colors.green
                                                      : Colors.grey[600],
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

                  // Llista de cims del mes
                  if (monthSummits.isNotEmpty) ...[
                    Text(
                      'Cims del mes (${monthSummits.values.fold(0, (sum, list) => sum + list.length)})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...monthSummits.entries
                        .toList()
                        .reversed
                        .expand((entry) => entry.value)
                        .map((summit) => _summitListTile(summit)),
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
                              'Cap cim assolit aquest mes',
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

  Widget _summitListTile(SummitModel summit) {
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
          child: const Center(
            child: Text('🏔️', style: TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          summit.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${summit.altitude}m · ${DateFormat('d MMM yyyy', 'ca').format(summit.achievedAt!)}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}