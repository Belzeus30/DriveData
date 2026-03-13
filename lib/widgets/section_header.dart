import 'package:flutter/material.dart';

/// Sdílený widget pro nadpisy sekcí s ikonkou v barevném kruhu.
///
/// Používá se místo holých bold textů pro vizuální hierarchii sekcí.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.emoji,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  }) : assert(icon != null || emoji != null, 'Zadej icon nebo emoji');

  final String title;
  final IconData? icon;
  final String? emoji;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 16, color: cs.onPrimaryContainer)
                : Text(emoji!, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
