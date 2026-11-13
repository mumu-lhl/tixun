import 'dart:convert';

import '../../core/l10n/app_error.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/l10n/generated/app_localizations.dart';

// Legacy persisted assistant errors were Chinese source messages. This list is
// intentionally limited to known app-authored AI failures; unrecognized
// provider/user text is never translated. New writes use stable codes instead.
const _historicChatFailures = <String, AppErrorCode>{
  "系统安全存储不可用。Linux 请启用并解锁 Secret Service 密钥环；应用不会明文保存密钥。":
      AppErrorCode.secureStorageUnavailableLinux,
  "资料工具需要支持工具调用的模型，并关闭深度思考。":
      AppErrorCode.materialToolsRequireModelWithoutThinking,
  "资料工具需要支持工具调用的模型。": AppErrorCode.materialToolsRequireToolCapableModel,
  "此会话启用了资料工具，请选择支持工具调用的模型并关闭深度思考，或关闭本会话资料工具。":
      AppErrorCode.conversationDataToolsRequireModelWithoutThinking,
  "此会话启用了资料工具，请选择支持工具调用的模型，或关闭本会话资料工具。":
      AppErrorCode.conversationDataToolsRequireToolCapableModel,
  "连接测试已取消。": AppErrorCode.connectionTestCancelled,
  "回复达到长度上限，可继续提问。": AppErrorCode.theResponseReachedItsLength,
  "API Key 无效或没有访问权限，请检查设置。": AppErrorCode.theAPIKeyIsInvalid,
  "API 余额不足，请在服务商平台检查。": AppErrorCode.insufficientAPIBalanceCheckYour,
  "请求过于频繁，请稍后重试。": AppErrorCode.tooManyRequestsTryAgain,
  "模型或请求参数不被服务支持，请检查地址、模型与能力设置。": AppErrorCode.theServiceDoesNotSupport,
  "网络连接失败或服务暂时不可用，请检查网络后重试。": AppErrorCode.theConnectionFailedOrThe,
  "ChatGPT 登录已失效，请重新登录。": AppErrorCode.yourChatGPTSignInHas,
  "ChatGPT 订阅额度或权限不可用，请在 ChatGPT 中检查用量。不会转用 API 计费。":
      AppErrorCode.chatGPTPlanAllowanceOrPermissions,
  "ChatGPT 不支持当前模型或参数，请刷新模型列表或改用模型默认思考设置。":
      AppErrorCode.chatGptUnsupportedModelOrParameter,
  "ChatGPT 请求失败，请检查网络后重试。": AppErrorCode.theChatGPTRequestFailedCheck,
  "ChatGPT 服务返回了错误，请刷新模型列表或重新登录后重试。":
      AppErrorCode.chatGPTReturnedAnErrorRefresh,

  "会话不存在，请重新选择会话。": AppErrorCode.errorTheConversationNoLongerExistsSelect,
  "AI 完成后仍返回数据。": AppErrorCode.errorTheAIReturnedDataAfterCompletion,
  "AI 回复过长。": AppErrorCode.errorTheAIResponseIsTooLong,
  "本次小分表整理不允许工具调用。": AppErrorCode.errorToolCallsAreNotAllowedWhile,
  "连接提前断开，未应用小分表。": AppErrorCode.errorTheConnectionClosedEarlyTheScore,
  "一次最多允许 8 个工具调用。": AppErrorCode.errorAtMost8ToolCallsAre,
  "工具调用索引无效。": AppErrorCode.errorInvalidToolCallIndex,
  "工具调用 ID 无效。": AppErrorCode.errorInvalidToolCallID,
  "工具参数片段无效。": AppErrorCode.errorInvalidToolArgumentFragment,
  "工具调用数据过长。": AppErrorCode.errorToolCallDataIsTooLong,
  "工具调用不完整或 ID 重复。": AppErrorCode.errorToolCallsAreIncompleteOrHave,
  "模拟网络失败：可点击重新生成验证重试流程。":
      AppErrorCode.errorSimulatedNetworkFailureSelectRegenerateTo,
  "摘要为空，未压缩上下文。": AppErrorCode.errorTheSummaryIsEmptyTheContext,

  "ChatGPT 回复字段类型不兼容，请重试并反馈此提示。":
      AppErrorCode.chatGPTReturnedIncompatibleResponseFields,
  "ChatGPT 回复格式无效，请重试。": AppErrorCode.invalidChatGPTResponseFormatTry,
  "ChatGPT 回复结束事件不完整，请重试并反馈此提示。": AppErrorCode.theChatGPTCompletionEventWas,
  "ChatGPT 工具上下文过大，请新建会话。": AppErrorCode.chatGPTToolContextIsToo,
  "ChatGPT 授权服务地址无效。": AppErrorCode.invalidChatGPTAuthorizationServiceURL,
  "ChatGPT 授权服务身份无效。": AppErrorCode.invalidChatGPTAuthorizationServiceIdentity,
  "ChatGPT 授权未完成，请重新登录并确认订阅使用权限。":
      AppErrorCode.chatGPTAuthorizationWasNotCompleted,
  "ChatGPT 未完成回复，已保留收到的内容。请重试。": AppErrorCode.chatGPTDidNotCompleteThe,
  "ChatGPT 模型列表格式无效。": AppErrorCode.invalidChatGPTModelCatalog,
  "ChatGPT 流式事件无法解析，请重试并检查网络或代理。": AppErrorCode.couldNotParseAChatGPT,
  "ChatGPT 登录回调无效，请重新登录。": AppErrorCode.invalidChatGPTSignInCallback,
  "ChatGPT 登录失败，请检查网络、系统时间和安全存储后重试。": AppErrorCode.chatGPTSignInFailedCheck,
  "ChatGPT 登录已改变，请重新发送。": AppErrorCode.chatGPTSignInChangedSend,
  "ChatGPT 登录续期失败，请重新登录。": AppErrorCode.couldNotRenewChatGPTSign,
  "ChatGPT 登录记录无法读取，请检查系统安全存储。": AppErrorCode.couldNotReadChatGPTSign,
  "ChatGPT 登录超时，请重试。": AppErrorCode.chatGPTSignInTimedOut,
  "ChatGPT 账号已切换，请重新发送。": AppErrorCode.theChatGPTAccountChangedSend,
  "ChatGPT 账号身份校验失败，请重新登录。": AppErrorCode.chatGPTIdentityVerificationFailedSign,
  "ChatGPT 返回了无法识别的回复格式，请检查服务后重试。":
      AppErrorCode.chatGPTReturnedAnUnrecognizedFormat,
  "ChatGPT 返回了网页而不是 AI 回复，请检查网络或代理后重试。": AppErrorCode.chatGPTReturnedAWebPage,
  "ChatGPT 非流式回复过大，请新建会话或重试。": AppErrorCode.theNonStreamingChatGPTResponse,
  "上次生成被中断，可重新生成。": AppErrorCode.previousGenerationInterrupted,
  "交互出题需要支持工具调用的模型。请先在设置中调整。": AppErrorCode.interactiveQuestionsNeedATool,
  "修改前必须完整读取所选知识；正文过长时请先手动拆分，避免覆盖未读取的内容。":
      AppErrorCode.theSelectedKnowledgeMustBe,
  "工具响应未正常结束，未执行本轮资料修改。": AppErrorCode.theToolResponseDidNot,
  "工具调用格式无效。": AppErrorCode.invalidToolCallFormat,
  "已停止生成。": AppErrorCode.generationStopped,
  "已取消 ChatGPT 登录。": AppErrorCode.chatGPTSignInCancelled,
  "已有 ChatGPT 登录正在进行。": AppErrorCode.aChatGPTSignInIs,
  "已达到 4 轮工具调用限制。已完成的资料修改仍然保留，可继续提问。": AppErrorCode.theLimitOf4Tool,
  "已达到本次最多 8 个工具调用的限制。": AppErrorCode.thisRequestReachedTheLimit,
  "已阻止修改未选中的资料，请重新发起整理。": AppErrorCode.editingAnUnselectedItemWas,
  "当前任务需要非思考工具调用，请保持关闭；普通讲解可在其他会话开启。": AppErrorCode.thisTaskRequiresNonThinking,
  "当前对话包含图片，所选模型不支持视觉。请切换到 Flash 或启用支持图片的模型。":
      AppErrorCode.thisConversationContainsImagesBut,
  "当前模型未声明支持思考参数。": AppErrorCode.theCurrentModelHasNot,
  "无法打开系统浏览器，请检查浏览器设置。": AppErrorCode.couldNotOpenSystemBrowser,
  "无法读取 ChatGPT 模型列表，请检查网络或重新登录。": AppErrorCode.couldNotLoadChatGPTModels,
  "服务未返回 SSE 流，请检查 API 地址和模型。": AppErrorCode.theServiceDidNotReturn,
  "服务返回错误，请检查模型配置后重试。": AppErrorCode.theServiceReturnedAnError,
  "模型声明调用工具，但没有提供完整调用。": AppErrorCode.theModelRequestedATool,
  "模型尝试调用未开放的工具，已阻止。": AppErrorCode.anUnavailableToolCallWas,
  "模型没有返回可显示的正文，请重试。": AppErrorCode.theModelReturnedNoDisplayable,
  "模型返回了无法解析的流式数据，请重试。": AppErrorCode.theModelReturnedUnreadableStream,
  "正在退出 ChatGPT，请稍后重试。": AppErrorCode.signingOutOfChatGPTTry,
  "生成失败。请检查安全存储是否可用、图片文件及服务设置。":
      AppErrorCode.generationFailedCheckSecureStorage,
  "生成超时，已保留部分内容。": AppErrorCode.generationTimedOutPartialContent,
  "登录账号与所选账号不一致，原登录记录未更改。": AppErrorCode.theSignedInIdentityDiffers,
  "等待回复超时，已保留收到的内容。": AppErrorCode.theResponseTimedOutReceived,
  "网络请求失败，请重试。": AppErrorCode.theNetworkRequestFailedTry,
  "请先使用 Continue with ChatGPT 登录。": AppErrorCode.signInUsingContinueWith,
  "请先停止生成，再调整本会话思考强度。": AppErrorCode.stopGeneratingBeforeChangingReasoning,
  "请先在设置中保存 API Key，或开启离线 Mock。": AppErrorCode.saveAnAPIKeyIn,
  "请选择已保存的 ChatGPT 账号。": AppErrorCode.selectASavedChatGPTAccount,
  "账号未授予 ChatGPT 订阅推理权限，请重新授权。": AppErrorCode.thisAccountHasNotGranted,
  "资料整理任务无效，请重新发起。": AppErrorCode.thisWritingTaskIsInvalid,
  "连接成功但没有收到正文。": AppErrorCode.connectedButNoResponseText,
  "连接提前断开，已保留收到的内容。请重新生成。": AppErrorCode.theConnectionEndedEarlyReceived,
};

