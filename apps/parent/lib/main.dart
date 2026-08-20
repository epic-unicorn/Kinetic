import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'db/app_database.dart';
import 'notifications/notification_service.dart';
import 'partner/services/partner_proposal_repository.dart';
import 'settings/settings_repository.dart';
import 'settings/settings_screen.dart';
import 'support/parent_notification_service.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/webdav_config_repository.dart';
import 'theme/app_themes.dart';
import 'todo/screens/notes_screen.dart';
import 'todo/screens/tasks_screen.dart';
import 'todo/services/ai_suggestion_engine.dart';
import 'todo/services/ai_suggestion_repository.dart';
import 'todo/services/note_repository.dart';
import 'todo/services/todo_repository.dart';
import 'vault/vault_gate.dart';

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
          home: VaultGate(
            db: db,
            settingsRepo: settingsRepo,
            readyBuilder: (context) =>
                _RootShell(db: db, settingsRepo: settingsRepo),
          ),
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
  late final WebDavConfigRepository _webDavConfig;
  late final AiSuggestionRepository _aiSuggestionRepository;
  AiSuggestionEngine? _aiSuggestionEngine;
  SyncOrchestrator? _syncOrchestrator;
  final syncStatus = ValueNotifier<SyncStatus>(SyncStatus.idle);
  final partnerPaired = ValueNotifier<bool>(false);
  final enrolledKidsCount = ValueNotifier<int>(0);
  final webDavConfigured = ValueNotifier<bool>(false);

  /// Incremented after every successful sync — lets the Kinderen tab reload.
  final _syncDoneCount = ValueNotifier<int>(0);

  /// False when the user has permanently blocked notifications in system settings.
  final notificationsEnabled = ValueNotifier<bool>(true);

  /// False when the Alarms & Reminders permission is not granted (Android 12+).
  final exactAlarmsGranted = ValueNotifier<bool>(true);

  /// Non-null when notification plugin initialization failed.
  final notifInitError = ValueNotifier<String?>(null);
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

    _aiSuggestionRepository = AiSuggestionRepository(widget.db);

    _initSync();
    // Request notification permissions immediately so the Android dialog
    // is shown on first launch rather than waiting for the first reminder.
    _notifSvc.init().then((_) => _checkNotificationPermission()).catchError((
      Object e,
      StackTrace st,
    ) {
      // Store error — visible in both debug and release via the banner.
      final svc = _notifSvc;
      if (svc is ParentNotificationService && svc.initError != null) {
        if (mounted) notifInitError.value = svc.initError.toString();
      } else {
        if (mounted) notifInitError.value = e.toString();
      }
    });
  }

  Future<void> _checkNotificationPermission() async {
    final enabled = await _notifSvc.areNotificationsEnabled();
    final exact = await _notifSvc.canScheduleExactAlarms();
    if (mounted) {
      notificationsEnabled.value = enabled;
      exactAlarmsGranted.value = exact;
    }
  }

  Future<void> _initSync() async {
    final config = await _webDavConfig.load();
    final isPaired = await _webDavConfig.isPartnerPaired();
    final kidsCount = (await _webDavConfig.loadEnrolledKids()).length;

    // Create the orchestrator FIRST so that when the ValueNotifiers below
    // trigger a rebuild, _syncOrchestrator!.config already contains the
    // updated config (including the family key for enrolled kids).
    if (config != null) {
      _syncOrchestrator = SyncOrchestrator(
        db: widget.db,
        config: config,
        onDisconnectsDetected: _handleDisconnects,
      );
      webDavConfigured.value = true;
    } else {
      _syncOrchestrator = null;
      webDavConfigured.value = false;
      syncStatus.value = SyncStatus.idle;
    }

    // Set notifiers after the orchestrator is ready so any rebuild triggered
    // by these changes sees the correct config.
    partnerPaired.value = isPaired;
    enrolledKidsCount.value = kidsCount;

    if (config != null) _triggerSync(); // fire-and-forget initial sync

    // Rebuild engine whenever sync config changes (partner repo may be null initially).
    _aiSuggestionEngine = AiSuggestionEngine(
      db: widget.db,
      suggestionRepo: _aiSuggestionRepository,
      todoRepo: _todoRepository,
      proposalRepo: isPaired ? _proposalRepository : null,
      myParentId: config?.parentId,
    );
    unawaited(_aiSuggestionEngine!.runIfDue());
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
      syncStatus.value = SyncStatus.idle;
      _syncDoneCount.value++;
    } catch (e) {
      print('Sync error: $e');
      syncStatus.value = SyncStatus.error;
    }
  }

  void _scheduleDebouncedSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), _triggerSync);
  }

  /// Called after a backup is restored. Re-schedules all notifications and
  /// re-initialises sync so the restored config takes effect immediately.
  Future<void> _onRestoreComplete() async {
    await _todoRepository.rescheduleAllReminders();
    await _noteRepository.rescheduleAllReminders();
    await _initSync();
  }

  /// Called by [SyncOrchestrator] when disconnect tombstones are found.
  ///
  /// Updates the partner-paired and enrolled-kids notifiers so the UI reacts
  /// immediately without requiring the user to navigate away and back.
  Future<void> _handleDisconnects(List<String> disconnectedIds) async {
    final isPaired = await _webDavConfig.isPartnerPaired();
    final kids = await _webDavConfig.loadEnrolledKids();
    partnerPaired.value = isPaired;
    enrolledKidsCount.value = kids.length;
  }

  /// Trigger a sync whenever the app returns to the foreground.
  /// Also re-check notification permission — user may have toggled it in Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
      _checkNotificationPermission();
      unawaited(_aiSuggestionEngine?.runIfDue());
    }
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notificationsEnabled,
      builder: (context, notifEnabled, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: exactAlarmsGranted,
          builder: (context, exactEnabled, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: notifInitError,
              builder: (context, initErr, _) {
                return _buildShell(
                  context,
                  notifEnabled,
                  exactEnabled,
                  initErr,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShell(
    BuildContext context,
    bool notifEnabled,
    bool exactEnabled,
    String? initErr,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: partnerPaired,
      builder: (context, paired, _) {
        return ValueListenableBuilder<int>(
          valueListenable: enrolledKidsCount,
          builder: (context, kidsCount, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: webDavConfigured,
              builder: (context, hasWebDav, _) {
                final screens = <Widget>[
                  TasksScreen(
                    repo: _todoRepository,
                    settingsRepo: widget.settingsRepo,
                    proposalRepo: paired ? _proposalRepository : null,
                    suggestionRepo: _aiSuggestionRepository,
                    myParentId: _syncOrchestrator?.parentId,
                    syncStatus: hasWebDav ? syncStatus : null,
                    hasFamilyKey: paired || kidsCount > 0,
                    partnerPaired: paired,
                    onSyncRetry: _triggerSync,
                    configRepo: _webDavConfig,
                    enrolledKidsCount: kidsCount,
                    syncDoneCount: _syncDoneCount,
                    syncConfig: _syncOrchestrator?.config,
                    pullPresence: _syncOrchestrator?.pullPresence,
                  ),
                  NotesScreen(
                    repo: _noteRepository,
                    settingsRepo: widget.settingsRepo,
                    onSyncRetry: _triggerSync,
                    syncStatus: hasWebDav ? syncStatus : null,
                    partnerPaired: paired,
                  ),
                  SettingsScreen(
                    db: widget.db,
                    configRepo: _webDavConfig,
                    settingsRepo: widget.settingsRepo,
                    syncOrchestrator: _syncOrchestrator,
                    onConfigSaved: _initSync,
                    onRestoreComplete: _onRestoreComplete,
                  ),
                ];

                const destinations = <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.check_circle_outline),
                    selectedIcon: Icon(Icons.check_circle),
                    label: 'Taken',
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
                ];

                final clampedIndex = _selectedIndex.clamp(
                  0,
                  screens.length - 1,
                );

                return Scaffold(
                  body: Column(
                    children: [
                      if (initErr != null)
                        MaterialBanner(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          content: Text(
                            'Meldingenservice kon niet starten: $initErr',
                          ),
                          leading: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => notifInitError.value = null,
                              child: const Text('Sluiten'),
                            ),
                          ],
                        ),
                      if (!notifEnabled)
                        MaterialBanner(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          content: const Text(
                            'Meldingen zijn uitgeschakeld. Zet ze aan in Instellingen om herinneringen te ontvangen.',
                          ),
                          leading: const Icon(Icons.notifications_off_outlined),
                          actions: [
                            TextButton(
                              onPressed: () {
                                const channel = MethodChannel(
                                  'net.moonbaseone.kinetic.parent/settings',
                                );
                                channel
                                    .invokeMethod<void>(
                                      'openNotificationSettings',
                                    )
                                    .catchError((_) {});
                              },
                              child: const Text('Instellingen'),
                            ),
                          ],
                        ),
                      if (notifEnabled && !exactEnabled)
                        MaterialBanner(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          content: const Text(
                            'Precieze herinneringen zijn uitgeschakeld. Sta "Alarmen & herinneringen" toe voor exacte tijden.',
                          ),
                          leading: const Icon(Icons.alarm_off_outlined),
                          actions: [
                            TextButton(
                              onPressed: () {
                                const channel = MethodChannel(
                                  'net.moonbaseone.kinetic.parent/settings',
                                );
                                channel
                                    .invokeMethod<void>(
                                      'openExactAlarmSettings',
                                    )
                                    .catchError((_) {});
                              },
                              child: const Text('Instellingen'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: clampedIndex,
                          children: screens,
                        ),
                      ),
                    ],
                  ),
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
