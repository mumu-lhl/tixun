import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../database/database.dart';
import '../chat_provider.dart';
import '../../platform/key_store.dart';
import 'auth.dart';

class RoutedChatProvider implements ChatProvider {
  RoutedChatProvider(
    this.chatGpt, {
    ChatProvider? api,
    Dio? client,
    KeyStore? keys,
  }) : api = api ?? OpenAiChatProvider(keys: keys),
       responses = ChatGptResponses(chatGpt, client: client);
  final ChatGptAuth chatGpt;
  final ChatProvider api;
  final ChatGptResponses responses;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      config.kind == 'chatgpt'
      ? responses.start(config, apiKeyOverride: apiKeyOverride)
      : api.start(config, apiKeyOverride: apiKeyOverride);
}

class ChatGptResponses implements ChatProvider {
  ChatGptResponses(this.auth, {Dio? client})
    : client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              followRedirects: false,
            ),
          );
  final ChatGptAuth auth;
  final Dio client;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    try {
      validateConfig(config);
    } on FormatException catch (e) {
      throw AiFailure(e.message);
    }
    if (apiKeyOverride != null) {
      throw const FormatException('ChatGPT 使用浏览器登录，无需 API Key。');
    }
    final context = <String, List<dynamic>>{};
    return AiConversation(
      (request, cancel) => _complete(config, request, context, cancel),
    );
  }

  Map<String, dynamic> _requestBody(
    ProviderConfig config,
    AiRequest request,
    Map<String, List<dynamic>> context,
  ) {
    final input = <dynamic>[];
    for (final m in request.messages) {
      if (m.role == AiRole.tool) {
        input.add({
          'type': 'function_call_output',
          'call_id': m.callId,
          'output': m.text,
        });
      } else if (m.calls.isNotEmpty) {
        final saved = context[m.calls.first.id];
        if (saved != null) {
          input.addAll(saved);
        } else {
          if (m.text.isNotEmpty) {
            input.add({'role': 'assistant', 'content': m.text});
          }
          for (final c in m.calls) {
            input.add({
              'type': 'function_call',
              'namespace': 'tixun',
              'call_id': c.id,
              'name': c.name,
              'arguments': c.arguments,
            });
          }
        }
      } else {
        input.add({
          'role': m.role.name,
          'content': m.images.isEmpty
              ? m.text
              : [
                  {'type': 'input_text', 'text': m.text},
                  for (final i in m.images)
                    {'type': 'input_image', 'image_url': i.dataUrl},
                ],
        });
      }
    }
    return {
      'model': config.model,
      'store': false,
      'stream': true,
      'input': input,
      // max_output_tokens is intentionally not sent here: the only
      // production caller that sets a limit is the connection test
      // (maxOutputTokens: 16), which cancels after the first text instead
      // of relying on a server-side cap. See chatgpt_test.dart.
      'include': ['reasoning.encrypted_content'],
      if (request.instructions.isNotEmpty) 'instructions': request.instructions,
      if (config.thinking)
        'reasoning': {
          'effort': AiOptions(config).effortParameter,
          if (AiOptions(config).reasoningEnabled) 'summary': 'auto',
        },
      if (request.tools.isNotEmpty)
        'tools': [
          {
            'type': 'namespace',
            'name': 'tixun',
            'description': 'User-approved TiXun learning data and interactive practice tools.',
            'tools': [
              for (final t in request.tools)
                {
                  'type': 'function',
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.parameters,
                  'strict': false,
                },
            ],
          },
        ],
    };
  }

  Stream<AiChunk> _complete(
    ProviderConfig config,
    AiRequest request,
    Map<String, List<dynamic>> context,
    CancelToken cancel,
  ) async* {
    try {
      validateConfig(config);
      final token = await auth.accessToken(cancel: cancel);
      cancel.checkCancelled();
      final response = await client.post<ResponseBody>(
        '$chatGptResource/responses',
        data: _requestBody(config, request, context),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );
      final mediaType = (response.headers.value('content-type') ?? '')
          .toLowerCase();
      final bytes = response.data!.stream.timeout(const Duration(seconds: 60));
      final responseEvents = mediaType.contains('text/event-stream')
          ? bytes
          : _compatibleResponseEvents(bytes, mediaType, cancel);
      await for (final chunk in decodeResponses(
        responseEvents,
        (id, items) => context[id] = items,
      )) {
        cancel.checkCancelled();
        yield chunk;
      }
    } on AiFailure {
      rethrow;
    } on FormatException catch (e) {
      // Configuration errors (e.g. thinking level vs model mismatch) must
      // keep their own message instead of becoming '回复格式无效'.
      throw AiFailure(e.message);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw AiFailure(switch (error.response?.statusCode) {
        401 => 'ChatGPT 登录已失效，请重新登录。',
        402 || 403 || 429 => 'ChatGPT 订阅额度或权限不可用，请在 ChatGPT 中检查用量。不会转用 API 计费。',
        400 || 404 || 422 => 'ChatGPT 不支持当前模型或参数，请刷新模型列表或改用模型默认思考设置。',
        _ => 'ChatGPT 请求失败，请检查网络后重试。',
      });
    } on TimeoutException {
      throw const AiFailure('等待回复超时，已保留收到的内容。');
    } catch (_) {
      throw const AiFailure('ChatGPT 回复格式无效，请重试。');
    }
  }
}

