part of "chat_screen.dart";

extension _ChatMessagePanel on _ConversationState {
  Widget _messagesPanel(
    BuildContext context,
    AppController c,
    ColorScheme colors,
  ) => Expanded(
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notice) {
        if (notice.depth == 0) _followBottom();
        return false;
      },
      child: Stack(
        children: [
          c.messages.isEmpty
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.auto_awesome_outlined,
                                color: colors.onPrimaryContainer,
                                size: 23,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              context.l10n.whatWouldYouLikeToUnderstand,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.yourQuestionDoesNotNeed,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.8,
                              ),
                            ),
                            const SizedBox(height: 28),
                            for (final (prompt, icon) in [
                              (
                                context.l10n.chatStarterConcept,
                                Icons.lightbulb_outline_rounded,
                              ),
                              (
                                context.l10n.chatStarterMethod,
                                Icons.account_tree_outlined,
                              ),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: colors.surfaceContainerLow,
                                    side: BorderSide(
                                      color: colors.outlineVariant.withValues(
                                        alpha: .55,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: () {
                                    _input.text = prompt;
                                    unawaited(c.draft(prompt));
                                    _focus.requestFocus();
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 20,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          prompt,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.north_east_rounded,
                                        size: 16,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : _anchorIndex != null && _anchorIndex! < c.messages.length
              ? CustomScrollView(
                  controller: _scroll,
                  center: _anchorKey,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: _anchorIndex!,
                        itemBuilder: (context, index) => Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 790),
                            child: MessageView(
                              message: c.messages[_anchorIndex! - index - 1],
                              isLast: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      key: _anchorKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      sliver: SliverList.builder(
                        itemCount:
                            c.messages.length -
                            _anchorIndex! +
                            (c.pendingTool != null ? 1 : 0),
                        itemBuilder: (context, offset) {
                          final index = _anchorIndex! + offset;
                          return Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 790),
                              child: index == c.messages.length
                                  ? const ToolApprovalCard()
                                  : MessageView(
                                      key: ValueKey(
                                        "message-${c.messages[index].id}",
                                      ),
                                      message: c.messages[index],
                                      isLast: index == c.messages.length - 1,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  key: PageStorageKey("messages-${c.selected!.id}"),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  itemCount:
                      c.messages.length + (c.pendingTool != null ? 1 : 0),
                  findChildIndexCallback: (key) {
                    if (key == const ValueKey("tool-approval")) {
                      return c.pendingTool == null ? null : c.messages.length;
                    }
                    final index = c.messages.indexWhere(
                      (m) => ValueKey(m.id) == key,
                    );
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) => index == c.messages.length
                      ? Align(
                          key: const ValueKey("tool-approval"),
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 790),
                            child: const ToolApprovalCard(),
                          ),
                        )
                      : Align(
                          key: ValueKey(c.messages[index].id),
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 790),
                            child: MessageView(
                              message: c.messages[index],
                              isLast: index == c.messages.length - 1,
                            ),
                          ),
                        ),
                ),
          if (c.messages.isNotEmpty && !_stick && !_scrolling)
            Positioned(
              right: 16,
              bottom: 16,
              child: IconButton.filledTonal(
                key: const Key("chat-scroll-bottom"),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest.withValues(
                    alpha: .88,
                  ),
                  foregroundColor: colors.onSurface,
                  shape: const CircleBorder(),
                ),
                tooltip: context.l10n.backToLatestMessage,
                onPressed: () {
                  _stickToBottom();
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                },
                icon: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    ),
  );
}
