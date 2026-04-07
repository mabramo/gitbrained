import 'package:flutter/material.dart';

class BreadcrumbBar extends StatelessWidget {
  final String path;
  final void Function(String path) onTap;

  const BreadcrumbBar({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final segments = path.isEmpty ? [] : path.split('/');

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(100), width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _crumb(
            context,
            label: 'root',
            path: '',
            isLast: segments.isEmpty,
          ),
          for (var i = 0; i < segments.length; i++) ...[
            Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant),
            _crumb(
              context,
              label: segments[i],
              path: segments.sublist(0, i + 1).join('/'),
              isLast: i == segments.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _crumb(
    BuildContext context, {
    required String label,
    required String path,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: isLast ? null : () => onTap(path),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isLast ? cs.onSurface : cs.primary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
