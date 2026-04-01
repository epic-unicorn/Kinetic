import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KineticKidsApp());
}

class KineticKidsApp extends StatelessWidget {
  const KineticKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFE7BB41); // Gold color for kids
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Kinetic Kids',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surfaceContainerLow,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          backgroundColor: colorScheme.surface,
        ),
      ),
      home: const KidsHomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Kids home screen � standalone mode (no sync in v2).
// Tasks will be pushed from the parent app in a future phase.
// ---------------------------------------------------------------------------

class KidsHomeScreen extends StatelessWidget {
  const KidsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mijn Opdrachten')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Alles klaar!',
              style: textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Geen opdrachten op dit moment.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
