import 'package:flutter/material.dart';

// Placeholder for Phase 11 - will be replaced with full partner
// sync via WebDAV once packages/webdav is implemented.
class PartnerScreen extends StatelessWidget {
  const PartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Partner',
              style: TextStyle(color: Colors.white38, fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Beschikbaar nadat WebDAV is geconfigureerd.',
              style: TextStyle(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