String encodeChatFailure(
  AppErrorCode code, [
  List<String> arguments = const [],
]) => arguments.isEmpty
    ? '$chatFailurePrefix${code.name}'
    : '$chatFailurePrefix${jsonEncode({'code': code.name, 'arguments': arguments})}';

const _rawChatFailurePrefix = '\u001etixun.raw:';

/// Distinguish new provider text from ambiguous, pre-code historical errors.
String encodeRawChatFailure(String value) => '$_rawChatFailurePrefix$value';

String chatFailureText(AppLocalizations l10n, String stored) {
  if (stored.startsWith(_rawChatFailurePrefix)) {
    return stored.substring(_rawChatFailurePrefix.length);
  }
  AppErrorCode? code;
  var arguments = <String>[];
  if (stored.startsWith(chatFailurePrefix)) {
    var name = stored.substring(chatFailurePrefix.length);
    if (name.startsWith('{')) {
      try {
        final data = jsonDecode(name);
        if (data is! Map ||
            data['code'] is! String ||
            data['arguments'] is! List ||
            !(data['arguments'] as List).every((value) => value is String)) {
          return stored;
        }
        name = data['code'] as String;
        arguments = (data['arguments'] as List).cast<String>();
      } on FormatException {
        return stored;
      }
    }
    code = AppErrorCode.values.where((value) => value.name == name).firstOrNull;
  } else {
    code = _historicChatFailures[stored];
  }
  return code == null ? stored : appErrorText(l10n, code, arguments);
}
