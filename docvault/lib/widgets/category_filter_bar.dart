import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: categoriesAsync.when(
        data: (categories) {
          final items = [null, ...categories];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = items[i];
              final isSelected = selectedId == cat?.id;
              
              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cat != null) ...[
                      Text(cat.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      cat == null ? 'All' : cat.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                onSelected: (_) {
                  ref.read(selectedCategoryProvider.notifier).state = cat?.id;
                },
                selectedColor: scheme.primaryContainer,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
