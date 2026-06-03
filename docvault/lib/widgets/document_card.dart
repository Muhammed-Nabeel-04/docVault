import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../models/category.dart';
import '../providers/providers.dart';
import '../utils/app_utils.dart';
import '../utils/app_router.dart';

class DocumentCard extends ConsumerWidget {
  final Document document;
  final VoidCallback? onStar;
  final VoidCallback? onDelete;
  final int index;

  const DocumentCard({
    super.key,
    required this.document,
    this.onStar,
    this.onDelete,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expired = AppUtils.isExpired(document.expiryDate);
    final expiringSoon =
        !expired && AppUtils.isExpiringSoon(document.expiryDate);

    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category = categories.firstWhere(
      (c) => c.id == document.categoryId,
      orElse: () => categories.isNotEmpty 
          ? categories.first 
          : Category(id: -1, name: 'Unknown', icon: '❓'),
    );

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRouter.viewDocument,
        arguments: document,
      ),
      onLongPress: () => _showOptions(context),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        category.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      if (document.files.length > 1)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 2),
                            ),
                            child: Text(
                              '${document.files.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expired)
                          _badge('Expired', Colors.red.shade100,
                              Colors.red.shade700)
                        else if (expiringSoon)
                          _badge(
                            AppUtils.daysUntilExpiry(document.expiryDate!),
                            Colors.orange.shade100,
                            Colors.orange.shade700,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.name}  ·  '
                      '${AppUtils.formatFileSize(document.files.isNotEmpty ? document.files.first.fileSizeBytes : 0)}  ·  '
                      '${AppUtils.timeAgo(document.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (document.note != null &&
                        document.note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        document.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (document.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: document.tags
                            .take(3)
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Star
              IconButton(
                icon: Icon(
                  document.isStarred
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: document.isStarred
                      ? Colors.amber
                      : scheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: onStar,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.04, end: 0, duration: 250.ms);
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  AppRouter.addDocument,
                  arguments: document,
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
