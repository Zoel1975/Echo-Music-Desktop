/// Translation settings + action for the player lyrics UI.
/// Port of Android's `AiSettingsScreen` + `LyricsMenu` translation flow:
/// the user enters a provider/API key/model/endpoint, chooses a target
/// language and mode, and receives translated lines (with cached results and
/// live status via `LyricsService.translationHelper`).
import 'package:flutter/material.dart';

import 'package:Echo/services/lyrics.dart';
import 'package:Echo/services/lyrics_translation.dart' as translation;
import 'package:Echo/services/translation_settings.dart';

const translationProviders = ['OpenRouter', 'ApiRoute', 'DeepL', 'Mistral', 'Custom'];
const translationModes = ['Translate', 'Romanized', 'Transcribed'];

class TranslationDialog extends StatefulWidget {
  const TranslationDialog({
    super.key,
    required this.lines,
    required this.service,
    required this.settings,
    this.onResult,
  });

  /// The non-empty lyrics lines to translate.
  final List<String> lines;
  final LyricsService service;
  final TranslationSettings settings;
  final void Function(List<String>)? onResult;

  @override
  State<TranslationDialog> createState() => _TranslationDialogState();
}

class _TranslationDialogState extends State<TranslationDialog> {
  late final TextEditingController _key = TextEditingController(text: widget.settings.translationApiKey);
  late final TextEditingController _baseUrl = TextEditingController(text: widget.settings.translationBaseUrl);
  late final TextEditingController _model = TextEditingController(text: widget.settings.translationModel);
  late final TextEditingController _language = TextEditingController(text: widget.settings.translationLanguage);

  String _provider = 'OpenRouter';
  String _mode = 'Translate';
  bool _streaming = true;
  bool _busy = false;
  String? _error;
  List<String>? _result;

  @override
  void initState() {
    super.initState();
    _provider = translationProviders.contains(widget.settings.translationProvider)
        ? widget.settings.translationProvider
        : 'OpenRouter';
    _mode = translationModes.contains(widget.settings.translationMode)
        ? widget.settings.translationMode
        : 'Translate';
    _streaming = widget.settings.translationStreaming;
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final lines = await widget.service.translateLyrics(
        lines: widget.lines,
        targetLanguage: _language.text.trim(),
        mode: _mode,
        provider: _provider,
        apiKey: _key.text.trim(),
        baseUrl: _baseUrl.text.trim(),
        model: _model.text.trim(),
        useStreaming: _streaming,
        onPartial: (partial) {
          if (mounted) setState(() => _result = partial);
        },
      );
      if (!mounted) return;
      setState(() => _result = lines);
      widget.onResult?.call(lines);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saveSettings() {
    widget.settings
      ..translationProvider = _provider
      ..translationApiKey = _key.text.trim()
      ..translationBaseUrl = _baseUrl.text.trim()
      ..translationModel = _model.text.trim()
      ..translationLanguage = _language.text.trim()
      ..translationMode = _mode
      ..translationStreaming = _streaming;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.service.translationHelper.status;
    return AlertDialog(
      title: const Text('Translate lyrics'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                for (final p in translationProviders)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => _provider = v ?? 'OpenRouter'),
            ),
            TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'API key'),
              obscureText: true,
            ),
            TextField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL (blank = default)',
              ),
            ),
            TextField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model (optional)'),
            ),
            TextField(
              controller: _language,
              decoration: const InputDecoration(labelText: 'Target language code'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: [
                for (final m in translationModes)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _mode = v ?? 'Translate'),
            ),
            SwitchListTile(
              title: const Text('Stream results'),
              value: _streaming,
              onChanged: (v) => setState(() => _streaming = v),
            ),
            if (status is translation.TranslationStatusTranslating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (status is translation.TranslationStatusError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(status.message,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (_result != null && _result!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _result!.take(3).join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy ? null : () async {
            _saveSettings();
            await _translate();
          },
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Translate'),
        ),
      ],
    );
  }
}
