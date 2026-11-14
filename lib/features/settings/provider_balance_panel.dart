import 'package:material_ui/material_ui.dart';

import '../../core/ai/provider_balance.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/time_format.dart';

/// Shows the balance the provider reports for its own account.
///
/// The figures are the provider's decimal strings, shown with the currency
/// symbol; this widget never recomputes or converts them.
class ProviderBalancePanel extends StatelessWidget {
  const ProviderBalancePanel({
    required this.balance,
    required this.loading,
    required this.failure,
    required this.onRefresh,
    super.key,
  });

  final ProviderBalance? balance;
  final bool loading;
  final Object? failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final value = balance;
    return Container(
      key: const Key('provider-balance'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
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
                  l10n.accountBalance,
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
                  key: const Key('provider-balance-refresh'),
                  tooltip: value == null ? l10n.checkBalance : l10n.refresh,
                  onPressed: onRefresh,
                  icon: Icon(
                    value == null ? Icons.receipt_long_outlined : Icons.refresh,
                    size: 18,
                  ),
                ),
            ],
          ),
          if (loading && value == null)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: Text(
                l10n.checkBalanceInProgress,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            )
          else if (failure != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: Text(
                failureText(l10n, failure!),
                style: TextStyle(fontSize: 12, color: colors.error),
              ),
            )
          else if (value != null) ...[
            if (!value.available)
              Text(
                l10n.accountBalanceUnavailable,
                style: TextStyle(fontSize: 13, color: colors.error),
              )
            else if (value.lines.isEmpty)
              Text(
                l10n.accountBalanceUnavailable,
                style: const TextStyle(fontSize: 13),
              )
            else
              for (final line in value.lines) ...[
                Text(
                  l10n.accountBalanceTotal(balanceAmount(line, line.total)),
                  key: Key('balance-total-${line.currency}'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l10n.accountBalanceBreakdown(
                      balanceAmount(line, line.granted),
                      balanceAmount(line, line.toppedUp),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.accountBalanceFetchedAt(
                  formatLocalTimestamp(value.fetchedAt),
                ),
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `¥110.00`, `$3.50`, or `CHF 4.00` for a currency we have no symbol for.
String balanceAmount(ProviderBalanceLine line, String amount) {
  final symbol = switch (line.currency.toUpperCase()) {
    'CNY' || 'RMB' => '¥',
    'USD' => r'$',
    final other => '$other ',
  };
  return '$symbol$amount';
}
