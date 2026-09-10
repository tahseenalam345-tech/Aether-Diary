import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:permission_handler/permission_handler.dart';

// Core & Navigation
import 'core/themes/app_theme.dart';
import 'core/themes/theme_provider.dart';
import 'core/navigation/app_router.dart';

// Services & Repositories
import 'core/services/task_notification_service.dart'; // Unified Notification Engine
import 'features/diary/data/diary_repository.dart';
import 'features/productivity/data/productivity_repository.dart';
import 'features/wallet/data/wallet_repository.dart';

// Models
import 'features/productivity/domain/models/aether_task.dart';
import 'features/productivity/domain/models/aether_subtask.dart';
import 'features/productivity/domain/models/aether_habit.dart';
import 'features/productivity/domain/models/aether_focus_session.dart';
import 'features/diary/domain/models/diary_entry.dart';
import 'features/diary/domain/models/aether_attachment.dart';
import 'features/wallet/domain/models/aether_transaction.dart';
import 'features/wallet/domain/models/aether_account.dart';
import 'features/wallet/domain/models/aether_subscription.dart';
import 'features/wallet/domain/models/aether_budget.dart';
import 'features/wallet/domain/models/aether_goal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Hive.initFlutter(); 
    
    Hive.registerAdapter(AetherTaskAdapter());
    Hive.registerAdapter(AetherSubtaskAdapter());
    Hive.registerAdapter(AetherHabitAdapter());
    Hive.registerAdapter(AetherFocusSessionAdapter());
    Hive.registerAdapter(DiaryEntryAdapter());
    Hive.registerAdapter(AetherAttachmentAdapter());
    Hive.registerAdapter(AetherTransactionAdapter());
    Hive.registerAdapter(AetherAccountAdapter());
    Hive.registerAdapter(AetherSubscriptionAdapter());
    Hive.registerAdapter(AetherBudgetAdapter());
    Hive.registerAdapter(AetherGoalAdapter());
    
    // 🌟 Booting everything cleanly
    await Future.wait([
      Hive.openBox('aether_settings'),
      Hive.openBox('settings'),
      DiaryRepository().init(),
      ProductivityRepository().init(),
      WalletRepository().init(),
      GlobalNotificationEngine().init(),
    ]);
    
  } catch (e, st) {
    developer.log('Aether OS Critical Boot Error', error: e, stackTrace: st);
  }
  
  runApp(const ProviderScope(child: AetherApp()));
}

class AetherApp extends ConsumerStatefulWidget {
  const AetherApp({super.key});
  @override
  ConsumerState<AetherApp> createState() => _AetherAppState();
}

class _AetherAppState extends ConsumerState<AetherApp> {
  @override
  void initState() {
    super.initState();
    _setupQuickActions(); 
    _requestPermissionsAndSchedule(); // 🌟 Automatically asks permission & schedules background alerts
  }

  Future<void> _requestPermissionsAndSchedule() async {
    try {
      // 🌟 1. Request notification permissions
      await Permission.notification.request();

      // 🌟 2. Ensure notification engine is initialized with channels
      await GlobalNotificationEngine().init();

      // 🌟 3. Send app-open greeting / reminder notification (outside app)
      await GlobalNotificationEngine().showAppOpenGreeting();

      // 🌟 4. Schedule all 10 Smart Wallet Background Notifications seamlessly
      await GlobalNotificationEngine().scheduleAllSmartWalletAlerts();

      // 🌟 5. Check if any budget is currently over limit and alert
      final repo = WalletRepository();
      final budgets = repo.getAllBudgets();
      final txs = repo.getAllTransactions();
      await GlobalNotificationEngine().checkAndAlertOverbudgets(budgets, txs);
    } catch (e, st) {
      developer.log('Notification Init/Alert Error', error: e, stackTrace: st);
    }
  }

  void _setupQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (shortcutType == 'action_add_expense') {
          AppRouter.router.push('/add-transaction');
        } else if (shortcutType == 'action_focus_mode') {
          AppRouter.router.push('/focus');
        } else if (shortcutType == 'action_new_note') {
          AppRouter.router.push('/create');
        }
      });
    });

    quickActions.setShortcutItems(const <ShortcutItem>[
      ShortcutItem(type: 'action_add_expense', localizedTitle: 'Fast Log Expense'),
      ShortcutItem(type: 'action_focus_mode', localizedTitle: 'Start Focus'),
      ShortcutItem(type: 'action_new_note', localizedTitle: 'New Memory'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isAmoled = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Aether OS',
      debugShowCheckedModeBanner: false,
      theme: isAmoled ? AppTheme.amoledTheme : AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}