import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen'), centerTitle: false),
      body: ListView(
        children: [
          const _SectionHeader(label: 'Synchronisatie'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined, color: kColorTeal),
            title: const Text('WebDAV configureren'),
            subtitle: const Text(
              'Verbind met een Nextcloud- of WebDAV-server',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Komt binnenkort beschikbaar.')),
            ),
          ),
          const _SectionHeader(label: 'Over'),
          ListTile(
            leading: const Icon(Icons.info_outline, color: kColorWarmGrey),
            title: const Text('Kinetic Link'),
            subtitle: const Text('Versie 2.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: kColorWarmGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
