import 'package:material_ui/material_ui.dart';

import '../../core/ai/chatgpt/usage.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/time_format.dart';

/// Shows the subscription quota the ChatGPT endpoint reports.
///
/// The numbers come from an undocumented endpoint, so the panel says so and
/// never hides a failure behind a stale value: every check replaces the shown
/// result or an error.
class ChatGptQuotaPanel extends StatelessWidget {
  const ChatGptQuotaPanel({
    required this.quota,
    required this.loading,
    required this.failure,
    required this.onRefresh,
    super.key,
  });

  final ChatGptQuota? quota;
  final bool loading;
  final Object? failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final value = quota;
    return Container(
      key: const Key('chatgpt-quota'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chatGptQuota,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: const Key('chatgpt-quota-refresh'),
                  tooltip: value == null
                      ? l10n.chatGptQuotaCheck
                      : l10n.refresh,
                  onPressed: onRefresh,
                  icon: Icon(
                    value == null ? Icons.speed_outlined : Icons.refresh,
                    size: 18,
                  ),
                ),
            ],
          ),
          if (loading && value == null)
            Text(
              l10n.chatGptQuotaChecking,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            )
          else if (failure != null)
            Text(
              failureText(l10n, failure!),
              style: TextStyle(fontSize: 12, color: colors.error),
            )
          else if (value != null) ...[
            Text(
              l10n.chatGptQuotaPlan(
                value.planType.isEmpty
                    ? l10n.chatGptQuotaPlanUnknown
                    : planLabel(value.planType),
              ),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            if (value.limitReached)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.chatGptQuotaLimitReached,
                  style: TextStyle(fontSize: 13, color: colors.error),
                ),
              ),
            for (final window in [value.primary, value.secondary])
              if (window != null) _window(context, window),
            if (value.unlimitedCredits)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.chatGptQuotaUnlimited),
              )
            else if (value.creditBalance case final String balance)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.chatGptQuotaCredits(balance)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.chatGptQuotaFetchedAt(
                  formatLocalTimestamp(value.fetchedAt),
                ),
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Text(
              l10n.chatGptQuotaExperimental,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _window(BuildContext context, ChatGptQuotaWindow window) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final length = window.windowSeconds >= 86400
        ? l10n.chatGptQuotaDays(
            l10nArgument((window.windowSeconds / 86400).round()),
          )
        : l10n.chatGptQuotaHours(
            l10nArgument((window.windowSeconds / 3600).round()),
          );
    final reset = window.resetAt;
    final remaining = reset != null
        ? reset.difference(DateTime.now())
        : Duration(seconds: window.resetAfterSeconds);
    final remainingLabel = _duration(context, remaining);
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chatGptQuotaUsed(
                    length,
                    l10nArgument(window.usedPercent),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (remaining.inSeconds > 0)
                Text(
                  l10n.chatGptQuotaResetsIn(remainingLabel),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: window.usedPercent / 100,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              color: window.usedPercent >= 90
                  ? colors.error
                  : window.usedPercent >= 70
                  ? colors.tertiary
                  : colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `1 天 3 小时` in the current language; the two largest units are enough for
/// a reset countdown.
String _duration(BuildContext context, Duration value) {
  final l10n = context.l10n;
  final remaining = value.isNegative ? Duration.zero : value;
  String count(int number) => l10nArgument(number);
  final parts = <String>[];
  if (remaining.inDays > 0) {
    parts.add(l10n.chatGptQuotaDurationDays(count(remaining.inDays)));
  }
  final hours = remaining.inHours % 24;
  if (hours > 0) {
    parts.add(l10n.chatGptQuotaDurationHours(count(hours)));
  }
  if (parts.isEmpty) {
    final minutes = remaining.inMinutes;
    parts.add(
      minutes > 0
          ? l10n.chatGptQuotaDurationMinutes(count(minutes))
          : l10n.chatGptQuotaDurationSeconds(count(remaining.inSeconds)),
    );
  }
  return parts.join(' ');
}

/// `plus` → `Plus`; unknown plans keep the server's word instead of a guess.
String planLabel(String planType) {
  final value = planType.trim();
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
