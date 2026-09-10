import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/app_lock_screen.dart';
import 'main_scaffold.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/diary/presentation/create_entry_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/analytics/presentation/consistency_analytics_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/ai_reflection/presentation/ai_reflection_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/diary/domain/models/diary_entry.dart';
import '../../features/wallet/presentation/wallet_dashboard_screen.dart';
import '../../features/wallet/presentation/accounts_screen.dart';
import '../../features/wallet/presentation/add_transaction_screen.dart';
import '../../features/wallet/presentation/budgets_screen.dart';
import '../../features/wallet/presentation/savings_goals_screen.dart';
import '../../features/wallet/presentation/subscriptions_screen.dart';
import '../../features/wallet/presentation/financial_analytics_screen.dart';
import '../../features/wallet/presentation/transaction_details_screen.dart';
import '../../features/wallet/domain/models/aether_transaction.dart';
import '../../features/goals/presentation/goals_screen.dart'; 
import '../../features/diary/presentation/diary_screen.dart';
import '../../features/productivity/presentation/productivity_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/productivity/presentation/habits_screen.dart';
import '../../features/wallet/presentation/budget_details_screen.dart';
import '../../features/wallet/domain/models/aether_budget.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/', 
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const OnboardingScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/lock', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const LockScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/home', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const MainScaffold(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      
      GoRoute(path: '/focus', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const FocusScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/productivity', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const ProductivityScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/diary', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const DiaryScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      
      GoRoute(path: '/habits', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const HabitsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      
      GoRoute(
        path: '/create',
        pageBuilder: (context, state) {
          if (state.extra is DiaryEntry) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: CreateEntryScreen(existingEntry: state.extra as DiaryEntry),
              transitionsBuilder: (context, animation, _, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          } else if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            return CustomTransitionPage(
              key: state.pageKey,
              child: CreateEntryScreen(
                existingEntry: map['entry'] as DiaryEntry?,
                initialMood: map['initialMood'] as String?,
              ),
              transitionsBuilder: (context, animation, _, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          }
          final moodParam = state.uri.queryParameters['mood'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: CreateEntryScreen(initialMood: moodParam),
            transitionsBuilder: (context, animation, _, child) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),

      GoRoute(path: '/analytics', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const AnalyticsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/consistency-analytics', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const ConsistencyAnalyticsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/calendar', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const CalendarScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/search', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const SearchScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/ai_reflect', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const AiReflectionScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/settings', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const SettingsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/wallet', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const WalletDashboardScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/accounts', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const AccountsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(
        path: '/add-transaction',
        pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const AddTransactionScreen(), transitionsBuilder: (context, animation, _, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child)),
      ),
      GoRoute(path: '/budgets', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const BudgetsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/subscriptions', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const SubscriptionsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      GoRoute(path: '/financial-analytics', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const FinancialAnalyticsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      
      GoRoute(path: '/savings', pageBuilder: (context, state) => CustomTransitionPage(key: state.pageKey, child: const SavingsGoalsScreen(), transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child))),
      
      GoRoute(
        path: '/goals',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey, 
          child: const GoalsScreen(), 
          transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child)
        ),
      ),
      
      GoRoute(
        path: '/transaction-details',
        pageBuilder: (context, state) {
          final transaction = state.extra as AetherTransaction?;
          if (transaction == null) {
            return CustomTransitionPage(
              key: state.pageKey, 
              child: const HomeScreen(), 
              transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child)
            );
          }
          return CustomTransitionPage(
            key: state.pageKey, 
            child: TransactionDetailsScreen(transaction: transaction), 
            transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child)
          );
        }
      ),

      GoRoute(
        path: '/budget-details',
        pageBuilder: (context, state) {
          final budget = state.extra as AetherBudget;
          return CustomTransitionPage(
            key: state.pageKey, 
            child: BudgetDetailsScreen(budget: budget), 
            transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child)
          );
        }
      ),
    ],
  );
}