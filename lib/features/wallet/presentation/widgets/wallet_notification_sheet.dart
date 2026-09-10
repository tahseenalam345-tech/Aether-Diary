import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/wallet_notifications_provider.dart';

class WalletNotificationSheet extends ConsumerWidget {
  final WalletNotifCategory category;

  const WalletNotificationSheet({super.key, required this.category});

  static void show(BuildContext context, {required WalletNotifCategory category}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WalletNotificationSheet(category: category),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 5) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM d, h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isAccounts = category == WalletNotifCategory.account;
    final notifs = isAccounts
        ? ref.watch(accountNotificationsProvider)
        : ref.watch(budgetNotificationsProvider);

    final unreadCount = notifs.where((n) => !n.isRead).length;
    final primaryColor = isAccounts ? const Color(0xFF38BDF8) : const Color(0xFF34F5C5);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF090D16).withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🌟 DRAG HANDLE
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🌟 HEADER ROW
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAccounts ? Icons.account_balance_wallet_rounded : Icons.pie_chart_rounded,
                            color: primaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAccounts ? "Account Alerts" : "Budget & Plan Alerts",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              unreadCount > 0
                                  ? "$unreadCount unread alert${unreadCount > 1 ? 's' : ''}"
                                  : "All caught up",
                              style: TextStyle(
                                color: unreadCount > 0 ? primaryColor : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (unreadCount > 0)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(readWalletNotifIdsProvider.notifier).markAllAsRead(notifs.map((n) => n.id).toList());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.done_all_rounded, color: Colors.white70, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "Mark Read",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),

              // 🌟 NOTIFICATIONS LIST
              Flexible(
                child: notifs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white24,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No notifications right now",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Your financial health looks clean and quiet.",
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: notifs.length,
                        itemBuilder: (context, index) {
                          final item = notifs[index];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(readWalletNotifIdsProvider.notifier).markAsRead(item.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? Colors.white.withValues(alpha: 0.02)
                                    : item.color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: item.isRead
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : item.color.withValues(alpha: 0.25),
                                  width: item.isRead ? 1 : 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: item.color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(item.icon, color: item.color, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTime(item.timestamp),
                                              style: TextStyle(
                                                color: item.isRead ? Colors.white30 : item.color.withValues(alpha: 0.8),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.message,
                                          style: TextStyle(
                                            color: item.isRead ? Colors.white54 : Colors.white70,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: BoxDecoration(
                                        color: item.color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.color.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ).animate().fadeIn(delay: Duration(milliseconds: index * 40)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletNotificationBell extends ConsumerWidget {
  final WalletNotifCategory category;
  final VoidCallback? onTap;

  const WalletNotificationBell({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = category == WalletNotifCategory.account
        ? ref.watch(unreadAccountAlertsCountProvider)
        : ref.watch(unreadBudgetAlertsCountProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap!();
        } else {
          WalletNotificationSheet.show(context, category: category);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 18),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFB7185),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFB7185),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
