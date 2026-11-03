import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/ai/chat_provider.dart';
import '../core/database/database.dart';
import '../core/platform/attachment_store.dart';
import '../core/platform/key_store.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw StateError('AppController must be initialized'),
);

class AppController extends ChangeNotifier {
  AppController(
    this.db,
    this.files,
    this.keys,
    this.provider, {
    this.demo = false,
  });
  final AppDatabase db;
  final AttachmentStore files;
  final KeyStore keys;
  final ChatProvider provider;
  final bool demo;
  late ProviderConfig config;
  List<ChatSession> sessions = [];
  List<ChatSession> allSessions = [];
  List<ChatMessage> messages = [];
  List<Attachment> attachments = [];
  ChatSession? selected;
  ThemeMode themeMode = ThemeMode.system;
  bool busy = false;
  String? error;
  CancelToken? _cancel;
  Future<void>? _generation;
  Completer<void>? _preparation;
  int _epoch = 0;
  bool _disposed = false;
  String search = '';
  String? notice;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  static Future<AppController> open({required bool demo}) async {
    final Directory root;
    if (demo) {
      root = await Directory.systemTemp.createTemp('tixun-demo-');
    } else {
      root = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'tixun'),
      );
      await root.create(recursive: true);
    }
    final db = demo
        ? AppDatabase.memory()
        : AppDatabase.file(File(p.join(root.path, 'tixun.sqlite')));
    final c = AppController(
      db,
      AttachmentStore(root),
      demo ? MemoryKeyStore() : const SecureKeyStore(),
      demo ? MockChatProvider() : OpenAiChatProvider(),
      demo: demo,
    );
    try {
      await c.initialize();
    } catch (_) {
      await db.close();
      rethrow;
    }
    return c;
  }

  Future<void> initialize() async {
    config = await db.config();
    themeMode = switch (await db.preference('theme')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    if (demo) await seedDemo();
    await reload();
    final lastId = await db.preference('selected_session');
    final last = sessions.where((s) => s.id == lastId).firstOrNull;
    if (last != null) await selectSession(last);
  }

  Future<void> seedDemo() async {
    final s = await db.createSession(title: '二次函数：从配方理解顶点');
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'demo-user',
            sessionId: s.id,
            role: 'user',
            content: '二次函数的顶点公式总是记不住，能帮我理解一下吗？',
            createdAt: DateTime(2026, 11, 3, 9),
          ),
        );
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'demo-answer',
            sessionId: s.id,
            role: 'assistant',
            content: MockChatProvider.explanation,
            model: const Value('Mock · 离线演示'),
            totalTokens: const Value(368),
            createdAt: DateTime(2026, 11, 3, 9, 0, 1),
          ),
        );
    await db.createSession(title: '英语阅读：怎样理解长难句');
    await db.createSession(title: '物理 · 受力分析的学习计划');
    final demoSessions = await db.sessions();
    for (final item in demoSessions) {
      final hour = item.id == s.id
          ? 11
          : item.title.startsWith('英语')
          ? 10
          : 9;
      await (db.update(
        db.chatSessions,
      )..where((t) => t.id.equals(item.id))).write(
        ChatSessionsCompanion(
          createdAt: Value(DateTime(2026, 11, 3, hour)),
          updatedAt: Value(DateTime(2026, 11, 3, hour)),
        ),
      );
    }
    await db.setPreference('selected_session', s.id);
  }

  Future<void> reload() async {
    allSessions = await db.sessions();
    sessions = search.isEmpty ? allSessions : await db.sessions(search);
    changed();
  }

  Future<void> searchSessions(String value) async {
    search = value;
    final result = await db.sessions(value);
    if (search == value) {
      sessions = result;
      changed();
    }
  }

  Future<void> selectSession(ChatSession session) async {
    await stop();
    await _loadSession(session);
  }

  Future<void> _loadSession(ChatSession session) async {
    final current = ++_epoch;
    final loaded = await Future.wait<Object>([
      db.messages(session.id),
      db.images(session.id),
    ]);
    if (_epoch != current) return;
    selected = await (db.select(
      db.chatSessions,
    )..where((s) => s.id.equals(session.id))).getSingle();
    messages = loaded[0] as List<ChatMessage>;
    attachments = loaded[1] as List<Attachment>;
    error = null;
    await db.setPreference('selected_session', session.id);
    changed();
  }

  Future<void> newSession() async {
    await stop();
    await selectSession(await db.createSession());
    search = '';
    await reload();
  }

  Future<void> renameSession(ChatSession s, String title) async {
    await db.rename(s.id, title);
    await reload();
    if (selected?.id == s.id) {
      selected = selected!.copyWith(title: title.trim());
      changed();
    }
  }

  Future<void> deleteSession(ChatSession s) async {
    if (selected?.id == s.id) {
      await stop();
      selected = null;
      messages = [];
      attachments = [];
    }
    await db.setDeleted(s.id, true);
    await reload();
  }

  Future<void> restoreSession(ChatSession s) async {
    await db.setDeleted(s.id, false);
    await reload();
  }

  Future<void> draft(String value) async {
    final s = selected;
    if (s == null) return;
    selected = s.copyWith(draft: value);
    try {
      await db.saveDraft(s.id, value);
    } catch (_) {
      error = '草稿保存失败，请检查可用存储空间。';
      changed();
    }
  }

  Future<void> mode(String value) async {
    if (selected == null || busy) return;
    final s = selected!.copyWith(mode: value, stage: 'diagnosing');
    await db.update(db.chatSessions).replace(s);
    selected = s;
    changed();
  }

  Future<void> addImage(String path) async {
    if (busy) return;
    if (selected == null) await newSession();
    final s = selected!;
    if (attachments.where((a) => a.messageId == null).length >= 4) {
      throw const FormatException('一次最多添加 4 张图片。');
    }
    final image = await files.importFile(path);
    try {
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: const Uuid().v4(),
              sessionId: s.id,
              relativePath: image.path,
              mime: image.mime,
              byteLength: image.bytes,
            ),
          );
    } catch (_) {
      await files.resolve(image.path).delete();
      rethrow;
    }
    if (selected?.id == s.id) {
      attachments = await db.images(s.id);
      changed();
    }
  }

  Future<void> removeImage(Attachment image) async {
    if (busy || image.messageId != null) return;
    await (db.delete(db.attachments)..where((a) => a.id.equals(image.id))).go();
    attachments = await db.images(selected!.id);
    changed();
    // Files remain recoverable until a future storage-maintenance pass.
  }

  Future<void> _startRequest(Future<String> Function() prepare) async {
    busy = true;
    error = null;
    final ready = Completer<void>();
    _preparation = ready;
    changed();
    try {
      final sessionId = await prepare();
      _generation = _generate(sessionId);
      ready.complete();
      _preparation = null;
      await _generation;
    } catch (_) {
      error = '消息保存失败，请检查存储空间后重试。';
      busy = false;
      changed();
    } finally {
      if (!ready.isCompleted) ready.complete();
      if (identical(_preparation, ready)) _preparation = null;
    }
  }

  Future<void> send(String input) async {
    if (busy ||
        (input.trim().isEmpty &&
            !attachments.any((a) => a.messageId == null))) {
      return;
    }
    await _startRequest(() async {
      if (selected == null) {
        selected = await db.createSession();
        messages = [];
        attachments = [];
      }
      final s = selected!;
      final userId = const Uuid().v4();
      final now = DateTime.now();
      await db.transaction(() async {
        await db
            .into(db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: userId,
                sessionId: s.id,
                role: 'user',
                content: input.trim().isEmpty ? '请帮我理解图片中的题目。' : input.trim(),
                createdAt: now,
              ),
            );
        await (db.update(db.attachments)
              ..where((a) => a.sessionId.equals(s.id) & a.messageId.isNull()))
            .write(AttachmentsCompanion(messageId: Value(userId)));
        await (db.update(
          db.chatSessions,
        )..where((t) => t.id.equals(s.id))).write(
          ChatSessionsCompanion(
            draft: const Value(''),
            updatedAt: Value(now),
            title: messages.isEmpty
                ? Value(
                    input.trim().isEmpty
                        ? '图片题目'
                        : input.trim().characters.take(30).toString(),
                  )
                : const Value.absent(),
          ),
        );
      });
      selected = await (db.select(
        db.chatSessions,
      )..where((t) => t.id.equals(s.id))).getSingle();
      await db.setPreference('selected_session', s.id);
      await _refreshSelected();
      await reload();
      return s.id;
    });
  }

  Future<void> _refreshSelected() async {
    final id = selected?.id;
    if (id == null) return;
    messages = await db.messages(id);
    attachments = await db.images(id);
    changed();
  }

  Future<void> _generate(String sessionId) async {
    busy = true;
    if (demo) debugPrint('TIXUN_GENERATION_STARTED');
    final cancel = CancelToken();
    _cancel = cancel;
    final id = const Uuid().v4();
    final requestConfig = config;
    final timer = Timer(
      const Duration(minutes: 3),
      () => cancel.cancel('timeout'),
    );
    var text = '';
    var status = 'complete';
    String? failure;
    int? tokens;
    var lastWrite = DateTime.now();
    try {
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: id,
              sessionId: sessionId,
              role: 'assistant',
              content: '',
              status: const Value('generating'),
              model: Value(demo ? 'Mock · 离线演示' : requestConfig.model),
              createdAt: DateTime.now(),
            ),
          );
      await _refreshSelected();
      final history = messages.where((m) => m.id != id).toList();
      final body = await completionBody(
        requestConfig,
        history,
        attachments,
        files,
        selected!.mode,
      );
      String? key;
      try {
        key = demo ? '' : await keys.read(providerKeyId(requestConfig));
      } catch (_) {
        throw const AiFailure(
          '系统安全存储不可用。Linux 请启用并解锁 Secret Service 密钥环；应用不会明文保存密钥。',
        );
      }
      cancel.checkCancelled();
      await for (final chunk in provider.complete(
        requestConfig,
        key ?? '',
        body,
        cancel,
      )) {
        text += chunk.text;
        tokens = chunk.tokens ?? tokens;
        if (DateTime.now().difference(lastWrite).inMilliseconds >= 80) {
          await _writeMessage(id, text, 'generating', null, tokens);
          await _refreshSelected();
          lastWrite = DateTime.now();
        }
      }
      if (text.trim().isEmpty) throw const AiFailure('模型没有返回可显示的正文，请重试。');
    } on AiFailure catch (e) {
      status = 'error';
      failure = e.message;
    } on DioException catch (e) {
      status = CancelToken.isCancel(e) ? 'stopped' : 'error';
      failure = cancel.cancelError?.error == 'timeout'
          ? '生成超时，已保留部分内容。'
          : (status == 'stopped' ? '已停止生成。' : '网络请求失败，请重试。');
    } catch (_) {
      status = 'error';
      failure = '生成失败。请检查安全存储是否可用、图片文件及服务设置。';
    } finally {
      timer.cancel();
      try {
        await _writeMessage(id, text, status, failure, tokens);
        await (db.update(
          db.chatSessions,
        )..where((s) => s.id.equals(sessionId))).write(
          ChatSessionsCompanion(
            stage: Value(text.isNotEmpty ? 'explaining' : 'diagnosing'),
          ),
        );
        await _refreshSelected();
        await reload();
      } catch (_) {
        error = '回复保存失败，当前内容可能未写入磁盘。';
      }
      busy = false;
      _cancel = null;
      if (demo) debugPrint('TIXUN_GENERATION_FINISHED status=$status');
      changed();
    }
  }

  Future<void> _writeMessage(
    String id,
    String text,
    String status,
    String? error,
    int? tokens,
  ) async {
    await (db.update(db.chatMessages)..where((m) => m.id.equals(id))).write(
      ChatMessagesCompanion(
        content: Value(text),
        status: Value(status),
        error: Value(error),
        totalTokens: Value(tokens),
      ),
    );
  }

  Future<void> stop() async {
    _cancel?.cancel('user');
    await _preparation?.future;
    _cancel?.cancel('user');
    await _generation;
  }

  Future<void> regenerate() async {
    if (busy || selected == null || messages.isEmpty) return;
    await _startRequest(() async {
      final last = messages.last;
      if (last.role == 'assistant') {
        await (db.delete(
          db.chatMessages,
        )..where((m) => m.id.equals(last.id))).go();
      }
      await _refreshSelected();
      return selected!.id;
    });
  }

  Future<void> editAndResend(ChatMessage message, String text) async {
    if (busy || text.trim().isEmpty || selected == null) return;
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0 || message.role != 'user') return;
    // Preserve original messages in a new branch so editing never destroys history.
    await _startRequest(() async {
      final originalImages = attachments;
      final branch = await db.createSession(title: '${selected!.title} · 重问');
      await db.transaction(() async {
        for (final m in messages.take(index + 1)) {
          final newId = const Uuid().v4();
          await db
              .into(db.chatMessages)
              .insert(
                m.copyWith(
                  id: newId,
                  sessionId: branch.id,
                  content: m.id == message.id ? text.trim() : m.content,
                ),
              );
          for (final a in originalImages.where((a) => a.messageId == m.id)) {
            await db
                .into(db.attachments)
                .insert(
                  a.copyWith(
                    id: const Uuid().v4(),
                    sessionId: branch.id,
                    messageId: Value(newId),
                  ),
                );
          }
        }
      });
      await _loadSession(branch);
      await reload();
      return branch.id;
    });
  }

  Future<void> saveSettings(ProviderConfig next, String? key) async {
    validateConfig(next);
    if (key != null) await keys.write(providerKeyId(next), key.trim());
    await db.saveConfig(next);
    config = next;
    changed();
  }

  Future<void> testConnection(ProviderConfig candidate, String? key) async {
    validateConfig(candidate);
    final secret = key?.trim().isNotEmpty == true
        ? key!.trim()
        : await keys.read(providerKeyId(candidate)) ?? '';
    final cancel = CancelToken();
    final timer = Timer(
      const Duration(seconds: 35),
      () => cancel.cancel('timeout'),
    );
    try {
      await for (final chunk in provider.complete(candidate, secret, {
        'model': candidate.model,
        'messages': [
          {'role': 'user', 'content': '只回复 OK'},
        ],
        'stream': true,
        'max_tokens': 16,
        if (candidate.kind == 'deepseek') 'thinking': {'type': 'disabled'},
      }, cancel)) {
        if (chunk.text.isNotEmpty) {
          cancel.cancel();
          return;
        }
      }
      throw const AiFailure('连接成功但没有收到正文。');
    } finally {
      timer.cancel();
    }
  }

  Future<void> theme(ThemeMode value) async {
    await db.setPreference('theme', value.name);
    themeMode = value;
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> shutdown() async {
    await stop();
    dispose();
    await db.close();
    if (demo && await files.root.exists()) {
      await files.root.delete(recursive: true);
    }
  }
}
