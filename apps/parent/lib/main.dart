import 'package:flutter/material.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'db/app_database.dart';
import 'notifications/notification_service.dart';
import 'partner/screens/partner_screen.dart';
import 'partner/services/partner_load_repository.dart';
import 'partner/services/partner_proposal_repository.dart';
import 'partner/services/load_analyzer.dart';
import 'partner/services/load_sync_service.dart';
import 'settings/settings_repository.dart';
import 'settings/settings_screen.dart';
import 'support/parent_notification_service.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/webdav_config_repository.dart';
import 'theme/app_themes.dart';
import 'todo/screens/notes_screen.dart';
import 'todo/screens/tasks_screen.dart';
import 'todo/services/note_repository.dart';
import 'todo/services/todo_repository.dart';

// Global theme notifier — allows theme changes from anywhere in the app
final themeNotifier = ValueNotifier<AppTheme>(AppTheme.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted theme preference
  final db = AppDatabase();
  final settingsRepo = SettingsRepository(db: db);
  final savedTheme = await settingsRepo.loadTheme();
  themeNotifier.value = savedTheme;

  runApp(KineticParentApp(db: db, settingsRepo: settingsRepo));
}

class KineticParentApp extends StatelessWidget {
  final AppDatabase db;
  final SettingsRepository settingsRepo;

  const KineticParentApp({
    super.key,
    required this.db,
    required this.settingsRepo,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Kinetic Link',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(theme),
          home: _RootShell(db: db, settingsRepo: settingsRepo),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Root Shell — bottom-nav scaffold shared by all top-level screens.
// ---------------------------------------------------------------------------

class _RootShell extends StatefulWidget {
  final AppDatabase db;
  final SettingsRepository settingsRepo;

  const _RootShell({required this.db, required this.settingsRepo});

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> with WidgetsBindingObserver {
  late final NotificationService _notifSvc;
  late final TodoRepository _todoRepository;
  late final NoteRepository _noteRepository;
  late final PartnerProposalRepository _proposalRepository;
  late final PartnerLoadRepository _loadRepository;
  late final WebDavConfigRepository _webDavConfig;
  SyncOrchestrator? _syncOrchestrator;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifSvc = ParentNotificationService();
    _todoRepository = TodoRepository(db: widget.db, notifications: _notifSvc);
    _noteRepository = NoteRepository(db: widget.db, notifications: _notifSvc);
    _proposalRepository = PartnerProposalRepository(db: widget.db);
    _webDavConfig = WebDavConfigRepository(FlutterSecureKeyValueStore());
    
    // Initialize load repository (service will be set later in _initSync)
    _loadRepository = PartnerLoadRepository(db: widget.db);
    
    _initSync();
  }

  Future<void> _initSync() async {
    final config = await _webDavConfig.load();
    if (config != null) {
      _syncOrchestrator = SyncOrchestrator(db: widget.db, config: config);
      
      // Initialize partner load service using the same config
      final client = WebDavClient(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
      );
      final webdavService = WebDavSyncService(client: client, config: config);
      final analyzer = LoadAnalyzer(db: widget.db);
      final loadService = LoadSyncService(service: webdavService, analyzer: analyzer);
      _loadRepository.setLoadService(loadService);
      // Note: client is kept alive for the duration of the app lifecycle
      // It will be cleaned up when the app terminates
      
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
    widget.db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TasksScreen(repo: _todoRepository),
      PartnerScreen(
        proposalRepository: _proposalRepository,
        loadRepository: _loadRepository,
      ),
      NotesScreen(repo: _noteRepository),
      SettingsScreen(
        configRepo: _webDavConfig,
        settingsRepo: widget.settingsRepo,
      ),
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
