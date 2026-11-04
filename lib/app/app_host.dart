import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/backup/backup_actions.dart';
import '../core/backup/backup_service.dart';
import '../core/platform/backup_file_picker.dart';
import '../core/ui/actions.dart';
import 'app.dart';
import 'controller.dart';
import 'theme.dart';

class TixunHost extends StatefulWidget {
  const TixunHost({
    required this.root,
    required this.demo,
    this.initialController,
    this.instanceLock,
    this.initialError,
    super.key,
  });
  final Directory root;
  final bool demo;
  final AppController? initialController;
  final RandomAccessFile? instanceLock;
  final String? initialError;
  @override
  State<TixunHost> createState() => _TixunHostState();
}

class _TixunHostState extends State<TixunHost> {
  AppController? _controller;
  ProviderContainer? _container;
  late String? _failure = widget.initialError;
  bool _working = false, _detached = false;
  String _operation = '';
  late final BackupActions _actions = BackupActions(
    export: _export,
    prepare: (file) =>
        _work('正在校验备份…', () => BackupService.prepare(file, widget.root)),
    prepareUndo: () =>
        _work('正在检查安全副本…', () => BackupService.preparePrevious(widget.root)),
    restore: _restore,
  );
  @override
  void initState() {
    super.initState();
    if (widget.initialController != null) _install(widget.initialController!);
  }

  void _install(AppController c) {
    _controller = c;
    _container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((ref) => c),
        backupActionsProvider.overrideWithValue(_actions),
      ],
    );
    _detached = false;
    _failure = null;
  }

  @override
  void dispose() {
    _container?.dispose();
    unawaited(() async {
      await _controller?.shutdown();
      await widget.instanceLock?.close();
    }());
    super.dispose();
  }

  Future<T> _work<T>(String message, Future<T> Function() action) async {
    if (_working) throw const FormatException('另一项备份操作尚未完成。');
    setState(() {
      _working = true;
      _operation = message;
    });
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _export() => _work('正在生成完整备份…', () async {
    final c = _controller!;
    await c.stop();
    await c.practice.flushDrafts();
    final temp = await Directory(
      p.join((await getTemporaryDirectory()).path, 'tixun-backup-export'),
    ).create(recursive: true);
    final file = File(
      p.join(
        temp.path,
        'tixun-${DateTime.now().millisecondsSinceEpoch}.tixun-backup',
      ),
    );
    try {
      await BackupService.export(c.db, c.files, file);
      if (await BackupFilePicker.save(file, p.basename(file.path))) {
        c.notice = '完整备份已导出，不包含 API Key。';
        c.changed();
      }
    } finally {
      if (await file.exists()) await file.delete();
    }
  });
  Future<void> _restore(PreparedBackup prepared) =>
      _work('正在恢复学习数据…', () async {
        final old = _controller;
        BackupActivation? receipt;
        AppController? opened;
        try {
          await old?.stop();
          await old?.practice.flushDrafts();
          if (old != null &&
              !await File(p.join(widget.root.path, 'tixun.sqlite')).exists()) {
            await old.db.customStatement('VACUUM INTO ?', [
              p.join(widget.root.path, 'tixun.sqlite'),
            ]);
          }
          setState(() => _detached = true);
          await WidgetsBinding.instance.endOfFrame;
          _container?.dispose();
          _container = null;
          await old?.db.close();
          receipt = await BackupService.activate(prepared, widget.root);
          opened = await AppController.openRoot(
            widget.root,
            demo: widget.demo,
            keyStore: old?.keys,
            chatProvider: old?.provider,
          );
          await BackupService.finish(receipt);
          PaintingBinding.instance.imageCache
            ..clear()
            ..clearLiveImages();
          opened.notice = '学习数据已恢复。可以在设置中撤销上次恢复；系统密钥保持原样。';
          if (mounted) {
            setState(() => _install(opened!));
          } else {
            await opened.db.close();
          }
        } catch (_) {
          await opened?.db.close();
          if (receipt != null) await BackupService.rollback(receipt);
          try {
            final recovered = await AppController.openRoot(
              widget.root,
              demo: widget.demo,
              keyStore: old?.keys,
              chatProvider: old?.provider,
            );
            recovered.notice = '恢复未完成，原学习数据已保留。';
            if (mounted) {
              setState(() => _install(recovered));
            } else {
              await recovered.db.close();
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _controller = null;
                _detached = false;
                _failure = '无法重新打开资料。原目录或安全副本仍保留，请从备份恢复。';
              });
            }
          }
          throw const FormatException('恢复未完成，已尝试保留并重新打开原数据。');
        }
      });
  Future<void> _retry() => _work('正在打开资料…', () async {
    await BackupService.recoverPending(widget.root);
    final c = await AppController.openRoot(
      widget.root,
      demo: widget.demo,
      seed:
          widget.demo &&
          !await File(p.join(widget.root.path, 'tixun.sqlite')).exists(),
    );
    if (mounted) {
      setState(() => _install(c));
    } else {
      await c.db.close();
    }
  });
  Widget _errorPage() => MaterialApp(
    theme: appTheme(Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_failure ?? '正在切换数据…', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (!_detached)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _working ? null : () => act(ctx, _retry),
                        child: const Text('重试打开'),
                      ),
                      FilledButton(
                        onPressed: _working
                            ? null
                            : () => act(ctx, () async {
                                final file = await BackupFilePicker.open();
                                if (file == null) return;
                                final prepared = await _actions.prepare(file);
                                try {
                                  if (!ctx.mounted) return;
                                  final info = prepared.preview;
                                  final ok = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dialog) => AlertDialog(
                                      title: const Text('恢复备份？'),
                                      content: Text(
                                        '包含 ${info.counts['chats'] ?? 0} 段对话、${info.counts['knowledge'] ?? 0} 条知识和 ${info.counts['mistakes'] ?? 0} 道错题。当前目录保留为最近一次安全副本；已有系统密钥不会更改。',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, false),
                                          child: const Text('取消'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, true),
                                          child: const Text('恢复数据'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await _restore(prepared);
                                } finally {
                                  await prepared.discard();
                                }
                              }),
                        child: const Text('从备份恢复'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        if (_container != null && !_detached)
          UncontrolledProviderScope(
            container: _container!,
            child: const TixunApp(),
          )
        else
          _errorPage(),
        if (_working)
          Positioned.fill(
            child: Material(
              color: Colors.black45,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xfffafbf8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _operation,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff1b2521),
                          fontFamily: 'NotoSansSC',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
