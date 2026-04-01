import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'db/app_database.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/webdav_config_repository.dart';
import 'task/screens/kids_home_screen.dart';
import 'task/services/kids_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDb = AppDatabase();
  runApp(KineticKidsApp(appDb: appDb));
}

class KineticKidsApp extends StatelessWidget {
  final AppDatabase appDb;

  const KineticKidsApp({super.key, required this.appDb});

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
      home: _KidsAppShell(appDb: appDb),
    );
  }
}

/// Shell widget that loads WebDAV config and wires up sync.
class _KidsAppShell extends StatefulWidget {
  final AppDatabase appDb;

  const _KidsAppShell({required this.appDb});

  @override
  State<_KidsAppShell> createState() => _KidsAppShellState();
}

class _KidsAppShellState extends State<_KidsAppShell>
    with WidgetsBindingObserver {
  late final KidsTaskRepository _repository;
  KidsSyncOrchestrator? _orchestrator;

  @override
  void initState() {
    super.initState();
    _repository = KidsTaskRepository(db: widget.appDb);
    WidgetsBinding.instance.addObserver(this);
    _initSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _orchestrator?.sync();
    }
  }

  Future<void> _initSync() async {
    final store = FlutterSecureKeyValueStore();
    final configRepo = WebDavConfigRepository(store);
    final config = await configRepo.load();
    if (config != null && mounted) {
      setState(() {
        _orchestrator = KidsSyncOrchestrator(
          db: widget.appDb,
          repo: _repository,
          config: config,
        );
      });
      unawaited(_orchestrator!.sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    return KidsHomeScreen(
      appDb: widget.appDb,
      repository: _repository,
      orchestrator: _orchestrator,
    );
  }
}

void unawaited(Future<void> future) {
  future.ignore();
}
