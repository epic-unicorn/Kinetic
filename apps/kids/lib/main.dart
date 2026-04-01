import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KineticKidsApp());
}

class KineticKidsApp extends StatelessWidget {
  const KineticKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetic Kids',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE7BB41),
          brightness: Brightness.dark,
        ),
      ),
      home: const KidsHomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Kids home screen — standalone mode (no sync in v2).
// Tasks will be pushed from the parent app in a future phase.
// ---------------------------------------------------------------------------

class KidsHomeScreen extends StatelessWidget {
  const KidsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijn Opdrachten'), centerTitle: true),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 64, color: Color(0xFFE7BB41)),
            SizedBox(height: 16),
            Text(
              'Alles klaar!',
              style: TextStyle(
                color: Color(0xFFE7BB41),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Geen opdrachten op dit moment.',
              style: TextStyle(color: Color(0xFFD3D0CB)),
            ),
          ],
        ),
      ),
    );
  }
}
