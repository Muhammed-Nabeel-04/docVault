import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../providers/providers.dart';

class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final categories = [null, ...DocumentCategory.values];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = selected == cat;
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
                  cat == null ? 'All' : cat.label,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            onSelected: (_) {
              ref.read(selectedCategoryProvider.notifier).state = cat;
              ref
                  .read(documentsProvider.notifier)
                  .filterByCategory(cat);
            },
            selectedColor: scheme.primaryContainer,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
