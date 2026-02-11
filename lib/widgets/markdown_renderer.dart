import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:photo_view/photo_view.dart';
import '../l10n/app_localizations.dart';

/// Markdown Renderer
class MarkdownRenderer extends StatelessWidget {
  final String data;
  final bool selectable;
  final bool fitContent;

  const MarkdownRenderer({
    super.key,
    required this.data,
    this.selectable = false,
    this.fitContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MarkdownBody(
      data: data,
      selectable: selectable,
      fitContent: fitContent,
      styleSheet: MarkdownStyleSheet(
        blockSpacing: 12.0,
        // 段落样式
        p: Theme.of(context).textTheme.bodyMedium,
        // 标题样式
        h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h3: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h4: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        h5: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        h6: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        // 表格样式
        tableBorder: TableBorder.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        tableBody: TextStyle(
          color: colorScheme.onSurface,
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        // 水平线样式
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        // 行内代码样式
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          backgroundColor: isDark 
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHighest.withOpacity(0.8),
          color: colorScheme.onSurface,
        ),
        // 代码块样式
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        codeblockPadding: EdgeInsets.zero,
        // 引用样式
        blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.primary,
              width: 4,
            ),
          ),
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        // 列表样式
        listBullet: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        // 链接样式
        a: TextStyle(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      builders: {
        // 自定义代码块
        'code': CustomCodeBuilder(),
        // LaTeX 支持
        'latex': LatexBuilder(),
      },
      // 自定义图片
      imageBuilder: (uri, title, alt) {
        return _ImageWidget(
          uri: uri,
          title: title,
          alt: alt,
        );
      },
      // 点击链接回调
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      // 支持 LaTeX 语法扩展
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          LatexSyntax(),
        ],
      ),
    );
  }
}

/// 自定义代码块
class CustomCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code') {
      return null;
    }
    
    final String code = element.textContent;
    final bool hasLanguageClass = element.attributes['class']?.startsWith('language-') ?? false;
    final bool isMultiLine = code.contains('\n');
    if (!hasLanguageClass && !isMultiLine) {
      return null;
    }
    final String language = element.attributes['class']?.replaceFirst('language-', '') ?? '';

    return _CodeBlockWidget(
      code: code,
      language: language,
    );
  }
}

/// 代码块组件
class _CodeBlockWidget extends StatelessWidget {
  final String code;
  final String language;

  const _CodeBlockWidget({
    required this.code,
    required this.language,
  });

  static Map<String, TextStyle> _buildCodeTheme(bool isDark) {
    final backgroundColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final baseTheme = isDark ? monokaiSublimeTheme : githubTheme;
    return Map.from(baseTheme).map((key, value) {
      return MapEntry(
        key,
        value.copyWith(backgroundColor: backgroundColor),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 代码块头部
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                if (language.isNotEmpty)
                  Text(
                    language,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: l10n.markdownCopyCode,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.markdownCodeCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          // 代码内容
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code,
              language: language.isEmpty ? 'plaintext' : language,
              theme: _buildCodeTheme(isDark),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// LaTeX 语法解析器
class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'\$\$(.+?)\$\$|\$(.+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final latex = match[1] ?? match[2];
    if (latex == null) return false;

    final element = md.Element.text('latex', latex);
    element.attributes['display'] = match[1] != null ? 'block' : 'inline';
    parser.addNode(element);

    return true;
  }
}

/// LaTeX
class LatexBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final latex = element.textContent;
    final isBlock = element.attributes['display'] == 'block';

    try {
      final widget = Math.tex(
        latex,
        textStyle: preferredStyle,
        mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      );

      if (isBlock) {
        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: widget,
            ),
          ),
        );
      }

      return widget;
    } catch (e) {
      // LaTeX 解析失败就显示原始文本
      return Text(
        isBlock ? '\$\$$latex\$\$' : '\$$latex\$',
        style: TextStyle(
          fontFamily: 'monospace',
          color: Colors.red,
        ),
      );
    }
  }
}

/// 图片
class _ImageWidget extends StatelessWidget {
  final Uri uri;
  final String? title;
  final String? alt;

  const _ImageWidget({
    required this.uri,
    this.title,
    this.alt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击图片预览
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ImagePreviewScreen(
              uri: uri,
              title: title ?? alt,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(
          maxWidth: double.infinity,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            uri.toString(),
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;

              return Container(
                height: 200,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alt ?? 'Failed to load image',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 图片预览界面
class _ImagePreviewScreen extends StatelessWidget {
  final Uri uri;
  final String? title;

  const _ImagePreviewScreen({
    required this.uri,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title != null ? Text(title!) : null,
      ),
      body: PhotoView(
        imageProvider: NetworkImage(uri.toString()),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        loadingBuilder: (context, event) {
          return Center(
            child: CircularProgressIndicator(
              value: event == null
                  ? null
                  : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
