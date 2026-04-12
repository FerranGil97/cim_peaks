import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/business_model.dart';
import '../../viewmodels/business_viewmodel.dart';
import 'business_detail_view.dart';

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessViewModel>().loadBusinesses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessViewModel = context.watch<BusinessViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serveis'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de cerca
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar per nom o comarca...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          businessViewModel.setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: businessViewModel.setSearchQuery,
            ),
          ),

          // Filtres per tipus
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _typeChip(
                  context,
                  label: 'Tots',
                  emoji: '🔍',
                  selected: businessViewModel.selectedType == null,
                  onTap: () =>
                      businessViewModel.setTypeFilter(null),
                ),
                const SizedBox(width: 8),
                ...BusinessType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _typeChip(
                        context,
                        label: type.label,
                        emoji: type.emoji,
                        selected:
                            businessViewModel.selectedType == type,
                        onTap: () =>
                            businessViewModel.setTypeFilter(type),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Comptador
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${businessViewModel.businesses.length} serveis',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),

          // Llista d'empreses
          Expanded(
            child: businessViewModel.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.green))
                : businessViewModel.businesses.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No hi ha serveis disponibles',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text(
                              'Aviat podràs trobar allotjaments,\nguies i restaurants de muntanya aquí',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            businessViewModel.businesses.length,
                        itemBuilder: (context, index) {
                          final business =
                              businessViewModel.businesses[index];
                          return _BusinessCard(business: business);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(
    BuildContext context, {
    required String label,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final BusinessModel business;

  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BusinessDetailView(business: business),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto
            if (business.photoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: Image.network(
                  business.photoUrl!,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.grey),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: Container(
                  height: 100,
                  color: Colors.green[50],
                  child: Center(
                    child: Text(
                      business.type.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom i badge Pro
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      if (business.isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.amber[400]!),
                          ),
                          child: const Text(
                            '⭐ Pro',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Tipus i comarca
                  Row(
                    children: [
                      Text(
                        '${business.type.emoji} ${business.type.label}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      if (business.comarca != null) ...[
                        const Text(' · ',
                            style: TextStyle(color: Colors.grey)),
                        Text(
                          business.comarca!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Descripció
                  Text(
                    business.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Rating i serveis
                  Row(
                    children: [
                      if (business.rating != null) ...[
                        const Icon(Icons.star,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${business.rating!.toStringAsFixed(1)} (${business.reviewsCount})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (business.services.isNotEmpty)
                        Text(
                          '${business.services.length} servei${business.services.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}