part of "chat_screen.dart";

extension _ChatComposer on _ConversationState {
  Widget _composer(
    BuildContext context,
    AppController c,
    ColorScheme colors,
    BoxConstraints constraints,
    List<Attachment> pending,
    Size viewport, {
    required bool keyboard,
    required bool shortInput,
    required String? sessionId,
    required bool reserveQuickActions,
  }) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: (constraints.maxHeight - (reserveQuickActions ? 40 : 0)).clamp(
        0.0,
        double.infinity,
      ),
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
                                fontFamily: "NotoSansSC",
                                fontSize: 12,
                                color: colors.primary,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: "guided",
                                  child: Text(context.l10n.guidedLearning),
                                ),
                                DropdownMenuItem(
                                  value: "direct",
                                  child: Text(context.l10n.directAnswer),
                                ),
                                DropdownMenuItem(
                                  value: "exam",
                                  child: Text(context.l10n.examPractice),
                                ),
                              ],
                              onChanged: c.busy
                                  ? null
                                  : (v) => act(context, () => c.mode(v!)),
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
                      color: colors.outlineVariant.withValues(alpha: .8),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: .045),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        AttachmentImage(
                                          attachment: a,
                                          width: 88,
                                          height: shortInput ? 48 : 80,
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
                                            message: context.l10n.removeImage,
                                            child: Semantics(
                                              button: true,
                                              label: context.l10n.removeImage,
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: c.busy
                                                    ? null
                                                    : () => act(
                                                        context,
                                                        () => c.removeImage(a),
                                                      ),
                                                child: SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.topRight,
                                                    child: Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        color: c.busy
                                                            ? colors
                                                                  .secondaryContainer
                                                                  .withValues(
                                                                    alpha: .38,
                                                                  )
                                                            : colors
                                                                  .secondaryContainer,
                                                        shape: BoxShape.circle,
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key("chat-input"),
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
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 32000,
                              decoration: InputDecoration(
                                hintText: viewport.width < 600
                                    ? context.l10n.chatCompactInputHint
                                    : context.l10n.askAQuestionOrAdd,
                                counterText: "",
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            key: const Key("chat-add-photo"),
                            popUpAnimationStyle: menuAnimation(context),
                            tooltip: context.l10n.addPhotos,
                            enabled: !c.busy,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 21,
                            ),
                            onSelected: _import,
                            itemBuilder: (_) => [
                              if (Platform.isAndroid) ...[
                                PopupMenuItem(
                                  value: "camera",
                                  child: Text(context.l10n.takePhoto),
                                ),
                                PopupMenuItem(
                                  value: "gallery",
                                  child: Text(context.l10n.chooseFromPhotos),
                                ),
                              ],
                              PopupMenuItem(
                                value: "file",
                                child: Text(context.l10n.chooseImageFile),
                              ),
                            ],
                          ),
                          IconButton(
                            key: const Key("chat-markdown-fullscreen"),
                            tooltip: context.l10n.markdownOpenFull,
                            icon: const Icon(
                              Icons.open_in_full_outlined,
                              size: 19,
                            ),
                            onPressed: c.selected == null
                                ? null
                                : () async {
                                    final sessionId = c.selected!.id;
                                    final result = await showMarkdownEditor(
                                      context,
                                      title: context.l10n.markdownEditor,
                                      initialValue: _input.value,
                                      maxLength: 32000,
                                      previewBuilder: (ctx, text) =>
                                          VisualMarkdown(
                                            text,
                                            sessionId: sessionId,
                                          ),
                                    );
                                    if (!mounted ||
                                        result == null ||
                                        c.selected?.id != sessionId) {
                                      return;
                                    }
                                    _input.value = result;
                                    await c.draft(result.text);
                                  },
                          ),
                          c.busy
                              ? IconButton.filled(
                                  key: const Key("stop-generation"),
                                  tooltip: context.l10n.stopGenerating,
                                  onPressed: c.stop,
                                  icon: const Icon(Icons.stop_rounded),
                                )
                              : ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _input,
                                  builder: (context, value, _) {
                                    final canSend =
                                        value.text.trim().isNotEmpty ||
                                        c.attachments.any(
                                          (a) => a.messageId == null,
                                        );
                                    if (canSend && c.demo) {
                                      _scheduleComposerReport(
                                        viewport,
                                        sessionId,
                                      );
                                    }
                                    return IconButton.filled(
                                      key: canSend
                                          ? const Key("send-message")
                                          : null,
                                      tooltip: context.l10n.sendCtrlEnter,
                                      onPressed: canSend
                                          ? () => act(context, _send)
                                          : null,
                                      icon: const Icon(
                                        Icons.arrow_upward_rounded,
                                      ),
                                    );
                                  },
                                ),
                          const SizedBox(width: 4),
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
  );
}
