part of "auth.dart";

extension _ChatGptLogin on ChatGptAuth {
  Future<ChatGptAccount> _signIn({String? accountId}) async {
    if (_signingOut) {
      throw const AiFailure.localized(
        AppErrorCode.signingOutOfChatGPTTry,
        "正在退出 ChatGPT，请稍后重试。",
      );
    }
    if (_login != null) {
      throw const AiFailure.localized(
        AppErrorCode.aChatGPTSignInIs,
        "已有 ChatGPT 登录正在进行。",
      );
    }
    final cancel = _login = CancelToken();
    HttpServer? server;
    Timer? timer;
    try {
      final host = await _exclusive(() async {
        final data = await _load();
        data["host"] ??= "urn:uuid:${const Uuid().v4()}";
        await _save(
          data,
        ); // Fail before opening browser if secure storage is unavailable.
        return data["host"] as String;
      });
      cancel.checkCancelled();
      final saved = _accounts(await _load());
      final old = accountId == null
          ? null
          : saved.where((a) => a.id == accountId).firstOrNull;
      if (accountId != null && old == null) {
        throw const AiFailure.localized(
          AppErrorCode.selectASavedChatGPTAccount,
          "请选择已保存的 ChatGPT 账号。",
        );
      }
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirect = "http://127.0.0.1:${server.port}/auth/callback";
      final state = _random(), nonce = _random(), verifier = _random();
      final result = Completer<Map<String, String>>();
      unawaited(
        cancel.whenCancel.then((_) {
          if (!result.isCompleted) {
            result.completeError(
              const AiFailure.localized(
                AppErrorCode.chatGPTSignInCancelled,
                "已取消 ChatGPT 登录。",
              ),
            );
          }
        }),
      );
      timer = Timer(const Duration(minutes: 3), () {
        if (!result.isCompleted) {
          result.completeError(
            const AiFailure.localized(
              AppErrorCode.chatGPTSignInTimedOut,
              "ChatGPT 登录超时，请重试。",
            ),
          );
        }
      });
      // Attach an error listener before browser launch/cancellation can complete it.
      final callback = result.future;
      unawaited(
        callback.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      server.listen((request) async {
        var accepted = false;
        try {
          final query = request.uri.queryParametersAll;
          accepted =
              request.method == "GET" &&
              request.uri.path == "/auth/callback" &&
              request.headers.value("host") == "127.0.0.1:${server!.port}" &&
              query.values.every((v) => v.length == 1) &&
              request.uri.queryParameters["state"] == state &&
              !result.isCompleted;
          if (accepted) result.complete(request.uri.queryParameters);
          request.response.statusCode = accepted ? 200 : 400;
          request.response.headers
            ..contentType = ContentType.html
            ..set("Cache-Control", "no-store")
            ..set("Referrer-Policy", "no-referrer")
            ..set("Content-Security-Policy", "default-src 'none'");
          request.response.write(
            accepted
                ? '<!doctype html><meta charset="utf-8"><p>Return to TiXun to finish signing in. 请返回题训完成登录。</p>'
                : "Invalid callback.",
          );
          await request.response.close();
        } catch (_) {
          await request.response.close();
        }
      });
      final uri = Uri.parse("$chatGptIssuer/api/accounts/authorize").replace(
        queryParameters: {
          "response_type": "code",
          "client_id": old?.clientId ?? "dynamic_agent_client",
          "agent_name_hint": "TiXun",
          "ext_agent_host_id": host,
          "redirect_uri": redirect,
          "scope": "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct",
          "resource": chatGptResource,
          "state": state,
          "nonce": nonce,
          "code_challenge_method": "S256",
          "code_challenge": base64UrlEncode(
            sha256.convert(ascii.encode(verifier)).bytes,
          ).replaceAll("=", ""),
          if (old?.data["id_token"] case final String hint)
            "id_token_hint": hint,
        },
      );
      bool opened;
      try {
        opened = await _openBrowser(uri);
      } catch (_) {
        throw const AiFailure.localized(
          AppErrorCode.couldNotOpenSystemBrowser,
          "无法打开系统浏览器，请检查浏览器设置。",
        );
      }
      if (!opened) {
        throw const AiFailure.localized(
          AppErrorCode.couldNotOpenSystemBrowser,
          "无法打开系统浏览器，请检查浏览器设置。",
        );
      }
      final answer = await callback;
      cancel.checkCancelled();
      if (answer.containsKey("error")) {
        throw const AiFailure.localized(
          AppErrorCode.chatGPTAuthorizationWasNotCompleted,
          "ChatGPT 授权未完成，请重新登录并确认订阅使用权限。",
        );
      }
      final clientId = answer["client_id"] ?? old?.clientId;
      if (clientId == null ||
          clientId == "dynamic_agent_client" ||
          !clientId.startsWith("oaiapp_") ||
          (old != null && clientId != old.clientId) ||
          (answer["code"] ?? "").isEmpty) {
        throw const AiFailure.localized(
          AppErrorCode.invalidChatGPTSignInCallback,
          "ChatGPT 登录回调无效，请重新登录。",
        );
      }
      final token = (await _client.post<Map<String, dynamic>>(
        _tokenUrl,
        data: {
          "grant_type": "authorization_code",
          "client_id": clientId,
          "code": answer["code"],
          "code_verifier": verifier,
          "redirect_uri": redirect,
          "resource": chatGptResource,
        },
        cancelToken: cancel,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      )).data!;
      final identity = await _verifyIdentity(
        token["id_token"] as String,
        clientId,
        nonce,
      );
      if (old != null && identity["sub"] != old.subject) {
        throw const AiFailure.localized(
          AppErrorCode.theSignedInIdentityDiffers,
          "登录账号与所选账号不一致，原登录记录未更改。",
        );
      }
      final record = _tokenRecord(token, {...identity, "client_id": clientId});
      cancel.checkCancelled();
      await _exclusive(() async {
        cancel.checkCancelled();
        final data = await _load();
        final account = _AccountRecord(record);
        data["accounts"] = [
          for (final a in _accounts(data))
            if (a.id != account.id) a.data,
          record,
        ];
        data["active"] = account.id;
        await _save(data);
        _accountEpoch++;
      });
      return _AccountRecord(record).summary;
    } on AiFailure {
      rethrow;
    } catch (_) {
      if (cancel.isCancelled) {
        throw const AiFailure.localized(
          AppErrorCode.chatGPTSignInCancelled,
          "已取消 ChatGPT 登录。",
        );
      }
      throw const AiFailure.localized(
        AppErrorCode.chatGPTSignInFailedCheck,
        "ChatGPT 登录失败，请检查网络、系统时间和安全存储后重试。",
      );
    } finally {
      timer?.cancel();
      await server?.close(force: true);
      _login = null;
    }
  }

  Future<Map<String, dynamic>> _verifyIdentity(
    String raw,
    String clientId,
    String nonce,
  ) async {
    // Trust keys from OpenAI discovery only, never a token-provided key or URL.
    // This also enforces the mitigation for GHSA-vm9r-h74p-hg97 independently
    // of JOSE dependency key-selection behavior.
    final parts = raw.split(".");
    if (parts.length != 3) {
      throw const AiFailure.localized(
        AppErrorCode.chatGPTIdentityVerificationFailedSign,
        "ChatGPT 账号身份校验失败，请重新登录。",
      );
    }
    final header = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
    );
    if (header is! Map ||
        header["alg"] != "RS256" ||
        ["jwk", "jku", "x5u"].any(header.containsKey)) {
      throw const AiFailure.localized(
        AppErrorCode.chatGPTIdentityVerificationFailedSign,
        "ChatGPT 账号身份校验失败，请重新登录。",
      );
    }
    final discovery = await _discovery();
    final jwks = (await _client.get<Map<String, dynamic>>(
      _trustedEndpoint(discovery["jwks_uri"]).toString(),
    )).data!;
    final store = JsonWebKeyStore()..addKeySet(JsonWebKeySet.fromJson(jwks));
    final jwt = await JsonWebToken.decodeAndVerify(
      raw,
      store,
      allowedArguments: ["RS256"],
    );
    final claims = jwt.claims;
    final now = DateTime.now();
    if (claims.issuer.toString() != chatGptIssuer ||
        !(claims.audience ?? []).contains(clientId) ||
        claims.issuedAt == null ||
        claims.expiry == null ||
        !claims.expiry!.isAfter(now) ||
        (claims.notBefore?.isAfter(now.add(const Duration(seconds: 30))) ??
            false) ||
        (claims.issuedAt?.isAfter(now.add(const Duration(seconds: 30))) ??
            false) ||
        claims["nonce"] != nonce ||
        (claims.subject ?? "").isEmpty ||
        ((claims.audience?.length ?? 0) > 1 && claims["azp"] != clientId)) {
      throw const AiFailure.localized(
        AppErrorCode.chatGPTIdentityVerificationFailedSign,
        "ChatGPT 账号身份校验失败，请重新登录。",
      );
    }
    final auth = claims["https://api.openai.com/auth"];
    return {
      "sub": claims.subject,
      "id_token": raw,
      if (claims["email"] is String) "email": claims["email"],
      if (claims["name"] is String) "name": claims["name"],
      if (auth is Map && auth["chatgpt_account_id"] is String)
        "account_id": auth["chatgpt_account_id"],
      if (auth is Map && auth["chatgpt_plan_type"] is String)
        "plan_type": auth["chatgpt_plan_type"],
    };
  }