// A proxy can alter the media type, and a service may return a complete
// JSON Response even with stream=true. Only normalize validated Responses
// payloads; an HTML page or JSON error must never become a successful answer.
Stream<List<int>> _compatibleResponseEvents(
  Stream<List<int>> stream,
  String mediaType,
  CancelToken cancel,
) async* {
  final body = <int>[];
  await for (final bytes in stream) {
    cancel.checkCancelled();
    if (body.length + bytes.length > 2 * 1024 * 1024) {
      throw const AiFailure('ChatGPT 非流式回复过大，请新建会话或重试。');
    }
    body.addAll(bytes);
  }
  cancel.checkCancelled();
  late String text;
  try {
    text = utf8.decode(body).replaceFirst('\ufeff', '').trimLeft();
  } on FormatException {
    throw const AiFailure('ChatGPT 回复格式无效，请重试。');
  }
  if (text.startsWith('data:') ||
      text.startsWith('event:') ||
      text.startsWith(':')) {
    yield utf8.encode(text);
    return;
  }
  if (mediaType.contains('text/html') || text.startsWith('<')) {
    throw const AiFailure('ChatGPT 返回了网页而不是 AI 回复，请检查网络或代理后重试。');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw const AiFailure('ChatGPT 返回了无法识别的回复格式，请检查服务后重试。');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const AiFailure('ChatGPT 回复格式无效，请重试。');
  }
  if (decoded['error'] != null) {
    final error = decoded['error'];
    final code = error is Map ? error['code'] : null;
    // Never display raw server messages: they may echo user input or tokens.
    throw AiFailure(switch (code) {
      'subscription_sharing_usage_limit_exceeded' ||
      'subscription_sharing_usage_unavailable' ||
      'insufficient_quota' ||
      'rate_limit_exceeded' =>
        'ChatGPT 订阅额度或权限不可用，请在 ChatGPT 中检查用量。不会转用 API 计费。',
      'invalid_api_key' ||
      'invalid_token' ||
      'token_expired' => 'ChatGPT 登录已失效，请重新登录。',
      'model_not_found' ||
      'invalid_request_error' ||
      'unsupported_value' => 'ChatGPT 不支持当前模型或参数，请刷新模型列表或改用模型默认思考设置。',
      _ => 'ChatGPT 服务返回了错误，请刷新模型列表或重新登录后重试。',
    });
  }
  if (decoded['status'] != 'completed' || decoded['output'] is! List) {
    throw const AiFailure('ChatGPT 未完成回复，已保留收到的内容。请重试。');
  }
  yield utf8.encode(
    'data: ${jsonEncode({'type': 'response.completed', 'response': decoded})}\n\n',
  );
}

