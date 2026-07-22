import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/markdown_renderer.dart';

class MarkdownTestScreen extends StatefulWidget {
  const MarkdownTestScreen({super.key});

  @override
  State<MarkdownTestScreen> createState() => _MarkdownTestScreenState();
}

class _MarkdownTestScreenState extends State<MarkdownTestScreen> {
  static const double _contentMaxWidth = 1200;
  static const String _defaultMarkdown = '''# Markdown Test

Type **Markdown** here and preview the rendered result.

- Lists
- `inline code`
- [Links](https://example.com)

> Quote

```json
{
  "hello": "TouchFish"
}
```
''';

  final _markdownController = TextEditingController(text: _defaultMarkdown);
  String _markdown = _defaultMarkdown;

  @override
  void dispose() {
    _markdownController.dispose();
    super.dispose();
  }

  Widget _buildEditorCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.debugMarkdownTesterEditorTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.debugMarkdownTesterDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _markdownController,
              minLines: 14,
              maxLines: 20,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (value) {
                setState(() => _markdown = value);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: l10n.debugMarkdownTesterHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.debugMarkdownTesterPreviewTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.debugMarkdownTesterPreviewDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(16),
              child: _markdown.trim().isEmpty
                  ? Text(
                      l10n.debugMarkdownTesterEmptyPreview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : MarkdownRenderer(
                      data: _markdown,
                      selectable: true,
                      fitContent: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugMarkdownTester)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useWideLayout = constraints.maxWidth >= 960;
              final children = [
                useWideLayout
                    ? Expanded(child: _buildEditorCard(context, l10n))
                    : _buildEditorCard(context, l10n),
                useWideLayout
                    ? const SizedBox(width: 16)
                    : const SizedBox(height: 16),
                useWideLayout
                    ? Expanded(child: _buildPreviewCard(context, l10n))
                    : _buildPreviewCard(context, l10n),
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