  Map<String, dynamic> _tokenRecord(
    Map<String, dynamic> token,
    Map<String, dynamic> old,
  ) {
    final scopes = token["scope"] is String
        ? (token["scope"] as String)
              .split(" ")
              .where((s) => s.isNotEmpty)
              .toList()
        : List<String>.from(old["scopes"] as List? ?? []);
    if (!_requiredScopes.every(scopes.contains) ||
        token["token_type"]?.toString().toLowerCase() != "bearer" ||
        token["access_token"] is! String ||
        (token["access_token"] as String).isEmpty ||
        token["expires_in"] is! num ||
        (token["expires_in"] as num) <= 0 ||
        (token["expires_in"] as num) > 604800 ||
        ((token["refresh_token"] ?? old["refresh_token"]) as String? ?? "")
            .isEmpty) {
      throw const AiFailure.localized(
        AppErrorCode.thisAccountHasNotGranted,
        "账号未授予 ChatGPT 订阅推理权限，请重新授权。",
      );
    }
    return {
      ...old,
      "access_token": token["access_token"],
      "refresh_token": token["refresh_token"] ?? old["refresh_token"],
      "scopes": scopes,
      "expires_at": DateTime.now()
          .add(Duration(seconds: (token["expires_in"] as num).toInt()))
          .toUtc()
          .toIso8601String(),
    };
  }
}
