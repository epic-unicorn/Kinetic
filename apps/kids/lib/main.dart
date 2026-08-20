import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'db/app_database.dart';
import 'enrollment/kids_enrollment_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'notifications/kids_notification_service.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/webdav_config_repository.dart';
import 'task/screens/kids_home_screen.dart';
import 'task/services/kids_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDb = AppDatabase();
  final notificationService = KidsNotificationService();
  await notificationService.initialize();
  runApp(KineticKidsApp(appDb: appDb, notificationService: notificationService));
}

class KineticKidsApp extends StatelessWidget {
  final AppDatabase appDb;
  final KidsNotificationService notificationService;

  const KineticKidsApp({
    super.key,
    required this.appDb,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFF97316); // Orange color from app icon
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Kinetic Kids',
      debugShowCheckedModeBanner: false,
      // Default to English; device Dutch no longer overrides.
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
      home: _KidsAppShell(appDb: appDb, notificationService: notificationService),
    );
  }
}

/// Shell widget that loads WebDAV config and wires up sync.
class _KidsAppShell extends StatefulWidget {
  final AppDatabase appDb;
  final KidsNotificationService notificationService;

  const _KidsAppShell({
    required this.appDb,
    required this.notificationService,
  });

  @override
  State<_KidsAppShell> createState() => _KidsAppShellState();
}

class _KidsAppShellState extends State<_KidsAppShell>
    with WidgetsBindingObserver {
  late final KidsTaskRepository _repository;
  KidsSyncOrchestrator? _orchestrator;
  bool _enrolled = false;
  bool _initDone = false;
  DateTime? _xpResetAt;

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
    final kidId = await configRepo.loadKidId() ?? '';
    // Restore any previously-received XP reset timestamp.
    final resetAtStr = await store.read(key: 'kinetic_xp_reset_at');
    final xpResetAt = resetAtStr != null ? DateTime.tryParse(resetAtStr) : null;
    if (!mounted) return;
    if (config != null) {
      setState(() {
        _enrolled = true;
        _initDone = true;
        _xpResetAt = xpResetAt;
        _orchestrator = KidsSyncOrchestrator(
          db: widget.appDb,
          repo: _repository,
          config: config,
          myKidId: kidId,
          onDisconnected: () {
            if (mounted) _leaveFamily();
          },
          onXpResetReceived: (resetAt) {
            FlutterSecureKeyValueStore().write(
              key: 'kinetic_xp_reset_at',
              value: resetAt.toUtc().toIso8601String(),
            );
            if (mounted) setState(() => _xpResetAt = resetAt);
          },
          onNewTaskReceived: (taskTitle) {
            final l10n = AppLocalizations.of(context);
            widget.notificationService.showNewTaskNotification(
              taskTitle,
              title: l10n.newTaskNotificationTitle,
            );
          },
        );
      });
      unawaited(_orchestrator!.sync());
    } else {
      setState(() {
        _enrolled = false;
        _initDone = true;
        _orchestrator = null;
      });
    }
  }

  Future<void> _leaveFamily() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.leaveFamilyTitle),
        content: Text(l10n.leaveFamilyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final store = FlutterSecureKeyValueStore();
    final configRepo = WebDavConfigRepository(store);
    await configRepo.clearEnrollment();
    if (mounted) {
      setState(() {
        _enrolled = false;
        _orchestrator = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_enrolled) {
      return KidsEnrollmentScreen(
        configRepo: WebDavConfigRepository(FlutterSecureKeyValueStore()),
        onEnrolled: _initSync,
      );
    }

    return KidsHomeScreen(
      appDb: widget.appDb,
      repository: _repository,
      orchestrator: _orchestrator,
      xpResetAt: _xpResetAt,
      onLeaveFamily: _leaveFamily,
    );
  }
}

void unawaited(Future<void> future) {
  future.ignore();
}
