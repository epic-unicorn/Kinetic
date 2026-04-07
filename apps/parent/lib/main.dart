import 'dart:async';

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
final themeNotifier = ValueNotifier<AppTheme>(AppTheme.light);

enum SyncStatus { idle, syncing, error }

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
  final syncStatus = ValueNotifier<SyncStatus>(SyncStatus.idle);
  final hasFamilyKey = ValueNotifier<bool>(false);
  final webDavConfigured = ValueNotifier<bool>(false);
  final pendingProposalCount = ValueNotifier<int>(0);
  StreamSubscription<int>? _proposalCountSub;
  Timer? _syncDebounce;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifSvc = ParentNotificationService();
    _todoRepository = TodoRepository(
      db: widget.db,
      notifications: _notifSvc,
      onWrite: _scheduleDebouncedSync,
    );
    _noteRepository = NoteRepository(
      db: widget.db,
      notifications: _notifSvc,
      onWrite: _scheduleDebouncedSync,
    );
    _proposalRepository = PartnerProposalRepository(
      db: widget.db,
      todoRepository: _todoRepository,
    );
    _webDavConfig = WebDavConfigRepository(FlutterSecureKeyValueStore());

    // Subscribe to the pending count so the nav badge stays live.
    _proposalCountSub = _proposalRepository.watchPendingCount().listen(
      (count) => pendingProposalCount.value = count,
    );

    // Initialize load repository (service will be set later in _initSync)
    _loadRepository = PartnerLoadRepository(db: widget.db);

    _initSync();
    // Request notification permissions immediately so the Android dialog
    // is shown on first launch rather than waiting for the first reminder.
    unawaited(_notifSvc.init());
  }

  Future<void> _initSync() async {
    final config = await _webDavConfig.load();
    hasFamilyKey.value = config?.familyKeyBytes != null;
    if (config != null) {
      _syncOrchestrator = SyncOrchestrator(db: widget.db, config: config);
      webDavConfigured.value = true;

      // Re-subscribe badge count with myParentId so own outgoing proposals
      // are excluded from the count.
      _proposalCountSub?.cancel();
      _proposalCountSub = _proposalRepository
          .watchPendingCount(myParentId: config.parentId)
          .listen((count) => pendingProposalCount.value = count);
      // Initialize partner load service using the same config
      final client = WebDavClient(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
      );
      final webdavService = WebDavSyncService(client: client, config: config);
      final analyzer = LoadAnalyzer(db: widget.db);
      final loadService = LoadSyncService(
        service: webdavService,
        analyzer: analyzer,
      );
      _loadRepository.setLoadService(loadService);
      // Note: client is kept alive for the duration of the app lifecycle
      // It will be cleaned up when the app terminates

      _triggerSync(); // fire-and-forget initial sync
    } else {
      _syncOrchestrator = null;
      webDavConfigured.value = false;
      syncStatus.value = SyncStatus.idle;
    }
  }

  Future<void> _triggerSync() async {
    if (_syncOrchestrator == null) return;
    syncStatus.value = SyncStatus.syncing;
    try {
      // Set timeout of 30 seconds for sync operations
      await _syncOrchestrator!.sync().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Sync operation timed out after 30 seconds'),
      );
      // Refresh load metrics in the UI after successful sync
      if (_syncOrchestrator != null) {
        unawaited(_loadRepository.refreshFamilyLoad());
      }
      syncStatus.value = SyncStatus.idle;
    } catch (e) {
      print('Sync error: $e');
      syncStatus.value = SyncStatus.error;
    }
  }

  void _scheduleDebouncedSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), _triggerSync);
  }

  /// Trigger a sync whenever the app returns to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
    }
  }

  @override
  void dispose() {
    _proposalCountSub?.cancel();
    _syncDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hasFamilyKey,
      builder: (context, paired, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: webDavConfigured,
          builder: (context, hasWebDav, _) {
            return ValueListenableBuilder<int>(
              valueListenable: pendingProposalCount,
              builder: (context, pendingCount, _) {
                final screens = <Widget>[
                  TasksScreen(
                    repo: _todoRepository,
                    settingsRepo: widget.settingsRepo,
                    proposalRepo: paired ? _proposalRepository : null,
                    myParentId: _syncOrchestrator?.parentId,
                    syncStatus: hasWebDav ? syncStatus : null,
                    hasFamilyKey: paired,
                    onSyncRetry: _triggerSync,
                  ),
                  if (paired)
                    PartnerScreen(
                      proposalRepository: _proposalRepository,
                      loadRepository: _loadRepository,
                      myParentId: _syncOrchestrator?.username,
                    ),
                  NotesScreen(
                    repo: _noteRepository,
                    settingsRepo: widget.settingsRepo,
                    onSyncRetry: _triggerSync,
                    syncStatus: hasWebDav ? syncStatus : null,
                    hasFamilyKey: hasFamilyKey,
                  ),
                  SettingsScreen(
                    db: widget.db,
                    configRepo: _webDavConfig,
                    settingsRepo: widget.settingsRepo,
                    onConfigSaved: _initSync,
                  ),
                ];

                final destinations = <NavigationDestination>[
                  const NavigationDestination(
                    icon: Icon(Icons.check_circle_outline),
                    selectedIcon: Icon(Icons.check_circle),
                    label: 'Taken',
                  ),
                  if (paired)
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: pendingCount > 0,
                        label: Text('$pendingCount'),
                        child: const Icon(Icons.people_outline),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: pendingCount > 0,
                        label: Text('$pendingCount'),
                        child: const Icon(Icons.people),
                      ),
                      label: 'Partner',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.note_outlined),
                    selectedIcon: Icon(Icons.note),
                    label: 'Notities',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Instellingen',
                  ),
                ];

                // Clamp selected index in case the partner tab disappears
                final clampedIndex = _selectedIndex.clamp(
                  0,
                  screens.length - 1,
                );

                return Scaffold(
                  body: IndexedStack(index: clampedIndex, children: screens),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: clampedIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _selectedIndex = i),
                    destinations: destinations,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
