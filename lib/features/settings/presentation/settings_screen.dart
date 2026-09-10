import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/themes/theme_provider.dart';
import '../../../core/services/task_notification_service.dart';
import '../../../core/providers/module_preferences_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../diary/data/diary_provider.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/utils/aether_currency.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricsEnabled = false;
  bool _isExporting = false;
  String _selectedLanguage = "English (US)";
  int _focusSprintMinutes = 25;
  String _defaultMood = "Calm";

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (canAuthenticate) {
          final bool didAuthenticate = await auth.authenticate(
            localizedReason: 'Authenticate to enable biometric app lock',
          );
          setState(() => _biometricsEnabled = didAuthenticate);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware biometrics not supported.')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } else {
      setState(() => _biometricsEnabled = false);
    }
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final diaries = ref.read(diaryEntriesProvider).valueOrNull ?? [];
      final tasks = ref.read(taskNotifierProvider).valueOrNull ?? [];
      final txs = ref.read(transactionNotifierProvider).valueOrNull ?? [];

      final exportPayload = {
        'version': 'Aether OS 2.4.0',
        'timestamp': DateTime.now().toIso8601String(),
        'vault_entries': diaries.map((e) => {'id': e.id, 'title': e.title, 'content': e.content, 'date': e.createdAt.toIso8601String()}).toList(),
        'tasks': tasks.map((t) => {'id': t.id, 'title': t.title, 'completed': t.isCompleted}).toList(),
        'transactions': txs.map((t) => {'id': t.id, 'amount': t.amount, 'type': t.type, 'date': t.date.toIso8601String()}).toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/aether_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(exportPayload));

      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Aether OS Complete Backup');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: const Text("Edit User Profile Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: const Color(0xFF060B14)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(userNameProvider.notifier).setName(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save Name", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    final currentCode = ref.read(primaryCurrencyProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101E).withValues(alpha: 0.95),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const Text("Select Primary Currency", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("All expenses, budgets & analytics will display in this currency.", style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: AetherCurrency.supportedCurrencies.length,
                    itemBuilder: (context, i) {
                      final c = AetherCurrency.supportedCurrencies[i];
                      final isSelected = c.code == currentCode;
                      return ListTile(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await ref.read(primaryCurrencyProvider.notifier).setCurrency(c.code);
                          if (context.mounted) context.pop();
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? const Color(0xFF10B981) : Colors.white12),
                          ),
                          child: Text(c.symbol.trim(), style: TextStyle(color: isSelected ? const Color(0xFF10B981) : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        title: Text(c.name, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(c.code, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Colors.white12)),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("Aether OS User Guide", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("💰 Wealth Management", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13.5)),
              SizedBox(height: 4),
              Text("Log expenses, track real-time net worth, set multi-period budgets with liquid date pickers, and manage subscriptions with renewal alerts.", style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),

              Text("📝 Sanctuary & Diary", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.5)),
              SizedBox(height: 4),
              Text("Capture rich reflections with live WYSIWYG formatting, whiteboard sketches, voice dictation, folder tags, and automatic draft protection.", style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),

              Text("⚡ Productivity & Focus", style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13.5)),
              SizedBox(height: 4),
              Text("Organize priority tasks with action subtasks, routine habits with streak matrices, and Pomodoro focus sprints.", style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),

              Text("✨ Neural AI Reflector", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13.5)),
              SizedBox(height: 4),
              Text("Monitors your cross-module execution, emotions, and spending to generate holistic daily advice without cloud tracking.", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got It", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showPrivacyInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Colors.white12)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text("Privacy & Security", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Aether OS operates on a strict 100% Local-First Architecture.\n\n"
          "• All data is stored locally in encrypted Hive boxes on your device.\n"
          "• No personal entries, financial transactions, or reflections are ever transmitted to external servers.\n"
          "• You have total ownership and can export your entire database as JSON anytime.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Understood", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Colors.white12)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text("About Aether OS", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Aether OS — Modular Super App", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text("Version 2.4.0 (Aether Neural Build)", style: TextStyle(color: Colors.white38, fontSize: 12)),
            SizedBox(height: 12),
            Text("Engineered for peak personal mastery, wealth intelligence, and mindfulness with zero distractions.", style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Color(0xFF38BDF8)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAmoled = ref.watch(themeProvider);
    final prefs = ref.watch(modulePreferencesProvider);
    final userName = ref.watch(userNameProvider).valueOrNull ?? "Traveler";

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "SETTINGS DECK",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 1. USER IDENTITY CARD
            _buildUserIdentityCard(userName),
            const SizedBox(height: 24),

            // 🌟 2. FEATURE TOGGLING / MODULAR WORKSPACES
            _buildSectionTitle("MODULAR WORKSPACES", "Activate or deactivate standalone systems"),
            const SizedBox(height: 12),
            _buildModuleToggleTile(
              icon: Icons.account_balance_wallet_rounded,
              title: "Wealth & Budgets",
              subtitle: "Expense tracking, accounts, smart budgets & cashflow",
              accentColor: const Color(0xFF10B981),
              value: prefs.isWealthEnabled,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(modulePreferencesProvider.notifier).toggleWealth(val);
              },
            ),
            const SizedBox(height: 10),
            _buildModuleToggleTile(
              icon: Icons.auto_stories_rounded,
              title: "Personal Diary",
              subtitle: "Encrypted memories, daily mood trends & reflections",
              accentColor: const Color(0xFF38BDF8),
              value: prefs.isDiaryEnabled,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(modulePreferencesProvider.notifier).toggleDiary(val);
              },
            ),
            const SizedBox(height: 10),
            _buildModuleToggleTile(
              icon: Icons.bolt_rounded,
              title: "Productivity & Habits",
              subtitle: "Smart task manager, focus timer & habit streaks",
              accentColor: const Color(0xFFFBBF24),
              value: prefs.isProductivityEnabled,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(modulePreferencesProvider.notifier).toggleProductivity(val);
              },
            ),

            const SizedBox(height: 28),

            // 🌟 3. WEALTH MODULE SPECIFIC SETTINGS
            if (prefs.isWealthEnabled) ...[
              _buildSectionTitle("WEALTH CONFIGURATIONS", "Currency, limits and budget rules"),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showCurrencyPicker(context),
                child: _buildActionTile(
                  icon: Icons.currency_exchange_rounded,
                  title: "Primary Currency",
                  subtitle: "${AetherCurrency.fromCode(ref.watch(primaryCurrencyProvider)).name} (${AetherCurrency.fromCode(ref.watch(primaryCurrencyProvider)).symbol.trim()})",
                  color: const Color(0xFF10B981),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(ref.watch(primaryCurrencyProvider), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final repo = WalletRepository();
                  await GlobalNotificationEngine().checkAndAlertOverbudgets(repo.getAllBudgets(), repo.getAllTransactions());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Budget overrun scan complete! ✅")));
                  }
                },
                child: _buildActionTile(
                  icon: Icons.notifications_active_outlined,
                  title: "Audit Budget Limits",
                  subtitle: "Scan transactions and trigger immediate alerts",
                  color: const Color(0xFF10B981),
                  trailing: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 🌟 4. DIARY MODULE SPECIFIC SETTINGS
            if (prefs.isDiaryEnabled) ...[
              _buildSectionTitle("DIARY & VAULT CONFIGURATIONS", "Encryption, moods and formatting"),
              const SizedBox(height: 12),
              _buildSwitchTile(
                icon: Icons.lock_outline_rounded,
                title: "Biometric Note Protection",
                subtitle: "Require fingerprint/face to view locked notes",
                color: const Color(0xFF38BDF8),
                value: _biometricsEnabled,
                onChanged: _toggleBiometrics,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                icon: Icons.mood_rounded,
                title: "Default Mood State",
                subtitle: "Pre-selects '$_defaultMood' on new reflection creation",
                color: const Color(0xFF38BDF8),
                trailing: DropdownButton<String>(
                  value: _defaultMood,
                  dropdownColor: const Color(0xFF0C101E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                  items: ['Happy', 'Calm', 'Sad', 'Anxious', 'Angry'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _defaultMood = val);
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 🌟 5. PRODUCTIVITY MODULE SPECIFIC SETTINGS
            if (prefs.isProductivityEnabled) ...[
              _buildSectionTitle("PRODUCTIVITY & FOCUS CONFIGURATIONS", "Sprints, intervals and notifications"),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.timer_outlined,
                title: "Focus Sprint Duration",
                subtitle: "Default Pomodoro sprint timer length",
                color: const Color(0xFFFBBF24),
                trailing: DropdownButton<int>(
                  value: _focusSprintMinutes,
                  dropdownColor: const Color(0xFF0C101E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFBBF24)),
                  style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12),
                  items: [15, 25, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text("${m}m"))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _focusSprintMinutes = val);
                  },
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await GlobalNotificationEngine().triggerImmediateAlert(
                    "🧪 Aether OS Notification Test",
                    "Task notifications & reminders are active! 🔔",
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test notification triggered!")));
                  }
                },
                child: _buildActionTile(
                  icon: Icons.send_rounded,
                  title: "Test System Notifications",
                  subtitle: "Send a mobile push test to notification shade",
                  color: const Color(0xFFFBBF24),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // 🌟 6. SYSTEM, THEME & SECURITY
            _buildSectionTitle("SYSTEM, THEME & SECURITY", "Global OS appearance and security"),
            const SizedBox(height: 12),
            _buildSwitchTile(
              icon: Icons.dark_mode_outlined,
              title: "AMOLED Pure Black",
              subtitle: "High contrast dark palette for OLED panels",
              color: const Color(0xFF8B5CF6),
              value: isAmoled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                ref.read(themeProvider.notifier).state = v;
              },
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.language_rounded,
              title: "App Language",
              subtitle: "Interface language localization",
              color: const Color(0xFF8B5CF6),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: const Color(0xFF0C101E),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B5CF6)),
                style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
                items: ["English (US)", "Urdu (اردو)", "Spanish (Español)", "German (Deutsch)"]
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
            ),

            const SizedBox(height: 28),

            // 🌟 7. DATA, GUIDE & PRIVACY
            _buildSectionTitle("DOCUMENTATION & BACKUP", "User guides, privacy policy and backups"),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showUserGuideDialog,
              child: _buildActionTile(
                icon: Icons.menu_book_rounded,
                title: "Aether OS User Guide",
                subtitle: "How to use features and modular shortcuts",
                color: const Color(0xFF38BDF8),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showPrivacyInfoDialog,
              child: _buildActionTile(
                icon: Icons.shield_outlined,
                title: "Privacy & Data Architecture",
                subtitle: "100% Local-First encrypted storage details",
                color: const Color(0xFF10B981),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _exportData,
              child: _buildActionTile(
                icon: Icons.download_outlined,
                title: "Export System Backup",
                subtitle: "Download entire database as JSON",
                color: const Color(0xFF2DD4BF),
                trailing: _isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showAboutDialog,
              child: _buildActionTile(
                icon: Icons.info_outline_rounded,
                title: "About Aether OS",
                subtitle: "Version 2.4.0 • Build info & credits",
                color: Colors.white70,
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIdentityCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF2DD4BF), Color(0xFF8B5CF6)]),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : "A",
                style: const TextStyle(color: Color(0xFF060B14), fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text("Aether Sanctuary Explorer", style: TextStyle(color: Colors.white38, fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => _showEditNameDialog(userName),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
      ],
    );
  }

  Widget _buildModuleToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value ? accentColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: value ? accentColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: value ? accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(icon, color: value ? accentColor : Colors.white54, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}