Stream<AiChunk> decodeResponses(
  Stream<List<int>> bytes,
  void Function(String id, List<dynamic> context)? retainContext,
) async* {
  var completed = false, summarySeen = false, textSeen = false;
  await for (final data in sseData(bytes)) {
    if (data == '[DONE]') break;
    Map<String, dynamic> event;
    try {
      event = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      throw const AiFailure('ChatGPT 回复格式无效，请重试。');
    }
    final type = event['type'];
    if ([
          'response.output_text.delta',
          'response.refusal.delta',
        ].contains(type) &&
        event['delta'] is String) {
      textSeen = textSeen || (event['delta'] as String).isNotEmpty;
      yield AiChunk(text: event['delta'] as String);
    } else if (type == 'response.reasoning_summary_text.delta' &&
        event['delta'] is String) {
      summarySeen = true;
      yield AiChunk(reasoning: event['delta'] as String);
    } else if ([
      'response.failed',
      'response.incomplete',
      'error',
    ].contains(type)) {
      final error = type == 'error'
          ? event
          : (event['response'] as Map?)?['error'];
      final code = error is Map ? error['code'] : null;
      throw AiFailure(
        [
              'subscription_sharing_usage_limit_exceeded',
              'subscription_sharing_usage_unavailable',
            ].contains(code)
            ? 'ChatGPT 订阅额度或权限不可用，请在 ChatGPT 中检查用量。不会转用 API 计费。'
            : 'ChatGPT 未完成回复，已保留收到的内容。请重试。',
      );
    } else if (type == 'response.completed') {
      final response = event['response'] as Map?;
      if (response == null ||
          response['status'] != 'completed' ||
          response['output'] is! List) {
        throw const AiFailure('ChatGPT 回复格式无效，请重试。');
      }
      final output = response['output'] as List;
      if (!textSeen) {
        for (final item in output.whereType<Map>()) {
          if (item['type'] != 'message' || item['content'] is! List) continue;
          for (final part in (item['content'] as List).whereType<Map>()) {
            final text = part['type'] == 'output_text'
                ? part['text']
                : part['type'] == 'refusal'
                ? part['refusal']
                : null;
            if (text is String && text.isNotEmpty) yield AiChunk(text: text);
          }
        }
      }
      if (!summarySeen) {
        for (final item in output.whereType<Map>()) {
          if (item['type'] != 'reasoning') continue;
          for (final part
              in (item['summary'] as List? ?? []).whereType<Map>()) {
            if (part['type'] == 'summary_text' && part['text'] is String) {
              yield AiChunk(reasoning: part['text'] as String);
            }
          }
        }
      }
      final calls = output
          .where((o) => o is Map && o['type'] == 'function_call')
          .toList();
      if (calls.length > 8) throw const AiFailure('已达到本次最多 8 个工具调用的限制。');
      if (calls.isNotEmpty) {
        final context = output
            .where(
              (o) =>
                  o is Map &&
                  ['reasoning', 'function_call', 'message'].contains(o['type']),
            )
            .toList();
        if (jsonEncode(context).length > 2 * 1024 * 1024) {
          throw const AiFailure('ChatGPT 工具上下文过大，请新建会话。');
        }
        final parts = <ToolCall>[];

        for (var i = 0; i < calls.length; i++) {
          final call = calls[i] as Map;
          if (call['call_id'] is! String ||
              call['name'] is! String ||
              call['arguments'] is! String ||
              (call['namespace'] != null && call['namespace'] != 'tixun')) {
            throw const AiFailure('工具调用格式无效。');
          }
          final name = (call['name'] as String).replaceFirst(
            RegExp(r'^tixun\.'),
            '',
          );
          parts.add(
            ToolCall(
              call['call_id'] as String,
              name,
              call['arguments'] as String,
            ),
          );
        }
        validateToolCalls(parts);
        retainContext?.call(parts.first.id, context);
        yield AiChunk(
          calls: parts,
          completed: true,
          tokens: response['usage'] is Map
              ? response['usage']['total_tokens'] as int?
              : null,
        );
      }
      if (calls.isNotEmpty) {
        completed = true;
        break;
      }
      final usage = response['usage'];
      yield AiChunk(
        tokens: usage is Map && usage['total_tokens'] is int
            ? usage['total_tokens'] as int
            : null,
        completed: true,
      );
      completed = true;
      break;
    }
  }
  if (!completed) throw const AiFailure('连接提前断开，已保留收到的内容。请重新生成。');
}
