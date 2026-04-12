import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/business_model.dart';

class BusinessDetailView extends StatelessWidget {
  final BusinessModel business;

  const BusinessDetailView({super.key, required this.business});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header amb foto
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.green,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                business.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: business.photoUrl != null
                  ? Image.network(business.photoUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          business.type.emoji,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tipus, comarca i badge Pro
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          '${business.type.emoji} ${business.type.label}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (business.comarca != null)
                        Text(business.comarca!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      const Spacer(),
                      if (business.isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber[400]!),
                          ),
                          child: const Text('⭐ Partner Pro',
                              style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating
                  if (business.rating != null)
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < business.rating!.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${business.rating!.toStringAsFixed(1)} · ${business.reviewsCount} valoracions',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Descripció
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sobre nosaltres',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(business.description),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Serveis i preus
                  if (business.services.isNotEmpty) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Serveis i preus',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 12),
                            ...business.services.map((service) =>
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(service.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            if (service.description !=
                                                null)
                                              Text(
                                                service.description!,
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (service.price != null)
                                        Text(
                                          '${service.price!.toStringAsFixed(0)}€${service.priceUnit != null ? '/${service.priceUnit}' : ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                        ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Contacte
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contacte',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          if (business.address != null)
                            _contactRow(
                                Icons.location_on, business.address!,
                                null),
                          if (business.phone != null)
                            _contactRow(Icons.phone, business.phone!,
                                () => _launchPhone(business.phone!)),
                          if (business.email != null)
                            _contactRow(Icons.email, business.email!,
                                () => _launchEmail(business.email!)),
                          if (business.website != null)
                            _contactRow(Icons.language,
                                business.website!,
                                () => _launchUrl(business.website!)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botó de contacte principal
                  if (business.phone != null)
                    ElevatedButton.icon(
                      onPressed: () => _launchPhone(business.phone!),
                      icon: const Icon(Icons.phone),
                      label: const Text('Trucar ara'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  if (business.email != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _launchEmail(business.email!),
                      icon: const Icon(Icons.email),
                      label: const Text('Enviar correu'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  if (business.website != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _launchUrl(business.website!),
                      icon: const Icon(Icons.language),
                      label: const Text('Visitar web'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: onTap != null ? Colors.blue : Colors.black,
                  decoration: onTap != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}