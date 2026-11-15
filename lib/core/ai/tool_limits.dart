import '../database/database.dart';

const maxToolCallsKey = 'max_tool_calls';
const defaultMaxToolCalls = 8;

/// Zero disables the per-request action count, not cancellation or validation.
Future<int> loadMaxToolCalls(AppDatabase db) async {
  final value = int.tryParse(await db.preference(maxToolCallsKey) ?? '');
  return value != null && value >= 0 ? value : defaultMaxToolCalls;
}
