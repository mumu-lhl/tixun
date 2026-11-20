part of 'chat_screen.dart';

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
      padding: const EdgeInsets.only(bottom: 20),
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
          if (!user) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 15,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.aiLearningAssistant,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            MessageReasoning(
              message,
              examGenerating:
                  message.status == 'generating' && c.selected?.mode == 'exam',
            ),
          ],
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
                          color: colors.primaryContainer.withValues(alpha: .72),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: SelectableText(
                          message.content,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  )
                : VisualMarkdown(
                    message.content,
                    sessionId: message.sessionId,
                    messageId: message.id,
                    streaming: message.status == 'generating',
                  ),
          if (!user && message.content.isEmpty)
            VisualMarkdown(
              '',
              sessionId: message.sessionId,
              messageId: message.id,
            ),
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
                        ? context.l10n.thinkingThroughYourQuestion
                        : context.l10n.waitingForYourConfirmation,
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
                chatFailureText(context.l10n, message.error!),
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
              mainAxisAlignment: user
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: context.l10n.copyMessage,
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.messageCopied)),
                      );
                    }
                  },
                ),
                ChatStudyMenu(message: message),
                if (user)
                  IconButton(
                    tooltip: context.l10n.editAndAskInA,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    onPressed: c.busy
                        ? null
                        : () async {
                            final text = await editText(
                              context,
                              title: context.l10n.editAndAskAgainKeep,
                              initial: message.content,
                              multiline: true,
                              markdown: true,
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
                      context.l10n.regenerate,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (!user && message.model != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: ValueKey('message-usage-${message.id}'),
                        onPressed: () => _showMessageUsage(context, c, message),
                        icon: const Icon(Icons.analytics_outlined, size: 15),
                        label: Text(
                          message.totalTokens == null
                              ? context.l10n.requestDetails
                              : '${message.totalTokens} tokens',
                        ),
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
