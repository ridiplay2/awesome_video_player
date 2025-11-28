import 'dart:async';
import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player/src/core/better_player_utils.dart';
import 'package:awesome_video_player/src/subtitles/better_player_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class BetterPlayerSubtitlesDrawer extends StatefulWidget {
  final List<BetterPlayerSubtitle> subtitles;
  final BetterPlayerController betterPlayerController;
  final BetterPlayerSubtitlesConfiguration? betterPlayerSubtitlesConfiguration;
  final Stream<bool> playerVisibilityStream;

  const BetterPlayerSubtitlesDrawer({
    Key? key,
    required this.subtitles,
    required this.betterPlayerController,
    this.betterPlayerSubtitlesConfiguration,
    required this.playerVisibilityStream,
  }) : super(key: key);

  @override
  _BetterPlayerSubtitlesDrawerState createState() =>
      _BetterPlayerSubtitlesDrawerState();
}

class _BetterPlayerSubtitlesDrawerState
    extends State<BetterPlayerSubtitlesDrawer> {
  final RegExp htmlRegExp =
  // ignore: unnecessary_raw_strings
  RegExp(r"<[^>]*>", multiLine: true);
  late TextStyle _innerTextStyle;
  late TextStyle _outerTextStyle;

  VideoPlayerValue? _latestValue;
  BetterPlayerSubtitlesConfiguration? _configuration;
  bool _playerVisible = false;
  String? _currentLanguage;

  ///Stream used to detect if play controls are visible or not
  late StreamSubscription _visibilityStreamSubscription;

  @override
  void initState() {
    _visibilityStreamSubscription = widget.playerVisibilityStream.listen((
      state,
    ) {
      setState(() {
        _playerVisible = state;
      });
    });

    if (widget.betterPlayerSubtitlesConfiguration != null) {
      _configuration = widget.betterPlayerSubtitlesConfiguration;
    } else {
      _configuration = setupDefaultConfiguration();
    }

    widget.betterPlayerController.videoPlayerController!.addListener(
      _updateState,
    );

    _updateTextStyles();

    super.initState();
  }

  /// Updates the text styles based on the current language
  void _updateTextStyles() {
    _currentLanguage =
        widget.betterPlayerController.betterPlayerSubtitlesSource?.language;
    final String fontFamily =
        _configuration!.languageFonts?[_currentLanguage] ??
        _configuration!.fontFamily;

    _outerTextStyle = TextStyle(
      fontSize: _configuration!.fontSize,
      fontFamily: fontFamily,
      fontVariations: _configuration!.fontVariations,
      foreground:
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _configuration!.outlineSize
            ..color = _configuration!.outlineColor,
    );

    _innerTextStyle = TextStyle(
      fontFamily: fontFamily,
      color: _configuration!.fontColor,
      fontSize: _configuration!.fontSize,
      fontVariations: _configuration!.fontVariations,
    );
  }

  @override
  void didUpdateWidget(BetterPlayerSubtitlesDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the language has changed, update the text styles
    if (_currentLanguage !=
        widget.betterPlayerController.betterPlayerSubtitlesSource?.language) {
      _updateTextStyles();
    }
  }

  @override
  void dispose() {
    widget.betterPlayerController.videoPlayerController!.removeListener(
      _updateState,
    );
    _visibilityStreamSubscription.cancel();
    super.dispose();
  }

  ///Called when player state has changed, i.e. new player position, etc.
  void _updateState() {
    if (mounted && !widget.betterPlayerController.isDetachingFromWidget) {
      setState(() {
        _latestValue =
            widget.betterPlayerController.videoPlayerController!.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BetterPlayerSubtitle? subtitle = _getSubtitleAtCurrentPosition();
    widget.betterPlayerController.renderedSubtitle = subtitle;
    final List<String> subtitles = subtitle?.texts ?? [];

    if (subtitles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Parse cue settings if available
    final cueSettings = subtitle?.cueSettings;
    final alignment = _getAlignmentFromCueSettings(cueSettings);
    final verticalPosition = _calculateVerticalPosition(cueSettings);

    final List<Widget> textWidgets =
        subtitles.map((text) => _buildSubtitleTextWidget(text)).toList();

    return Container(
      height: double.infinity,
      width: double.infinity,
      child: Align(
        alignment: Alignment(alignment.x, verticalPosition),
        child: Padding(
          padding: EdgeInsets.only(
            left: _configuration!.leftPadding,
            right: _configuration!.rightPadding,
            bottom: _playerVisible ? 30 : 0,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: textWidgets),
        ),
      ),
    );
  }

  BetterPlayerSubtitle? _getSubtitleAtCurrentPosition() {
    if (_latestValue == null) {
      return null;
    }

    final Duration position = _latestValue!.position;
    for (final BetterPlayerSubtitle subtitle
        in widget.betterPlayerController.subtitlesLines) {
      if (subtitle.start! <= position && subtitle.end! >= position) {
        return subtitle;
      }
    }
    return null;
  }

  Widget _buildSubtitleTextWidget(String subtitleText) {
    return _getTextWithStroke(subtitleText);
  }

  Widget _getTextWithStroke(String subtitleText) {
    return Container(
      color: _configuration!.backgroundColor,
      child: Stack(
        children: [
          if (_configuration!.outlineEnabled)
            _buildHtmlWidget(subtitleText, _outerTextStyle)
          else
            const SizedBox(),
          _buildHtmlWidget(subtitleText, _innerTextStyle),
        ],
      ),
    );
  }

  Widget _buildHtmlWidget(String text, TextStyle textStyle) {
    return HtmlWidget(text, textStyle: textStyle);
  }

  BetterPlayerSubtitlesConfiguration setupDefaultConfiguration() {
    return const BetterPlayerSubtitlesConfiguration();
  }

  /// Calculate vertical position based on VTT cue settings (line setting)
  /// Returns a value from -1.0 (top) to 1.0 (bottom) for Alignment
  /// VTT line can be a percentage (e.g., "85%") or a line number
  double _calculateVerticalPosition(Map<String, String>? cueSettings) {
    // Default position: keep original position (0.7) but allow bottomPadding adjustment
    // bottomPadding 기본값 20일 때 0.7 유지, 값에 따라 미세 조정
    final bottomPadding = _configuration!.bottomPadding;
    final defaultAlignment =
        0.7 + ((20.0 - bottomPadding) / 100.0).clamp(-0.3, 0.3);

    if (cueSettings == null || !cueSettings.containsKey('line')) {
      return defaultAlignment;
    }

    final lineValue = cueSettings['line']!;

    // If line is a percentage (e.g., "10%" or "85%")
    if (lineValue.endsWith('%')) {
      try {
        final percentage = double.parse(lineValue.replaceAll('%', ''));

        // VTT line percentage: 0% = top, 100% = bottom
        // Flutter Alignment: -1.0 = top, 1.0 = bottom
        // Convert: alignment = (percentage / 50) - 1
        // 0% -> -1.0 (top), 50% -> 0.0 (center), 100% -> 1.0 (bottom)
        final alignmentY = (percentage / 50.0) - 1.0;

        // Clamp to reasonable bounds
        final clampedAlignment = alignmentY.clamp(-0.9, 0.9);

        BetterPlayerUtils.log(
          "VTT line:$lineValue -> alignmentY:$clampedAlignment",
        );
        return clampedAlignment;
      } catch (e) {
        BetterPlayerUtils.log(
          "Failed to parse line percentage: $lineValue, error: $e",
        );
        return defaultAlignment;
      }
    }

    // If line is a number (line count from top or bottom)
    // For simplicity, we'll use the default position for line numbers
    return defaultAlignment;
  }

  /// Get alignment from VTT cue settings (align setting)
  Alignment _getAlignmentFromCueSettings(Map<String, String>? cueSettings) {
    if (cueSettings == null || !cueSettings.containsKey('align')) {
      return _configuration!.alignment;
    }

    final alignValue = cueSettings['align']!;
    switch (alignValue.toLowerCase()) {
      case 'start':
      case 'left':
        return Alignment.centerLeft;
      case 'center':
      case 'middle':
        return Alignment.center;
      case 'end':
      case 'right':
        return Alignment.centerRight;
      default:
        return _configuration!.alignment;
    }
  }
}
