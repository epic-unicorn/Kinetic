import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'db/app_database.dart';
import 'notifications/notification_service.dart';
import 'partner/screens/partner_screen.dart';
import 'settings/settings_screen.dart';
import 'support/parent_notification_service.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/webdav_config_repository.dart';
import 'todo/screens/tasks_screen.dart';
import 'todo/services/todo_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KineticParentApp());
}

class KineticParentApp extends StatelessWidget {
  const KineticParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetic Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF44BBA4),
          brightness: Brightness.dark,
        ),
      ),
      home: const _RootShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Root Shell — bottom-nav scaffold shared by all top-level screens.
// ---------------------------------------------------------------------------

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> with WidgetsBindingObserver {
  late final AppDatabase _db;
  late final NotificationService _notifSvc;
  late final TodoRepository _todoRepository;
  late final WebDavConfigRepository _webDavConfig;
  SyncOrchestrator? _syncOrchestrator;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _db = AppDatabase();
    _notifSvc = ParentNotificationService();
    _todoRepository = TodoRepository(db: _db, notifications: _notifSvc);
    _webDavConfig = WebDavConfigRepository(FlutterSecureKeyValueStore());
    _initSync();
  }

  Future<void> _initSync() async {
    final config = await _webDavConfig.load();
    if (config != null) {
      _syncOrchestrator = SyncOrchestrator(db: _db, config: config);
      _syncOrchestrator!.sync(); // fire-and-forget initial sync
    }
  }

  /// Trigger a sync whenever the app returns to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncOrchestrator?.sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TasksScreen(repo: _todoRepository),
      const PartnerScreen(),
      const _NotesPlaceholder(),
      SettingsScreen(configRepo: _webDavConfig),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Taken',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Partner',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_outlined),
            selectedIcon: Icon(Icons.note),
            label: 'Notities',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Instellingen',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes placeholder — replaced in Phase 10.
// ---------------------------------------------------------------------------

class _NotesPlaceholder extends StatelessWidget {
  const _NotesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_outlined, size: 56, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Notities',
              style: TextStyle(color: Colors.white38, fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Komt binnenkort beschikbaar.',
              style: TextStyle(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
