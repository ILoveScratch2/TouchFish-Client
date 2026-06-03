import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  static const double _contentMaxWidth = 1200;
  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  final _endpointController = TextEditingController(text: '/auth/login');
  final _requestBodyController = TextEditingController(text: '{\n}');

  TfDebugRequestResult? _result;
  bool _isSending = false;
  bool _includeCredentials = false;
  bool _encryptRequest = true;
  TfDebugRequestMethod _requestMethod = TfDebugRequestMethod.post;

  bool get _hasCredentials {
    return AuthState.instance.uid != null && AuthState.instance.password != null;
  }

  bool get _canEncryptRequest => _requestMethod == TfDebugRequestMethod.post;

  @override
  void initState() {
    super.initState();
    _includeCredentials = _hasCredentials;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _requestBodyController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Map<String, dynamic> _parseRequestBody(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('Request body must be a JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _formatJsonLike(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return value;
    }

    try {
      return _prettyJsonEncoder.convert(jsonDecode(trimmed));
    } catch (_) {
      return value;
    }
  }

  String _requestMethodLabel(
    AppLocalizations l10n,
    TfDebugRequestMethod method,
  ) {
    switch (method) {
      case TfDebugRequestMethod.get:
        return l10n.debugApiTesterMethodGet;
      case TfDebugRequestMethod.post:
        return l10n.debugApiTesterMethodPost;
    }
  }

  String _requestEditorLabel(AppLocalizations l10n) {
    return _requestMethod == TfDebugRequestMethod.get
        ? l10n.debugApiTesterQueryParameters
        : l10n.debugApiTesterRequestBody;
  }

  String _requestEditorHint(AppLocalizations l10n) {
    return _requestMethod == TfDebugRequestMethod.get
        ? l10n.debugApiTesterQueryParametersHint
        : l10n.debugApiTesterRequestBodyHint;
  }

  String _requestPayloadLabel(
    AppLocalizations l10n,
    TfDebugRequestResult result,
  ) {
    if (result.method == TfDebugRequestMethod.get) {
      return l10n.debugApiTesterQueryParameters;
    }
    return result.requestEncrypted
        ? l10n.debugApiTesterEncodedBody
        : l10n.debugApiTesterRequestPayload;
  }

  Future<void> _sendRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final endpoint = _endpointController.text.trim();

    if (endpoint.isEmpty) {
      _showMessage(l10n.debugApiTesterInvalidEndpoint);
      return;
    }

    if (_includeCredentials && !_hasCredentials) {
      _showMessage(l10n.debugApiTesterCredentialsUnavailable);
      return;
    }

    late final Map<String, dynamic> requestBody;
    try {
      requestBody = _parseRequestBody(_requestBodyController.text);
    } on FormatException {
      _showMessage(l10n.debugApiTesterInvalidBody);
      return;
    }

    setState(() => _isSending = true);

    final result = await TfApiClient.instance.debugRequest(
      _requestMethod,
      endpoint,
      requestBody,
      encryptRequest: _canEncryptRequest && _encryptRequest,
      uid: _includeCredentials ? AuthState.instance.uid : null,
      password: _includeCredentials ? AuthState.instance.password : null,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
      _result = result;
    });
  }

  Widget _buildCodeSection(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: colorScheme.outlineVariant),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.debugApiTester,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.debugApiTesterDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: l10n.debugApiTesterEndpoint,
                helperText: l10n.debugApiTesterEndpointHint,
                prefixIcon: const Icon(Icons.route_outlined),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TfDebugRequestMethod>(
                initialValue: _requestMethod,
              decoration: InputDecoration(
                labelText: l10n.debugApiTesterMethod,
                prefixIcon: const Icon(Icons.swap_horiz_rounded),
              ),
              items: TfDebugRequestMethod.values
                  .map(
                    (method) => DropdownMenuItem<TfDebugRequestMethod>(
                      value: method,
                      child: Text(_requestMethodLabel(l10n, method)),
                    ),
                  )
                  .toList(),
              onChanged: _isSending
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _requestMethod = value);
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _includeCredentials,
              title: Text(l10n.debugApiTesterUseCredentials),
              subtitle: Text(
                _hasCredentials
                    ? l10n.debugApiTesterUseCredentialsDescription
                    : l10n.debugApiTesterNoCredentials,
              ),
              onChanged: _hasCredentials
                  ? (value) {
                      setState(() => _includeCredentials = value);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _encryptRequest,
              title: Text(l10n.debugApiTesterEncryptRequest),
              subtitle: Text(
                _canEncryptRequest
                    ? l10n.debugApiTesterEncryptRequestDescription
                    : l10n.debugApiTesterEncryptRequestUnavailableForGet,
              ),
              onChanged: _canEncryptRequest
                  ? (value) {
                      setState(() => _encryptRequest = value);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _requestBodyController,
              minLines: 12,
              maxLines: 18,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: _requestEditorLabel(l10n),
                hintText: _requestEditorHint(l10n),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSending ? null : _sendRequest,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.debugApiTesterSendRequest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, AppLocalizations l10n) {
    final result = _result;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.debugApiTesterResultTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.debugApiTesterResultDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (result == null)
              Text(
                l10n.debugApiTesterAwaitingResult,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                '${l10n.debugApiTesterStatus}: ${result.statusCode == null ? l10n.debugApiTesterStatusUnavailable : 'HTTP ${result.statusCode}'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.requestUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCodeSection(
                  context,
                  label: l10n.debugApiTesterRequestUrl,
                  value: result.requestUrl,
                ),
              ],
              if (result.requestPayload.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCodeSection(
                  context,
                  label: _requestPayloadLabel(l10n, result),
                  value: _formatJsonLike(result.requestPayload),
                ),
              ],
              if (result.decodedResponseBody?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildCodeSection(
                  context,
                  label: l10n.debugApiTesterDecryptedResponse,
                  value: _formatJsonLike(result.decodedResponseBody!),
                ),
              ],
              if (result.rawResponseBody?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildCodeSection(
                  context,
                  label: l10n.debugApiTesterRawResponse,
                  value: _formatJsonLike(result.rawResponseBody!),
                ),
              ],
              if (result.errorMessage?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildCodeSection(
                  context,
                  label: l10n.debugApiTesterError,
                  value: result.errorMessage!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugApiTester)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useWideLayout = constraints.maxWidth >= 960;
              final children = [
                useWideLayout
                    ? Expanded(child: _buildRequestCard(context, l10n))
                    : _buildRequestCard(context, l10n),
                useWideLayout
                    ? const SizedBox(width: 16)
                    : const SizedBox(height: 16),
                useWideLayout
                    ? Expanded(child: _buildResultCard(context, l10n))
                    : _buildResultCard(context, l10n),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: useWideLayout
                    ? IntrinsicHeight(child: Row(children: children))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}