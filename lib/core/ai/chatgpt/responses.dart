import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../database/database.dart';
import '../chat_provider.dart';
import 'auth.dart';

class RoutedChatProvider implements ChatProvider {
  RoutedChatProvider(this.chatGpt, {ChatProvider? api, Dio? client})
    : api = api ?? OpenAiChatProvider(),
      responses = ChatGptResponses(chatGpt, client: client);
  final ChatGptAuth chatGpt;
  final ChatProvider api;
  final ChatGptResponses responses;
  @override
  Stream<AiChunk> complete(
    ProviderConfig config,
    String key,
    Map<String, dynamic> body,
    CancelToken cancel,
  ) => config.kind == 'chatgpt'
      ? responses.complete(config, key, body, cancel)
      : api.complete(config, key, body, cancel);
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

  /// The cache lives in a single controller request body across tool rounds.
  /// Encrypted reasoning is replayed only to OpenAI and never stored in messages.
  static Map<String, dynamic> requestBody(
    ProviderConfig config,
    Map<String, dynamic> body,
  ) {
    final input = <dynamic>[], instructions = <String>[];
    final cache = body['_chatgpt_tool_context'] as Map<String, dynamic>? ?? {};
    for (final row in body['messages'] as List? ?? []) {
      final message = row as Map;
      final role = message['role'];
      if (role == 'system') {
        instructions.add(message['content'].toString());
        continue;
      }
      if (role == 'tool') {
        input.add({
          'type': 'function_call_output',
          'call_id': message['tool_call_id'],
          'output': message['content'].toString(),
        });
      } else if (role == 'assistant' && message['tool_calls'] is List) {
        final calls = message['tool_calls'] as List;
        final saved = calls.isEmpty ? null : cache[(calls.first as Map)['id']];
        if (saved != null) {
          input.addAll(saved as List);
        } else {
          for (final call in calls) {
            input.add({
              'type': 'function_call',
              'namespace': 'tixun',
              'call_id': call['id'],
              'name': call['function']['name'],
              'arguments': call['function']['arguments'],
            });
          }
        }
      } else if (role == 'user' || role == 'assistant') {
        final content = message['content'];
        if (content is String || role == 'assistant') {
          input.add({
            'role': role,
            'content': content is String
                ? content
                : (content as List)
                      .where((p) => p['type'] == 'text')
                      .map((p) => p['text'])
                      .join('\n'),
          });
        } else {
          input.add({
            'role': 'user',
            'content': [
              for (final part in content as List)
                if (part['type'] == 'text')
                  {'type': 'input_text', 'text': part['text']}
                else if (part['type'] == 'image_url')
                  {'type': 'input_image', 'image_url': part['image_url']['url']}
                else
                  throw const AiFailure('ChatGPT 不支持此消息内容。'),
            ],
          });
        }
      } else {
        throw const AiFailure('ChatGPT 消息角色无效。');
      }
    }
    return {
      'model': config.model,
      'store': false,
      'stream': true,
      'input': input,
      'include': ['reasoning.encrypted_content'],
      if (instructions.isNotEmpty) 'instructions': instructions.join('\n'),
      if (config.thinking)
        'reasoning': {
          'effort': config.effort == 'max' ? 'xhigh' : config.effort,
        },
      if ((body['tools'] as List? ?? []).isNotEmpty)
        'tools': [
          {
            'type': 'namespace',
            'name': 'tixun',
            'description': 'User-approved TiXun learning data and interactive practice tools.',
            'tools': [
              for (final tool in body['tools'] as List)
                {
                  'type': 'function',
                  'name': tool['function']['name'],
                  'description': tool['function']['description'],
                  'parameters': tool['function']['parameters'],
                  'strict': false,
                },
            ],
          },
        ],
    };
  }

  @override
  Stream<AiChunk> complete(
    ProviderConfig config,
    String key,
    Map<String, dynamic> body,
    CancelToken cancel,
  ) async* {
    validateConfig(config);
    try {
      final token = await auth.accessToken(cancel: cancel);
      cancel.checkCancelled();
      final response = await client.post<ResponseBody>(
        '$chatGptResource/responses',
        data: requestBody(config, body),
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
      if (!(response.headers.value('content-type') ?? '').contains(
        'text/event-stream',
      )) {
        throw const AiFailure('ChatGPT 未返回有效的流式回复。');
      }
      await for (final chunk in decodeResponses(
        response.data!.stream.timeout(const Duration(seconds: 60)),
        body,
      )) {
        cancel.checkCancelled();
        yield chunk;
      }
    } on AiFailure {
      rethrow;
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

Stream<AiChunk> decodeResponses(
  Stream<List<int>> bytes,
  Map<String, dynamic> body,
) async* {
  var completed = false;
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
      yield AiChunk(text: event['delta'] as String);
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
        final cache = body.putIfAbsent(
          '_chatgpt_tool_context',
          () => <String, dynamic>{},
        ) as Map<String, dynamic>;
        cache[calls.first['call_id'] as String] = context;
        final parts = <dynamic>[];
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
          parts.add({
            'index': i,
            'id': call['call_id'],
            'type': 'function',
            'function': {'name': name, 'arguments': call['arguments']},
          });
        }
        yield AiChunk(toolParts: parts);
      }
      final usage = response['usage'];
      yield AiChunk(
        tokens: usage is Map && usage['total_tokens'] is int
            ? usage['total_tokens'] as int
            : null,
        finish: calls.isEmpty ? 'stop' : 'tool_calls',
      );
      completed = true;
      break;
    }
  }
  if (!completed) throw const AiFailure('连接提前断开，已保留收到的内容。请重新生成。');
}
