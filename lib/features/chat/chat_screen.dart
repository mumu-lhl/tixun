import '../../core/ui/app_menu.dart';
import '../scratchpad/scratchpad_screen.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/platform/photo_picker.dart';
import '../../core/ui/learning_markdown.dart';
import '../library/chat_study_actions.dart';
import '../library/image_editor.dart';
import '../practice/question_card.dart';
import 'reasoning_menu.dart';
import 'message_reasoning.dart';
import 'session_list.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Row(
      children: [
        if (wide) ...[
          const SizedBox(width: 268, child: SessionList()),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    if (!wide)
                      IconButton(
                        tooltip: context.tr("会话列表"),
                        icon: const Icon(Icons.menu_book_outlined),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => SizedBox(
                            height: MediaQuery.sizeOf(context).height * .85,
                            child: SessionList(
                              onSelected: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.selected?.title ?? context.tr("AI 学习助手"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            c.demo
                                ? context.tr("Mock · 隔离数据 · 不连接 API")
                                : context.tr(
                                    c.config.kind == 'chatgpt'
                                        ? "使用 ChatGPT 订阅 · {0} · {1}"
                                        : "{0} · {1}",
                                    [
                                      c.config.model,
                                      c.busy
                                          ? context.tr("正在回复")
                                          : context.tr("本地保存"),
                                    ],
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: context.tr(
                          c.selected?.toolsEnabled == true
                              ? '关闭本会话资料工具'
                              : '开启本会话资料工具',
                        ),
                        onPressed: c.busy || c.selected == null
                            ? null
                            : () => act(
                                context,
                                () => _toggleStudyTools(context, c),
                              ),
                        icon: Icon(
                          c.selected?.toolsEnabled == true
                              ? Icons.auto_stories
                              : Icons.auto_stories_outlined,
                          size: 21,
                        ),
                      ),
                    if (!compact)
                      IconButton(
                        tooltip: context.tr('关联学习资料'),
                        onPressed: () => act(
                          context,
                          () => openChatStudyLinks(context, ref),
                        ),
                        icon: const Icon(Icons.link, size: 21),
                      ),
                    const ReasoningMenu(),
                    if (c.selected != null)
                      ScratchpadButton('chat:${c.selected!.id}'),
                    if (!compact)
                      IconButton(
                        tooltip: context.tr('模型设置'),
                        onPressed: () => context.push('/settings/ai'),
                        icon: const Icon(Icons.tune, size: 21),
                      ),
                    if (compact)
                      PopupMenuButton<String>(
                        popUpAnimationStyle: menuAnimation(context),
                        key: const Key('chat-more'),
                        tooltip: context.tr('更多对话操作'),
                        icon: Badge(
                          isLabelVisible: c.selected?.toolsEnabled == true,
                          smallSize: 6,
                          child: const Icon(Icons.more_vert),
                        ),
                        onSelected: (action) {
                          if (action == 'tools') {
                            act(context, () => _toggleStudyTools(context, c));
                          }
                          if (action == 'links') {
                            act(
                              context,
                              () => openChatStudyLinks(context, ref),
                            );
                          }
                          if (action == 'settings') {
                            context.push('/settings/ai');
                          }
                        },
                        itemBuilder: (ctx) => [
                          CheckedPopupMenuItem(
                            value: 'tools',
                            checked: c.selected?.toolsEnabled == true,
                            enabled: !c.busy && c.selected != null,
                            child: Text(
                              ctx.tr(
                                c.selected?.toolsEnabled == true
                                    ? '关闭本会话资料工具'
                                    : '开启本会话资料工具',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'links',
                            enabled: c.selected != null,
                            child: Text(ctx.tr('关联学习资料')),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Text(ctx.tr('模型设置')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (c.error != null)
                MaterialBanner(
                  content: Text(context.tr(c.error!)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        c.error = null;
                        c.changed();
                      },
                      child: Text(context.tr("关闭")),
                    ),
                  ],
                ),
              Expanded(
                child: c.selected == null
                    ? _NoSession(onStart: () => act(context, c.newSession))
                    : Conversation(key: ValueKey(c.selected!.id)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _toggleStudyTools(BuildContext context, AppController c) async {
  final session = c.selected;
  if (session == null || c.busy) return;
  if (session.toolsEnabled) {
    await c.setTools(false);
    return;
  }
  final approved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('允许本会话使用学习资料？')),
      content: Text(
        ctx.tr('AI 可以检索相关知识和错题，并读取选中的资料正文。新增、修改、删除和关联仍须由你逐项确认。图片不会通过检索工具自动上传。'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('允许')),
        ),
      ],
    ),
  );
  if (approved == true && context.mounted && c.selected?.id == session.id) {
    await c.setTools(true);
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            context.tr("每个问题，都值得弄懂"),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr("输入文字或上传题目图片，和 AI 一起理清思路。"),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onStart, child: Text(context.tr("开始新的学习对话"))),
        ],
      ),
    ),
  );
}

class Conversation extends ConsumerStatefulWidget {
  const Conversation({super.key});
  @override
  ConsumerState<Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<Conversation> {
  final _scroll = ScrollController();
  late final TextEditingController _input;
  final _focus = FocusNode();
  bool _stick = true;
  // Text of the last sent message. The field stays editable while a send is
  // being prepared, so the auto-clear below must only wipe the field when it
  // still shows exactly what was sent — otherwise it would discard text the
  // user typed after tapping send.
  String? _lastSent;
  Size? _reportedViewport;
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: ref.read(appControllerProvider).selected?.draft ?? '',
    );
    _scroll.addListener(() {
      final stick =
          !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.offset < 160;
      if (stick != _stick) setState(() => _stick = stick);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = ref.read(appControllerProvider);
    final before = _input.text;
    _lastSent = before;
    final future = c.send(before);
    await future;
    if (!mounted) return;
    if (c.selected?.draft.isEmpty == true && _input.text == before) {
      _input.clear();
    }
  }

  Future<void> _import(String type) async {
    final c = ref.read(appControllerProvider);
    await act(context, () async {
      final picked = await pickPhotos(
        context,
        takePhoto: type == 'camera',
        filesOnly: type == 'file',
      );
      final added = <Attachment>[];
      for (final file in picked) {
        added.add(await c.addImage(file.path));
      }
      for (final image in added) {
        if (!mounted) break;
        await editChatPhoto(context, c, image);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final keyboard =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        View.of(context).viewInsets.bottom > 0;
    final shortInput = keyboard || MediaQuery.sizeOf(context).height < 700;
    final showQuickActions = c.messages.isNotEmpty && !c.busy && !shortInput;
    final viewport = MediaQuery.sizeOf(context);
    if (c.demo && _reportedViewport != viewport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        RenderBox? input, send;
        void visit(Element e) {
          if (e.widget.key == const Key('chat-input')) {
            input = e.findRenderObject() as RenderBox?;
          }
          if (e.widget.key == const Key('send-message')) {
            send = e.findRenderObject() as RenderBox?;
          }
          e.visitChildElements(visit);
        }

        context.visitChildElements(visit);
        if (input?.hasSize == true && send?.hasSize == true) {
          final ratio = MediaQuery.devicePixelRatioOf(context);
          final p =
              input!.localToGlobal(
                Offset(input!.size.width / 2, input!.size.height / 2),
              ) *
              ratio;
          final button =
              send!.localToGlobal(send!.size.center(Offset.zero)) * ratio;
          debugPrint('TIXUN_COMPOSER_POINT ${p.dx.round()} ${p.dy.round()}');
          debugPrint(
            'TIXUN_SEND_POINT ${button.dx.round()} ${button.dy.round()}',
          );
          _reportedViewport = viewport;
        }
      });
    }

    final pending = c.attachments.where((a) => a.messageId == null).toList();
    if (_stick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _stick) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    // Clear immediately after the user message has committed, including during streaming.
    // Only wipe the field when it still shows exactly the sent text: the
    // field stays editable while the send is prepared, so the user may have
    // typed past it already.
    if (c.selected?.draft.isEmpty == true &&
        c.busy &&
        _input.text.isNotEmpty &&
        _input.text == _lastSent) {
      _input.clear();
    }
    return LayoutBuilder(
      builder: (context, constraints) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter, control: true):
              _SendIntent(),
        },
        child: Actions(
          actions: {
            _SendIntent: CallbackAction<_SendIntent>(
              onInvoke: (_) {
                // Read the live state: typing does not rebuild this widget,
                // so the emptiness check must not rely on build-time values.
                final hasText = _input.text.trim().isNotEmpty;
                final hasPending = c.attachments.any(
                  (a) => a.messageId == null,
                );
                if (!c.busy && (hasText || hasPending)) _send();
                return null;
              },
            ),
          },
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    c.messages.isEmpty
                        ? SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 24),
                                      Text(
                                        context.tr("今天，想弄懂什么？"),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        context.tr(
                                          "不必先把问题整理得很完美。\n告诉我卡在哪里，或者直接发一张题目图片。",
                                        ),
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          height: 1.8,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      for (final prompt in [
                                        '二次函数的顶点公式，怎样理解而不是死记？',
                                        '我会做这道题，但不知道为什么要用这个方法。',
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: OutlinedButton(
                                            onPressed: () {
                                              _input.text = prompt;
                                              c.draft(prompt);
                                              _focus.requestFocus();
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              child: Text(prompt),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            key: PageStorageKey('messages-${c.selected!.id}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            itemCount:
                                c.messages.length +
                                (c.pendingTool != null ? 1 : 0),
                            itemBuilder: (context, index) =>
                                index == c.messages.length
                                ? Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 790,
                                      ),
                                      child: const ToolApprovalCard(),
                                    ),
                                  )
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 790,
                                      ),
                                      child: MessageView(
                                        message: c.messages[index],
                                        isLast: index == c.messages.length - 1,
                                      ),
                                    ),
                                  ),
                          ),
                    if (c.messages.isNotEmpty && !_stick)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          heroTag: 'scroll-to-bottom',
                          tooltip: context.tr("回到最新消息"),
                          onPressed: () {
                            setState(() => _stick = true);
                            if (_scroll.hasClients) {
                              _scroll.jumpTo(_scroll.position.maxScrollExtent);
                            }
                          },
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                  ],
                ),
              ),
              // Hide optional actions while typing, leaving room for photos
              // and the send button above the keyboard.
              Visibility(
                visible: showQuickActions,
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final text in [
                        '给我提示',
                        '换种方式解释',
                        '讲简单一点',
                        '直接给答案',
                        '再出一道题',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              context.tr(text),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              _input.text = context.tr(text);
                              c.draft(context.tr(text));
                              _focus.requestFocus();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (constraints.maxHeight - (showQuickActions ? 40 : 0))
                          .clamp(0.0, double.infinity),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Visibility(
                              visible: !keyboard,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: AppSelectField<String>(
                                          compact: true,
                                          initialValue: c.selected!.mode,
                                          style: TextStyle(
                                            fontFamily: 'NotoSansSC',
                                            fontSize: 12,
                                            color: colors.primary,
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'guided',
                                              child: Text(context.tr("引导教学")),
                                            ),
                                            DropdownMenuItem(
                                              value: 'direct',
                                              child: Text(context.tr("直接解答")),
                                            ),
                                            DropdownMenuItem(
                                              value: 'exam',
                                              child: Text(context.tr("考试训练")),
                                            ),
                                          ],
                                          onChanged: c.busy
                                              ? null
                                              : (v) => act(
                                                  context,
                                                  () => c.mode(v!),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          c.selected!.mode == 'exam'
                                              ? context.tr("先提交答案，再查看反馈与解析")
                                              : context.tr("先理解，再独立尝试"),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLowest,
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  if (pending.isNotEmpty)
                                    SizedBox(
                                      height: shortInput ? 64 : 96,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.all(8),
                                        children: pending
                                            .map(
                                              (a) => Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    AttachmentImage(
                                                      attachment: a,
                                                      width: 88,
                                                      height: shortInput
                                                          ? 48
                                                          : 80,
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      top: 0,
                                                      // 48dp hit area around
                                                      // the small 28dp visual
                                                      // circle, so removing a
                                                      // draft image is easy to
                                                      // hit without covering
                                                      // the thumbnail.
                                                      child: Tooltip(
                                                        message: context.tr(
                                                          "移除图片",
                                                        ),
                                                        child: Semantics(
                                                          button: true,
                                                          label: context.tr(
                                                            "移除图片",
                                                          ),
                                                          child: GestureDetector(
                                                            behavior:
                                                                HitTestBehavior
                                                                    .opaque,
                                                            onTap: c.busy
                                                                ? null
                                                                : () => act(
                                                                    context,
                                                                    () => c
                                                                        .removeImage(
                                                                          a,
                                                                        ),
                                                                  ),
                                                            child: SizedBox(
                                                              width: 48,
                                                              height: 48,
                                                              child: Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topRight,
                                                                child: Container(
                                                                  width: 28,
                                                                  height: 28,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        c.busy
                                                                        ? colors.secondaryContainer.withValues(
                                                                            alpha:
                                                                                .38,
                                                                          )
                                                                        : colors
                                                                              .secondaryContainer,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                                  child: Icon(
                                                                    Icons.close,
                                                                    size: 16,
                                                                    color: colors
                                                                        .onSecondaryContainer,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: const Key('chat-input'),
                                          scrollPadding: EdgeInsets.fromLTRB(
                                            20,
                                            20,
                                            20,
                                            keyboard ? 80 : 20,
                                          ),
                                          controller: _input,
                                          focusNode: _focus,
                                          // Typing a draft stays possible while a
                                          // generation runs; only sending is gated
                                          // (the send button becomes a stop button
                                          // while busy, and send() refuses while
                                          // busy). The draft is saved via onChanged.
                                          onChanged: c.draft,
                                          minLines: 1,
                                          maxLines: 1,
                                          maxLength: 32000,
                                          decoration: InputDecoration(
                                            hintText: context.tr(
                                              "写下你的问题，或添加题目图片…",
                                            ),
                                            counterText: '',
                                            filled: false,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 14,
                                                ),
                                          ),
                                        ),
                                      ),
                                      c.busy
                                          ? IconButton.filled(
                                              key: const Key('stop-generation'),
                                              tooltip: context.tr("停止生成"),
                                              onPressed: c.stop,
                                              icon: const Icon(
                                                Icons.stop_rounded,
                                              ),
                                            )
                                          : ValueListenableBuilder<
                                              TextEditingValue
                                            >(
                                              valueListenable: _input,
                                              builder: (context, value, _) {
                                                // The right-hand slot morphs
                                                // with state: with nothing to
                                                // send it offers adding an
                                                // image; once there is text —
                                                // or a pending image — it
                                                // becomes the send button.
                                                // The image button therefore
                                                // only ever appears while the
                                                // input is empty, and the
                                                // field width never jumps.
                                                final canSend =
                                                    value.text
                                                        .trim()
                                                        .isNotEmpty ||
                                                    c.attachments.any(
                                                      (a) =>
                                                          a.messageId == null,
                                                    );
                                                if (!canSend) {
                                                  return PopupMenuButton<
                                                    String
                                                  >(
                                                    popUpAnimationStyle:
                                                        menuAnimation(context),
                                                    tooltip: context.tr("添加图片"),
                                                    enabled: !c.busy,
                                                    icon: const Icon(
                                                      Icons
                                                          .add_photo_alternate_outlined,
                                                      size: 23,
                                                    ),
                                                    onSelected: _import,
                                                    itemBuilder: (_) => [
                                                      if (Platform
                                                          .isAndroid) ...[
                                                        PopupMenuItem(
                                                          value: 'camera',
                                                          child: Text(
                                                            context.tr("拍照"),
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'gallery',
                                                          child: Text(
                                                            context.tr("从相册选择"),
                                                          ),
                                                        ),
                                                      ],
                                                      PopupMenuItem(
                                                        value: 'file',
                                                        child: Text(
                                                          context.tr("选择图片文件"),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }
                                                return IconButton.filled(
                                                  key: const Key(
                                                    'send-message',
                                                  ),
                                                  tooltip: context.tr(
                                                    "发送（Ctrl+Enter）",
                                                  ),
                                                  onPressed: () =>
                                                      act(context, _send),
                                                  icon: const Icon(
                                                    Icons.arrow_upward_rounded,
                                                  ),
                                                );
                                              },
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class MessageView extends ConsumerWidget {
  const MessageView({required this.message, required this.isLast, super.key});
  final ChatMessage message;
  final bool isLast;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final user = message.role == 'user';
    final colors = Theme.of(context).colorScheme;
    final images = c.attachments.where((a) => a.messageId == message.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Align(
              alignment: user ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: images
                      .map(
                        (a) => AttachmentImage(
                          attachment: a,
                          width: 190,
                          height: 150,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          if (!user)
            MessageReasoning(
              message,
              examGenerating:
                  message.status == 'generating' && c.selected?.mode == 'exam',
            ),
          if (message.content.isNotEmpty)
            user
                ? Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: SelectableText(
                          message.content,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  )
                : LearningMarkdown(message.content),
          if (!user) MessageQuestions(message.id),
          if (!user) ToolHistory(message.id),
          if (message.status == 'generating')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: c.pendingTool == null
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          )
                        : Icon(
                            Icons.fact_check_outlined,
                            size: 12,
                            color: colors.primary,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.pendingTool == null
                        ? context.tr("正在思考与组织回答…")
                        : context.tr("等待确认资料操作…"),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (message.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                context.tr(message.error!),
                style: TextStyle(
                  fontSize: 12,
                  color: message.status == 'error'
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          if (message.status != 'generating')
            Row(
              children: [
                IconButton(
                  tooltip: context.tr("复制消息"),
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr("消息已复制"))),
                      );
                    }
                  },
                ),
                ChatStudyMenu(message: message),
                if (user)
                  IconButton(
                    tooltip: context.tr("编辑并在新分支重问"),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    onPressed: c.busy
                        ? null
                        : () async {
                            final text = await editText(
                              context,
                              title: context.tr("编辑并重问（保留原会话）"),
                              initial: message.content,
                              multiline: true,
                            );
                            if (text != null && context.mounted) {
                              await act(
                                context,
                                () => c.editAndResend(message, text),
                              );
                            }
                          },
                  ),
                if (!user && isLast)
                  TextButton.icon(
                    onPressed: c.busy ? null : () => act(context, c.regenerate),
                    icon: const Icon(Icons.refresh, size: 17),
                    label: Text(
                      context.tr("重新生成"),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (!user && message.totalTokens != null)
                  Expanded(
                    child: Text(
                      '${message.totalTokens} tokens',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({
    required this.attachment,
    required this.width,
    required this.height,
    super.key,
  });
  final Attachment attachment;
  final double width, height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appControllerProvider);
    final file = c.files.resolve(attachment.relativePath);
    Widget picture({bool preview = false}) => Image.file(
      file,
      width: preview ? null : width,
      height: preview ? null : height,
      fit: BoxFit.contain,
      cacheWidth: preview ? 1600 : 500,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(context.tr("图片无法读取"), textAlign: TextAlign.center),
        ),
      ),
    );
    return Semantics(
      label: context.tr("题目图片，点击预览"),
      button: true,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        attachment.originalPath == null
                            ? context.tr("原图预览")
                            : context.tr("发送图片预览"),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr("关闭预览"),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(child: picture(preview: true)),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (attachment.originalPath != null)
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (ctx) => Dialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(width: 16),
                                    Expanded(child: Text(context.tr("保留的原图"))),
                                    IconButton(
                                      tooltip: context.tr("关闭原图"),
                                      onPressed: () => Navigator.pop(ctx),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                Flexible(
                                  child: InteractiveViewer(
                                    child: Image.file(
                                      c.files.resolve(attachment.originalPath!),
                                      cacheWidth: 1600,
                                      errorBuilder: (_, _, _) =>
                                          Text(context.tr("原图无法读取。")),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: Text(context.tr("查看保留的原图")),
                      ),
                    if (attachment.messageId == null)
                      TextButton.icon(
                        key: Key('edit-draft-image-${attachment.id}'),
                        onPressed: c.busy
                            ? null
                            : () => act(context, () async {
                                Navigator.pop(dialogContext);
                                await editChatPhoto(context, c, attachment);
                              }),
                        icon: const Icon(Icons.crop, size: 18),
                        label: Text(context.tr("裁剪 / 旋转 / 缩小")),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    context.tr("原图单独保留在此设备，发送时使用当前预览的图片。"),
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: picture(),
          ),
        ),
      ),
    );
  }
}

Future<void> editChatPhoto(
  BuildContext context,
  AppController c,
  Attachment image,
) async {
  await showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => StudyImageEditor(
      attachment: StudyAttachment(
        id: image.id,
        relativePath: image.relativePath,
        mime: image.mime,
        byteLength: image.byteLength,
        role: 'original',
        deleted: false,
      ),
      isMistake: true,
      title: '编辑题目图片',
      createLabel: '保存图片编辑',
      allowSplit: false,
      onCreate: (bytes, _, _) => c.replaceDraftImage(image, bytes),
    ),
  );
}
