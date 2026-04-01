import 'package:flutter/material.dart';

// Placeholder for Phase 11 - will be replaced with full partner
// sync via WebDAV once packages/webdav is implemented.
class PartnerScreen extends StatelessWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Partner',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Beschikbaar nadat WebDAV is geconfigureerd.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
