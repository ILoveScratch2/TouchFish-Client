import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';

class MarkdownRenderer extends HookWidget {
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    final spoilerRevealed = useState(false);
    final codeBlockDecoration = BoxDecoration(
      color: isDark
          ? theme.colorScheme.surfaceBright
          : theme.colorScheme.surfaceDim,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    );

    final mentionGenerator = MentionChipGenerator(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      onTap: (username) async {
        final profile = await TfApiClient.instance.getUserByUsername(username);
        if (profile != null && context.mounted) {
          context.push('/user/${profile.uid}');
        }
      },
    );

    final highlightGenerator = HighlightGenerator(
      highlightColor: theme.colorScheme.primaryContainer,
    );

    final spoilerGenerator = SpoilerGenerator(
      backgroundColor: theme.colorScheme.tertiary,
      foregroundColor: theme.colorScheme.onTertiary,
      outlineColor: theme.colorScheme.outline,
      revealed: spoilerRevealed.value,
      hiddenLabel: l10n.markdownSpoilerHidden,
      onToggle: () => spoilerRevealed.value = !spoilerRevealed.value,
    );

    final markdown = MarkdownBlock(
      data: data,
      selectable: selectable,
      config: config.copy(
        configs: [
          isDark
              ? PreConfig.darkConfig.copy(
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  styleNotMatched: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: codeBlockDecoration,
                )
              : PreConfig(
                  theme: a11yLightTheme,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  styleNotMatched: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: codeBlockDecoration,
                ),
          PConfig(
            textStyle:
                theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
          ),
          Heading1Config(
            style:
                theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(
                  fontSize: 32,
                  height: 40 / 32,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Heading2Config(
            style:
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(
                  fontSize: 24,
                  height: 30 / 24,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Heading3Config(
            style:
                theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(
                  fontSize: 20,
                  height: 25 / 20,
                  fontWeight: FontWeight.bold,
                ),
          ),
          PreConfig(
            theme: isDark ? a11yDarkTheme : a11yLightTheme,
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            styleNotMatched: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: codeBlockDecoration,
          ),
          TableConfig(
            wrapper: (child) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
          LinkConfig(
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            onTap: (href) => _openLink(context, href),
          ),
          ImgConfig(
            builder: (url, attributes) {
              final uri = Uri.tryParse(url);
              if (uri == null) {
                return const SizedBox.shrink();
              }
              return _MarkdownRemoteImage(uri: uri);
            },
          ),
        ],
      ),
      generator: MarkdownRenderer.buildGenerator(
        isDark: isDark,
        generators: [mentionGenerator, highlightGenerator, spoilerGenerator],
      ),
    );

    if (fitContent) {
      return markdown;
    }

    return SizedBox(width: double.infinity, child: markdown);
  }

  static MarkdownGenerator buildGenerator({
    required bool isDark,
    List<dynamic> generators = const [],
  }) {
    return MarkdownGenerator(
      generators: [
        latexGenerator,
        ...generators,
        SpanNodeGeneratorWithTag(
          tag: MarkdownTag.hr.name,
          generator: (element, config, visitor) => DividerNode(),
        ),
      ],
      inlineSyntaxList: [
        _MentionInlineSyntax(),
        _HighlightInlineSyntax(),
        _SpoilerInlineSyntax(),
        LatexSyntax(isDark),
      ],
      linesMargin: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  static Future<void> _openLink(BuildContext context, String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MentionInlineSyntax extends markdown.InlineSyntax {
  _MentionInlineSyntax()
    : super(r'(^|\s)(@[^\s@,.!?;:，。！？；：]+)(?=\s|$|[,.!?;:，。！？；：])');

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    final prefix = match[1] ?? '';
    final alias = match[2]!;
    final username = alias.substring(1);
    if (prefix.isNotEmpty) {
      parser.addNode(markdown.Text(prefix));
    }

    final element = markdown.Element('mention-chip', [markdown.Text(alias)])
      ..attributes['alias'] = alias
      ..attributes['username'] = username;
    parser.addNode(element);

    return true;
  }
}

class _HighlightInlineSyntax extends markdown.InlineSyntax {
  _HighlightInlineSyntax() : super(r'==([^=]+)==');

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    final text = match[1]!;
    final element = markdown.Element('highlight', [markdown.Text(text)]);
    parser.addNode(element);
    return true;
  }
}

class _SpoilerInlineSyntax extends markdown.InlineSyntax {
  _SpoilerInlineSyntax() : super(r'=!([^!]+)!=');

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    final text = match[1]!;
    final element = markdown.Element('spoiler', [markdown.Text(text)]);
    parser.addNode(element);
    return true;
  }
}

class MentionChipGenerator extends SpanNodeGeneratorWithTag {
  MentionChipGenerator({
    required Color backgroundColor,
    required Color foregroundColor,
    required void Function(String username) onTap,
  }) : super(
         tag: 'mention-chip',
         generator: (element, config, visitor) {
           return MentionChipSpanNode(
             attributes: element.attributes,
             backgroundColor: backgroundColor,
             foregroundColor: foregroundColor,
             onTap: onTap,
           );
         },
       );
}

class MentionChipSpanNode extends SpanNode {
  final Map<String, String> attributes;
  final Color backgroundColor;
  final Color foregroundColor;
  final void Function(String username) onTap;

  MentionChipSpanNode({
    required this.attributes,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  InlineSpan build() {
    final username = attributes['username'] ?? '';
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _MentionChipContent(
        username: username,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        onTap: () => onTap(username),
      ),
    );
  }
}

class _MentionChipContent extends StatelessWidget {
  final String username;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _MentionChipContent({
    required this.username,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentUser =
        AuthState.instance.currentUser?.username.toLowerCase() ==
        username.toLowerCase();
    final chipColor = isCurrentUser
        ? Theme.of(context).colorScheme.tertiary
        : backgroundColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.only(
          left: 5,
          right: 7,
          top: 2.5,
          bottom: 2.5,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: isCurrentUser ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 9,
              backgroundColor: chipColor.withValues(alpha: 0.35),
              child: Text(
                '@',
                style: TextStyle(color: chipColor, fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '@$username',
              style: TextStyle(
                color: chipColor,
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HighlightGenerator extends SpanNodeGeneratorWithTag {
  HighlightGenerator({required Color highlightColor})
    : super(
        tag: 'highlight',
        generator: (element, config, visitor) {
          return HighlightSpanNode(
            text: element.textContent,
            highlightColor: highlightColor,
          );
        },
      );
}

class HighlightSpanNode extends SpanNode {
  final String text;
  final Color highlightColor;

  HighlightSpanNode({required this.text, required this.highlightColor});

  @override
  InlineSpan build() {
    return TextSpan(
      text: text,
      style: TextStyle(backgroundColor: highlightColor),
    );
  }
}

class SpoilerGenerator extends SpanNodeGeneratorWithTag {
  SpoilerGenerator({
    required Color backgroundColor,
    required Color foregroundColor,
    required Color outlineColor,
    required bool revealed,
    required String hiddenLabel,
    required VoidCallback onToggle,
  }) : super(
         tag: 'spoiler',
         generator: (element, config, visitor) {
           return SpoilerSpanNode(
             text: element.textContent,
             backgroundColor: backgroundColor,
             foregroundColor: foregroundColor,
             outlineColor: outlineColor,
             revealed: revealed,
             hiddenLabel: hiddenLabel,
             onToggle: onToggle,
           );
         },
       );
}

class SpoilerSpanNode extends SpanNode {
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color outlineColor;
  final bool revealed;
  final String hiddenLabel;
  final VoidCallback onToggle;

  SpoilerSpanNode({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.outlineColor,
    required this.revealed,
    required this.hiddenLabel,
    required this.onToggle,
  });

  @override
  InlineSpan build() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: revealed ? Colors.transparent : backgroundColor,
            border: revealed ? Border.all(color: outlineColor, width: 1) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: revealed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: Text(text)),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: foregroundColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(hiddenLabel, style: TextStyle(color: foregroundColor)),
                  ],
                ),
        ),
      ),
    );
  }
}

final SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (element, config, visitor) {
    return LatexNode(element.attributes, element.textContent, config);
  },
);

const String _latexTag = 'latex';

class LatexSyntax extends markdown.InlineSyntax {
  final bool isDark;

  LatexSyntax(this.isDark) : super(r'(\$\$[\s\S]+\$\$)|(\$.+?\$)');

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    final matchValue = match.input.substring(match.start, match.end);
    String content = '';
    var isInline = true;
    const blockSyntax = r'$$';
    const inlineSyntax = r'$';

    if (matchValue.startsWith(blockSyntax) &&
        matchValue.endsWith(blockSyntax) &&
        matchValue != blockSyntax) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(inlineSyntax) &&
        matchValue.endsWith(inlineSyntax) &&
        matchValue != inlineSyntax) {
      content = matchValue.substring(1, matchValue.length - 1);
    }

    final element = markdown.Element.text(_latexTag, matchValue)
      ..attributes['content'] = content
      ..attributes['isInline'] = '$isInline'
      ..attributes['isDark'] = isDark.toString();
    parser.addNode(element);
    return true;
  }
}

class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final isInline = attributes['isInline'] == 'true';
    final isDark = attributes['isDark'] == 'true';
    final style = parentStyle ?? config.p.textStyle;

    if (content.isEmpty) {
      return TextSpan(style: style, text: textContent);
    }

    final latex = Math.tex(
      content,
      mathStyle: MathStyle.text,
      textStyle: style.copyWith(color: isDark ? Colors.white : Colors.black),
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(textContent, style: style.copyWith(color: Colors.red));
      },
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: isInline
          ? latex
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: latex),
            ),
    );
  }
}

