// WeChat picker delegates still use the legacy Material types.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Image-only picker: keep selection counts useful without showing the internal
/// integer used to avoid imposing an arbitrary photo limit.
class PhotoPickerBuilder
    extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  PhotoPickerBuilder({
    required super.provider,
    required super.initialPermission,
    required super.pickerTheme,
    required super.textDelegate,
  }) : super(shouldRevertGrid: false);

  @override
  Widget confirmButton(BuildContext context) => ListenableBuilder(
    listenable: provider,
    builder: (context, _) => PhotoConfirmButton(
      label: textDelegate.confirm,
      count: provider.selectedAssets.length,
      onPressed:
          provider.isSelectedNotEmpty ||
              provider.previousSelectedAssets.isNotEmpty
          ? () => Navigator.of(context).pop(provider.selectedAssets)
          : null,
    ),
  );

  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    final current = index == null
        ? provider.selectedAssets
        : provider.currentAssets;
    if (current.isEmpty) return;
    final result = await Navigator.of(context).push<List<AssetEntity>>(
      AssetPickerViewerPageRoute(
        builder: (_) =>
            AssetPickerViewer<
              AssetEntity,
              AssetPathEntity,
              AssetPickerViewerProvider<AssetEntity>,
              PhotoViewerBuilder
            >(
              builder: PhotoViewerBuilder(
                currentIndex: index ?? current.indexOf(currentAsset),
                previewAssets: current,
                selectedAssets: provider.selectedAssets,
                selectorProvider: provider,
                provider: AssetPickerViewerProvider<AssetEntity>(
                  provider.selectedAssets,
                  maxAssets: provider.maxAssets,
                ),
                maxAssets: provider.maxAssets,
                themeData: theme,
              ),
            ),
      ),
    );
    if (result != null && context.mounted) Navigator.of(context).pop(result);
  }
}

class PhotoViewerBuilder
    extends
        DefaultAssetPickerViewerBuilderDelegate<
          AssetPickerViewerProvider<AssetEntity>,
          DefaultAssetPickerProvider
        > {
  PhotoViewerBuilder({
    required super.currentIndex,
    required super.previewAssets,
    required super.selectedAssets,
    required super.selectorProvider,
    required AssetPickerViewerProvider<AssetEntity> super.provider,
    required super.maxAssets,
    required super.themeData,
  });

  @override
  Widget confirmButton(BuildContext context) => ListenableBuilder(
    listenable: provider!,
    builder: (context, _) => PhotoConfirmButton(
      label: textDelegate.confirm,
      count: provider!.currentlySelectedAssets.length,
      onPressed: (selectedAssets?.isNotEmpty ?? false)
          ? () async {
              if (provider!.isSelectedNotEmpty) {
                Navigator.of(context).pop(provider!.currentlySelectedAssets);
              } else if (await onChangingSelected(
                context,
                currentAsset,
                false,
              )) {
                if (context.mounted) {
                  Navigator.of(context).pop(selectedAssets ?? [currentAsset]);
                }
              }
            }
          : null,
    ),
  );
}

class PhotoConfirmButton extends StatelessWidget {
  const PhotoConfirmButton({
    required this.label,
    required this.count,
    required this.onPressed,
    super.key,
  });

  final String label;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Text(count == 0 ? label : '$label ($count)'),
  );
}
