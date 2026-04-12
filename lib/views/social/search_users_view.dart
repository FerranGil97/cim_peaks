import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/social_viewmodel.dart';

class SearchUsersView extends StatefulWidget {
  const SearchUsersView({super.key});

  @override
  State<SearchUsersView> createState() => _SearchUsersViewState();
}

class _SearchUsersViewState extends State<SearchUsersView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialViewModel = context.watch<SocialViewModel>();
    final authViewModel = context.read<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar usuaris'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de cerca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar per nom d\'usuari...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          socialViewModel.searchUsers(
                              '', authViewModel.currentUser!.uid);
                        },
                      )
                    : null,
              ),
              onChanged: (value) => socialViewModel.searchUsers(
                  value, authViewModel.currentUser!.uid),
            ),
          ),

          // Resultats
          Expanded(
            child: socialViewModel.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green))
                : socialViewModel.searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Busca usuaris per nom'
                              : 'No s\'han trobat usuaris',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: socialViewModel.searchResults.length,
                        itemBuilder: (context, index) {
                          final user = socialViewModel.searchResults[index];
                          final userId = user['id'] as String;
                          final isFollowing =
                              socialViewModel.isFollowing(userId);

                          return ListTile(
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
                            trailing: ElevatedButton(
                              onPressed: () => socialViewModel.toggleFollow(
                                  authViewModel.currentUser!.uid, authViewModel.currentUser!.displayName, userId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? Colors.grey[200]
                                    : Colors.green,
                                foregroundColor: isFollowing
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              child: Text(
                                  isFollowing ? 'Seguint' : 'Seguir'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}