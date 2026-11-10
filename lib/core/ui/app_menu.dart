import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

const _menuMotion = AnimationStyle(
  duration: Duration(milliseconds: 180),
  reverseDuration: Duration(milliseconds: 120),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);
AnimationStyle menuAnimation(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? AnimationStyle.noAnimation
    : _menuMotion;

/// A selection control using Flutter's animated M3 anchored menu. Selection is
/// delivered after closing, so a caller rebuilding its field cannot cut off the
/// exit animation. Material owns overlay placement and keyboard navigation.
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.compact = false,
    this.style,
    super.key,
  });
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration decoration;
  final bool compact;
  final TextStyle? style;
  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  final controller = MenuController();
  final focus = FocusNode();
  late T? value = widget.initialValue;
  T? pending;
  bool hasPending = false, open = false;
  @override
  void didUpdateWidget(covariant AppSelectField<T> old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue) value = widget.initialValue;
    if (widget.onChanged == null && controller.isOpen) controller.close();
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void closed() {
    if (!mounted) return;
    final commit = hasPending, selected = pending;
    setState(() {
      open = false;
      hasPending = false;
      if (commit) value = selected;
    });
    if (commit) {
      widget.items.where((i) => i.value == selected).firstOrNull?.onTap?.call();
      widget.onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null && widget.items.isNotEmpty;
    final choice = widget.items.where((i) => i.value == value).firstOrNull;
    final label =
        choice?.child ??
        Text(
          widget.decoration.hintText ?? context.tr('请选择'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    final textStyle = widget.style ?? Theme.of(context).textTheme.bodyLarge!;
    // Dialogs query intrinsic sizes; LayoutBuilder cannot answer those queries.
    // Let the parent size the field and use a bounded, viewport-safe menu.
    final fieldWidth = widget.compact ? 132.0 : null;
    final menuWidth = math.min(
      widget.compact ? 220.0 : 280.0,
      MediaQuery.sizeOf(context).width - 24,
    );
    return LimitedBox(
      maxWidth: 280,
      child: MenuAnchor(
        controller: controller,
        childFocusNode: focus,
        animated: !MediaQuery.disableAnimationsOf(context),
        consumeOutsideTap: true,
        style: (Theme.of(context).menuTheme.style ?? const MenuStyle())
            .copyWith(
              alignment: AlignmentDirectional.bottomStart,
              minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
              maximumSize: WidgetStatePropertyAll(
                Size(
                  menuWidth,
                  math.min(440, MediaQuery.sizeOf(context).height * .6),
                ),
              ),
            ),
        alignmentOffset: const Offset(0, 6),
        onOpen: () => setState(() => open = true),
        onClose: closed,
        menuChildren: [
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: menuWidth - 8,
                child: MenuItemButton(
                  closeOnActivate: false,
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    backgroundColor: item.value == value
                        ? WidgetStatePropertyAll(
                            colors.primaryContainer.withValues(alpha: .65),
                          )
                        : null,
                  ),
                  leadingIcon: SizedBox(
                    width: 20,
                    child: item.value == value
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: colors.primary,
                          )
                        : null,
                  ),
                  onPressed: item.enabled && enabled
                      ? () {
                          pending = item.value;
                          hasPending = true;
                          controller.close();
                        }
                      : null,
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: item.enabled
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: item.child,
                  ),
                ),
              ),
            ),
        ],
        builder: (context, menu, child) => SizedBox(
          width: fieldWidth,
          child: Semantics(
            button: true,
            enabled: enabled,
            expanded: open,
            child: InkWell(
              focusNode: focus,
              borderRadius: BorderRadius.circular(12),
              onTap: enabled
                  ? () {
                      focus.requestFocus();
                      menu.isOpen ? menu.close() : menu.open();
                    }
                  : null,
              child: widget.compact
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: _row(label, textStyle, enabled, colors),
                    )
                  : InputDecorator(
                      isEmpty: choice == null,
                      isFocused: open,
                      decoration: widget.decoration
                          .copyWith(
                            enabled: enabled,
                            suffixIcon: AnimatedRotation(
                              turns: open ? .5 : 0,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: const Icon(Icons.expand_more_rounded),
                            ),
                          )
                          .applyDefaults(
                            Theme.of(context).inputDecorationTheme,
                          ),
                      child: DefaultTextStyle(
                        style: textStyle.copyWith(
                          color: enabled
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: label,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    Widget label,
    TextStyle style,
    bool enabled,
    ColorScheme colors,
  ) => Row(
    children: [
      Expanded(
        child: DefaultTextStyle(
          style: style.copyWith(
            color: enabled
                ? style.color ?? colors.onSurface
                : colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: label,
        ),
      ),
      const SizedBox(width: 4),
      AnimatedRotation(
        turns: open ? .5 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: Icon(
          Icons.expand_more_rounded,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
