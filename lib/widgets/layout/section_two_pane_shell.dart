import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/tokens.dart';
import '../../utils/wide_screen_helper.dart';

class SectionTwoPaneShell extends StatefulWidget {
  /// 右侧内容（嵌套子路由）。
  final Widget child;

  /// 左侧常驻列表；[twoPane] 为假时独占整屏。
  final Widget list;

  /// 宽屏是否分栏。
  final bool twoPane;

  /// 持久化键前缀，不同 Section 需传入不同值避免互相覆盖。
  final String storageKeyPrefix;

  final double defaultWidth;
  final double minWidth;
  final double maxWidth;

  /// 拖动收窄到该值以下时折叠为图标栏。
  final double collapseThreshold;

  /// 折叠态宽度。
  final double collapsedWidth;

  /// 拖拽把手无障碍标签
  final String? resizeHandleLabel;

  const SectionTwoPaneShell({
    super.key,
    required this.child,
    required this.list,
    required this.storageKeyPrefix,
    this.twoPane = true,
    this.defaultWidth = TFPane.defaultWidth,
    this.minWidth = TFPane.minWidth,
    this.maxWidth = TFPane.maxWidth,
    this.collapseThreshold = TFPane.collapseThreshold,
    this.collapsedWidth = TFPane.collapsedWidth,
    this.resizeHandleLabel,
  });

  @override
  State<SectionTwoPaneShell> createState() => _SectionTwoPaneShellState();
}

class _SectionTwoPaneShellState extends State<SectionTwoPaneShell>
    with SingleTickerProviderStateMixin {
  static const Duration _layoutAnimation = Duration(milliseconds: 220);
  static const double _paneGap = TFPane.gap;
  static const double _paneTop = TFPane.topInset;
  static const double _paneRadius = TFPane.radius;

  bool _isCollapsed = false;
  bool _isHoveringHandle = false;
  bool _isDragging = false;
  late double _sidebarWidth = widget.defaultWidth;

  /// 拖拽期间用零时长
  Duration get _positionDuration =>
      _isDragging ? Duration.zero : _layoutAnimation;

  late final AnimationController _enterController;
  late final Animation<double> _enterAnimation;

  String get _widthKey => '${widget.storageKeyPrefix}_width';
  String get _collapsedKey => '${widget.storageKeyPrefix}_collapsed';

  @override
  void initState() {
    super.initState();
    _restore();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _enterAnimation = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _enterController.forward();
      }
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  Widget _enterWrapper(BuildContext context, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: _enterAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.06, 0),
          end: Offset.zero,
        ).animate(_enterAnimation),
        child: child,
      ),
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCollapsed = prefs.getBool(_collapsedKey) ?? false;
      _sidebarWidth = _clampWidth(
        prefs.getDouble(_widthKey) ?? widget.defaultWidth,
      );
    });
  }


  double _clampWidth(double width) =>
      width.clamp(widget.minWidth, widget.maxWidth);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collapsedKey, _isCollapsed);
    await prefs.setDouble(_widthKey, _sidebarWidth);
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (!_isCollapsed) _sidebarWidth = widget.defaultWidth;
    });
    _persist();
  }

  void _onDragUpdate(double dx) {
    setState(() {
      _isDragging = true;
      if (_isCollapsed) {
        _isCollapsed = false;
        _sidebarWidth = widget.minWidth;
        return;
      }
      // 下限刻意取 collapseThreshold（低于 minWidth）：拖到底就等于把左栏
      // 折成图标栏。收尾时由 [_onDragEnd] 抬回 [_clampWidth] 的合法范围。
      _sidebarWidth = (_sidebarWidth + dx).clamp(
        widget.collapseThreshold,
        widget.maxWidth,
      );
    });
  }

  void _onDragEnd() {
    if (_isDragging) {
      setState(() => _isDragging = false);
    }
    if (!_isCollapsed && _sidebarWidth <= widget.collapseThreshold) {
      setState(() {
        _isCollapsed = true;
        _sidebarWidth = widget.minWidth;
      });
    } else if (!_isCollapsed) {
      // 没折到阈值但压进了 [collapseThreshold, minWidth)：拖动结束先抬回
      // 合法范围再持久化，别把恢复时会变的值写进 prefs。
      final clamped = _clampWidth(_sidebarWidth);
      if (clamped != _sidebarWidth) {
        setState(() => _sidebarWidth = clamped);
      }
    }
    _persist();
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Semantics(
      button: true,
      label: widget.resizeHandleLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _isHoveringHandle = true),
        onExit: (_) => setState(() => _isHoveringHandle = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d.delta.dx),
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onTap: _isCollapsed ? _toggleCollapse : null,
          child: Center(
            child: AnimatedContainer(
              duration: TFMotion.fast,
              // 悬停时加粗提示可拖动
              width: _isHoveringHandle || _isCollapsed ? 3 : 1,
              height: _isCollapsed ? 32 : 44,
              decoration: BoxDecoration(
                color: _isHoveringHandle
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(
                        alpha: TFAlpha.divider,
                      ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paneCard(Widget child, {required bool rounded}) {
    return ClipRRect(
      borderRadius: rounded
          ? const BorderRadius.vertical(top: Radius.circular(_paneRadius))
          : BorderRadius.zero,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 只有 expanded 档才谈得上分栏；medium 及以下直接单栏透传。
    if (!WideScreenHelper.isExpanded(context)) {
      return _enterWrapper(context, widget.child);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final twoPane = widget.twoPane;

    return _enterWrapper(
      context,
      Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final leftWidth = twoPane
                  ? (_isCollapsed ? widget.collapsedWidth : _sidebarWidth)
                  : available;
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedPositioned(
                    duration: _positionDuration,
                    curve: Curves.easeOutCubic,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: twoPane ? available - leftWidth : 0,
                    child: AnimatedPadding(
                      duration: _positionDuration,
                      curve: Curves.easeOutCubic,
                      padding: twoPane
                          ? const EdgeInsets.fromLTRB(
                              0,
                              _paneTop,
                              _paneGap / 2,
                              0,
                            )
                          : EdgeInsets.zero,
                      child: _paneCard(widget.list, rounded: twoPane),
                    ),
                  ),
                  if (twoPane) ...[
                    AnimatedPositioned(
                      duration: _positionDuration,
                      curve: Curves.easeOutCubic,
                      left: leftWidth,
                      top: 0,
                      bottom: 0,
                      width: _paneGap,
                      child: _buildHandle(colorScheme),
                    ),
                    AnimatedPositioned(
                      duration: _positionDuration,
                      curve: Curves.easeOutCubic,
                      left: leftWidth + _paneGap,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          _paneTop,
                          _paneGap,
                          0,
                        ),
                        child: _paneCard(widget.child, rounded: true),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
