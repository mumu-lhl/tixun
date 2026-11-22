part of "ai_usage_screen.dart";

extension _UsagePrices on _AiUsageScreenState {
  Future<void> _deletePrice(AiModelPrice price) async {
    await _store.deletePrice(price);
    if (mounted) _reloadPrices();
  }

  Future<void> _editPrice([AiModelPrice? price]) async {
    final currentConfig = ref.read(appControllerProvider).config;
    final initialProvider =
        price?.providerKind ??
        (currentConfig.kind == "chatgpt" ? "deepseek" : currentConfig.kind);
    final input = TextEditingController(
      text: price == null ? "" : _rateText(price.inputRateNanoUsdPerMillion),
    );
    final cached = TextEditingController(
      text: price == null
          ? ""
          : _rateText(price.cachedInputRateNanoUsdPerMillion),
    );
    final output = TextEditingController(
      text: price == null ? "" : _rateText(price.outputRateNanoUsdPerMillion),
    );
    final discount = TextEditingController(
      text: price == null
          ? (initialProvider == "deepseek" ? "50" : "0")
          : price.offPeakDiscountPercent.toString(),
    );
    final model = TextEditingController(
      text:
          price?.model ??
          (currentConfig.kind == "chatgpt"
              ? "deepseek-flash"
              : currentConfig.model),
    );
    final endpoint = TextEditingController(
      text:
          price?.endpoint ??
          (currentConfig.kind == "chatgpt"
              ? "https://api.deepseek.com"
              : currentConfig.baseUrl),
    );
    var provider = initialProvider;
    String? validationError;
    final result =
        await showDialog<
          ({
            String provider,
            String model,
            String endpoint,
            int input,
            int cached,
            int output,
            int discount,
          })
        >(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                price == null
                    ? context.l10n.addModelPrice
                    : context.l10n.editModelPrice,
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: provider,
                        decoration: InputDecoration(
                          labelText: context.l10n.provider,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: "deepseek",
                            child: Text(context.l10n.providerDeepSeek),
                          ),
                          DropdownMenuItem(
                            value: "compatible",
                            child: Text(context.l10n.providerCompatible),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => provider = value);
                          }
                        },
                      ),
                      TextField(
                        controller: endpoint,
                        decoration: InputDecoration(
                          labelText: context.l10n.endpoint,
                          hintText: "https://api.example.com/v1",
                        ),
                      ),
                      TextField(
                        controller: model,
                        decoration: InputDecoration(
                          labelText: context.l10n.model,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.modelPrices,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: input,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.inputPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: cached,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.cachedPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: output,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.outputPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: discount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.offPeakDiscount,
                          helperText: context.l10n.offPeakDiscountHint,
                          helperMaxLines: 3,
                        ),
                      ),
                      if (validationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            validationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final rates = [input, cached, output]
                        .map(
                          (controller) =>
                              double.tryParse(controller.text.trim()),
                        )
                        .toList();
                    final discountPercent = int.tryParse(discount.text.trim());
                    if (model.text.trim().isEmpty ||
                        endpoint.text.trim().isEmpty ||
                        discountPercent == null ||
                        discountPercent < 0 ||
                        discountPercent > 100 ||
                        rates.any(
                          (rate) =>
                              rate == null ||
                              !rate.isFinite ||
                              rate < 0 ||
                              rate > 100000,
                        )) {
                      setDialogState(
                        () => validationError = context.l10n.invalidModelPrice,
                      );
                      return;
                    }
                    validationError = null;
                    Navigator.pop(context, (
                      provider: provider,
                      model: model.text.trim(),
                      endpoint: endpoint.text.trim(),
                      input: (rates[0]! * 1000000000).round(),
                      cached: (rates[1]! * 1000000000).round(),
                      output: (rates[2]! * 1000000000).round(),
                      discount: discountPercent,
                    ));
                  },
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          ),
        );
    input.dispose();
    cached.dispose();
    output.dispose();
    discount.dispose();
    model.dispose();
    endpoint.dispose();
    if (result == null) return;
    await _store.savePrice(
      providerKind: result.provider,
      endpoint: result.endpoint,
      model: result.model,
      inputRateNanoUsdPerMillion: result.input,
      cachedInputRateNanoUsdPerMillion: result.cached,
      outputRateNanoUsdPerMillion: result.output,
      offPeakDiscountPercent: result.discount,
    );
    if (mounted) _reloadPrices();
  }

  Widget _pricesSection(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.modelPrices, style: theme.textTheme.titleMedium),
            ),
            IconButton(
              key: const Key("add-ai-model-price"),
              tooltip: l10n.addModelPrice,
              onPressed: _editPrice,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Text(l10n.ratePeakNote, style: style),
        const SizedBox(height: 2),
        Text(l10n.usagePriceSnapshotNote, style: style),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse("https://api-docs.deepseek.com/quick_start/pricing/"),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l10n.officialPricingPage),
          ),
        ),
        FutureBuilder<List<AiModelPrice>>(
          future: prices,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <AiModelPrice>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            return Column(
              children: [
                for (final price in list)
                  ListTile(
                    title: Text("${price.providerKind} · ${price.model}"),
                    subtitle: Text(
                      "${price.endpoint} · "
                      "${l10n.usagePriceUpdated(_dateOnly(price.updatedAt.toLocal()))}\n"
                      "${_usdRate(price.inputRateNanoUsdPerMillion)} / "
                      "${_usdRate(price.cachedInputRateNanoUsdPerMillion)} / "
                      "${_usdRate(price.outputRateNanoUsdPerMillion)}"
                      '${price.offPeakDiscountPercent > 0 ? ' · ${l10n.usageOffPeakDiscount(l10nArgument(usageInteger(price.offPeakDiscountPercent)))}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => _editPrice(price),
                    trailing: price.source == "user"
                        ? IconButton(
                            tooltip: l10n.delete,
                            onPressed: () => _deletePrice(price),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
