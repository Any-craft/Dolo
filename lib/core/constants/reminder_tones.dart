import 'package:intl/intl.dart';

/// WhatsApp reminder tone presets (PRD Module 14, Handoff Task 6).
///
/// Stored in `app_settings` under [ReminderTones.settingsKey] as the
/// [ReminderTone.id] string.
enum ReminderTone {
  friendly(
    id: 'friendly',
    label: 'Friendly',
    emoji: '🤝',
    template:
        'Hey! Just a reminder about the Rs {amount} from our last hangout 😊',
  ),
  campus(
    id: 'campus',
    label: 'Campus Urdu',
    emoji: '🎓',
    template: 'Bhai, woh Rs {amount} yaad hai? Settle kar do yaar',
  ),
  firm(
    id: 'firm',
    label: 'Firm',
    emoji: '📋',
    template:
        'Payment of Rs {amount} is overdue. Please settle at your earliest.',
  );

  const ReminderTone({
    required this.id,
    required this.label,
    required this.emoji,
    required this.template,
  });

  final String id;
  final String label;
  final String emoji;
  final String template;

  static ReminderTone fromId(String? id) => ReminderTone.values.firstWhere(
        (t) => t.id == id,
        orElse: () => ReminderTone.friendly,
      );

  /// Fills the template with a whole-rupee [amountRs] formatted as `1,200`,
  /// optionally appending the user's Raast ID so the friend can pay directly.
  String message(int amountRs, {String? raastId}) {
    final amount = NumberFormat('#,###').format(amountRs);
    final text = template.replaceAll('{amount}', amount);
    if (raastId == null || raastId.trim().isEmpty) return text;
    return '$text\nRaast ID: ${raastId.trim()}';
  }
}

class ReminderTones {
  ReminderTones._();

  static const String settingsKey = 'whatsapp_tone';
}
