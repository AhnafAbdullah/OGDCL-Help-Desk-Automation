import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _dateTimeFormat = DateFormat('MMM d, y • h:mm a');
  static final _dateFormat = DateFormat('MMM d, y');

  static String dateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());

  static String date(DateTime value) => _dateFormat.format(value.toLocal());

  /// A short "3h ago" style label, falling back to a plain date past a week.
  static String relative(DateTime value) {
    final local = value.toLocal();
    final diff = DateTime.now().difference(local);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(local);
  }
}