class DividerNode extends SpanNode {
  @override
  InlineSpan build() {
    return const WidgetSpan(child: Divider());
  }
}

class Heading1Config extends HeadingConfig {
  @override
  final TextStyle style;

  const Heading1Config({
    this.style = const TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.bold,
    ),
  });

  @override
  String get tag => MarkdownTag.h1.name;
}

class Heading2Config extends HeadingConfig {
  @override
  final TextStyle style;

  const Heading2Config({
    this.style = const TextStyle(
      fontSize: 24,
      height: 30 / 24,
      fontWeight: FontWeight.bold,
    ),
  });

  @override
  String get tag => MarkdownTag.h2.name;
}

class Heading3Config extends HeadingConfig {
  @override
  final TextStyle style;

  const Heading3Config({
    this.style = const TextStyle(
      fontSize: 20,
      height: 25 / 20,
      fontWeight: FontWeight.bold,
    ),
  });

  @override
  String get tag => MarkdownTag.h3.name;
}

class _MarkdownRemoteImage extends StatelessWidget {
  final Uri uri;

  const _MarkdownRemoteImage({required this.uri});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ImagePreviewScreen(uri: uri),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Image.network(
            uri.toString(),
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return Container(
                constraints: const BoxConstraints(minHeight: 120),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes == null
                      ? null
                      : loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                constraints: const BoxConstraints(minHeight: 120),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final Uri uri;

  const _ImagePreviewScreen({required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PhotoView(
        imageProvider: NetworkImage(uri.toString()),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
