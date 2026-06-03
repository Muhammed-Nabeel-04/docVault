import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../utils/app_router.dart';
import '../../widgets/document_card.dart';
import '../../widgets/category_filter_bar.dart';
import '../../widgets/empty_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);
    final expiring = ref.watch(expiringSoonProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('DocVault 🔐'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.search),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.settings),
              ),
            ],
          ),

          // ── Expiry banner ────────────────────────────────────────────
          expiring.when(
            data: (docs) {
              if (docs.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${docs.length} document${docs.length > 1 ? 's' : ''} expiring within 30 days',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Category filters ─────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CategoryFilterBar(),
            ),
          ),

          // ── Documents ────────────────────────────────────────────────
          docsAsync.when(
            data: (docs) {
              if (docs.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyState(
                    title: 'No documents yet',
                    subtitle: 'Tap + to add your first document',
                    icon: Icons.description_rounded,
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => DocumentCard(
                    document: docs[i],
                    index: i,
                    onStar: () => ref
                        .read(documentsProvider.notifier)
                        .toggleStar(docs[i].id!),
                    onDelete: () => _confirmDelete(
                        context, ref, docs[i].id!),
                  ),
                  childCount: docs.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRouter.addDocument);
          ref.read(documentsProvider.notifier).load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Document'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
            'This permanently deletes the document from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(documentsProvider.notifier)
                  .deleteDocument(docId);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
