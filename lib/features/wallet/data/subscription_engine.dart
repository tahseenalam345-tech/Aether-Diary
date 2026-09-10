import '../domain/models/aether_subscription.dart';
import '../../../core/services/task_notification_service.dart';

class SubscriptionEngine {
  static final SubscriptionEngine _instance = SubscriptionEngine._internal();
  factory SubscriptionEngine() => _instance;
  SubscriptionEngine._internal();

  /// Walks a past-due subscription date forward until it is in the future
  DateTime rollDateForward(DateTime currentDue, String cycle) {
    DateTime rolledDate = currentDue;
    final now = DateTime.now();

    while (rolledDate.isBefore(now)) {
      if (cycle == 'weekly') {
        rolledDate = rolledDate.add(const Duration(days: 7));
      } else if (cycle == 'yearly') {
        rolledDate = DateTime(rolledDate.year + 1, rolledDate.month, rolledDate.day, rolledDate.hour, rolledDate.minute);
      } else {
        // Default to monthly handling
        int nextMonth = rolledDate.month + 1;
        int nextYear = rolledDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        rolledDate = DateTime(nextYear, nextMonth, rolledDate.day, rolledDate.hour, rolledDate.minute);
      }
    }
    return rolledDate;
  }

  /// SCALABILITY OPTIMIZATION: 
  /// Delegates scheduling to the unified GlobalNotificationEngine to prevent Android OS alarm limiting.
  Future<void> scheduleSubscriptionAlerts(AetherSubscription sub) async {
    await GlobalNotificationEngine().scheduleSubscriptionAlerts(sub);
  }
}