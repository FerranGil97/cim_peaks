import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import 'summit_detail_view.dart';
import 'add_summit_view.dart';
import 'nearby_summits_view.dart';

class SummitListView extends StatefulWidget {
  const SummitListView({super.key});

  @override
  State<SummitListView> createState() => _SummitListViewState();
}

class _SummitListViewState extends State<SummitListView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SortOrder _sortOrder = SortOrder.altitudeDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SummitModel> _getFilteredSummits(List<SummitModel> allSummits) {
    var results = allSummits.where((summit) {
      if (_searchQuery.isEmpty) return true;
      return summit.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortOrder) {
      case SortOrder.altitudeDesc:
        results.sort((a, b) => b.altitude.compareTo(a.altitude));
      case SortOrder.altitudeAsc:
        results.sort((a, b) => a.altitude.compareTo(b.altitude));
      case SortOrder.nameAsc:
        results.sort((a, b) => a.name.compareTo(b.name));
    }

    return results;
  }

  void _showRandomSummitPicker(BuildContext context) {
    final summitViewModel = context.read<SummitViewModel>();
    final allSummits = summitViewModel.allSummits;

    final comarques = allSummits
        .where((s) => s.massif != null && s.massif!.isNotEmpty)
        .map((s) => s.massif!)
        .toSet()
        .toList()
      ..sort();

    int? minAltitude;
    int? maxAltitude;
    String? selectedComarca;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Text('🎲', style: TextStyle(fontSize: 28)),
                    SizedBox(width: 8),
                    Text(
                      'Cim sorpresa!',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aplica filtres opcionals i et suggerirem un cim aleatori',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                const Text('Altitud mínima',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _altChip('Qualsevol', minAltitude == null,
                        () => setModalState(() => minAltitude = null)),
                    _altChip('500m', minAltitude == 500,
                        () => setModalState(() => minAltitude = 500)),
                    _altChip('1.000m', minAltitude == 1000,
                        () => setModalState(() => minAltitude = 1000)),
                    _altChip('1.500m', minAltitude == 1500,
                        () => setModalState(() => minAltitude = 1500)),
                    _altChip('2.000m', minAltitude == 2000,
                        () => setModalState(() => minAltitude = 2000)),
                    _altChip('2.500m', minAltitude == 2500,
                        () => setModalState(() => minAltitude = 2500)),
                    _altChip('3.000m', minAltitude == 3000,
                        () => setModalState(() => minAltitude = 3000)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Altitud màxima',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _altChip('Qualsevol', maxAltitude == null,
                        () => setModalState(() => maxAltitude = null)),
                    _altChip('1.000m', maxAltitude == 1000,
                        () => setModalState(() => maxAltitude = 1000)),
                    _altChip('1.500m', maxAltitude == 1500,
                        () => setModalState(() => maxAltitude = 1500)),
                    _altChip('2.000m', maxAltitude == 2000,
                        () => setModalState(() => maxAltitude = 2000)),
                    _altChip('2.500m', maxAltitude == 2500,
                        () => setModalState(() => maxAltitude = 2500)),
                    _altChip('3.000m', maxAltitude == 3000,
                        () => setModalState(() => maxAltitude = 3000)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Comarca (opcional)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedComarca,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    hintText: 'Totes les comarques',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Totes les comarques'),
                    ),
                    ...comarques.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (value) =>
                      setModalState(() => selectedComarca = value),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _findRandomSummit(
                      context,
                      allSummits: allSummits,
                      minAltitude: minAltitude,
                      maxAltitude: maxAltitude,
                      comarca: selectedComarca,
                    );
                  },
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  label: const Text('Trobar cim sorpresa!',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _altChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: selected ? Colors.green : Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 12,
        ),
      ),
    );
  }

  void _findRandomSummit(
    BuildContext context, {
    required List<SummitModel> allSummits,
    int? minAltitude,
    int? maxAltitude,
    String? comarca,
  }) {
    var candidates = allSummits.where((summit) {
      if (minAltitude != null && summit.altitude < minAltitude) return false;
      if (maxAltitude != null && summit.altitude > maxAltitude) return false;
      if (comarca != null && summit.massif != comarca) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('😅 Cap resultat'),
          content: const Text(
              'No hi ha cims amb aquests filtres. Prova amb altres criteris.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entès'),
            ),
          ],
        ),
      );
      return;
    }

    candidates.shuffle();
    final randomSummit = candidates.first;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Text('🎲', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('El teu cim sorpresa!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              randomSummit.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${randomSummit.altitude}m',
              style: const TextStyle(fontSize: 18, color: Colors.green),
            ),
            if (randomSummit.massif != null) ...[
              const SizedBox(height: 4),
              Text('📍 ${randomSummit.massif}',
                  style: const TextStyle(color: Colors.grey)),
            ],
            if (randomSummit.province != null)
              Text('🏛️ ${randomSummit.province}',
                  style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'De ${candidates.length} cims possibles amb els teus filtres',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Tornar a tirar amb els mateixos filtres
              Future.delayed(const Duration(milliseconds: 200), () {
                if (context.mounted) {
                  _findRandomSummit(
                    context,
                    allSummits: allSummits,
                    minAltitude: minAltitude,
                    maxAltitude: maxAltitude,
                    comarca: comarca,
                  );
                }
              });
            },
            child: const Text('🎲 Tornar a tirar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Future.delayed(const Duration(milliseconds: 200), () {
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SummitDetailView(summit: randomSummit),
                    ),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Veure detalls'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summitViewModel = context.watch<SummitViewModel>();
    final filtered = _getFilteredSummits(summitViewModel.allSummits);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tots els cims'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.near_me),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NearbySummitsView()),
            ),
            tooltip: 'Cims a prop',
          ),
          IconButton(
            icon: const Text('🎲', style: TextStyle(fontSize: 22)),
            onPressed: () => _showRandomSummitPicker(context),
            tooltip: 'Cim sorpresa!',
          ),
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort),
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: SortOrder.altitudeDesc,
                child: Text('Altitud (major a menor)'),
              ),
              const PopupMenuItem(
                value: SortOrder.altitudeAsc,
                child: Text('Altitud (menor a major)'),
              ),
              const PopupMenuItem(
                value: SortOrder.nameAsc,
                child: Text('Nom (A-Z)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSummitView()),
        ),
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Proposar nou cim',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Barra de cerca
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cim...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value),
            ),
          ),

          // Comptador
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  _searchQuery.isEmpty
                      ? '${filtered.length} cims'
                      : '${filtered.length} resultats',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _sortOrderLabel(_sortOrder),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),

          // Llista
          Expanded(
            child: summitViewModel.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.green))
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No s\'han trobat cims',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final summit = filtered[index];
                          return _SummitListTile(summit: summit);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _sortOrderLabel(SortOrder order) {
    return switch (order) {
      SortOrder.altitudeDesc => '↓ Altitud',
      SortOrder.altitudeAsc => '↑ Altitud',
      SortOrder.nameAsc => 'A-Z',
    };
  }
}

enum SortOrder { altitudeDesc, altitudeAsc, nameAsc }

class _SummitListTile extends StatelessWidget {
  final SummitModel summit;

  const _SummitListTile({required this.summit});

  Color _statusColor(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => Colors.green,
      SummitStatus.saved => Colors.orange,
      SummitStatus.pending => Colors.grey[350]!,
    };
  }

  String _statusEmoji(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => '✅',
      SummitStatus.saved => '⭐',
      SummitStatus.pending => '🔘',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SummitDetailView(summit: summit),
        ),
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _statusColor(summit.status).withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: _statusColor(summit.status)),
        ),
        child: Center(
          child: Text(
            _statusEmoji(summit.status),
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      title: Text(
        summit.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${summit.altitude}m${summit.province != null ? ' · ${summit.province}' : ''}${summit.massif != null ? ' · ${summit.massif}' : ''}',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}