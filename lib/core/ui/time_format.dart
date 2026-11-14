/// Small timestamp helper shared by the settings panels. It prints a plain
/// `yyyy-MM-dd HH:mm` local time, which stays unambiguous next to provider
/// figures that arrive in different time zones.
library;

String formatLocalTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
