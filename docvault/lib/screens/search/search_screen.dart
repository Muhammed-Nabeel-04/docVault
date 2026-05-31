import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../widgets/document_card.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search documents...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                      ref.read(documentsProvider.notifier).load();
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            ref.read(searchQueryProvider.notifier).state = v;
            ref.read(documentsProvider.notifier).search(v);
          },
        ),
      ),
      body: query.isEmpty
          ? const EmptyState(
              title: 'Search your documents',
              subtitle: 'Type a name, tag or note',
              icon: Icons.search_rounded,
            )
          : docsAsync.when(
              data: (docs) => docs.isEmpty
                  ? EmptyState(
                      title: 'No results for "$query"',
                      subtitle: 'Try a different keyword',
                      icon: Icons.search_off_rounded,
                    )
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) => DocumentCard(
                        document: docs[i],
                        index: i,
                        onStar: () => ref
                            .read(documentsProvider.notifier)
                            .toggleStar(docs[i].id!),
                      ),
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
    );
  }
}
