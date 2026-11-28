import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Form field (602): letter-spaced caps label (+ red asterisk when required),
/// borderless input, dashed 1 dp underline that turns into a solid indigo
/// line on focus, and the error below in red.
class UnderlineField extends StatefulWidget {
  const UnderlineField({
    required this.label,
    this.controller,
    this.hint,
    this.required = false,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.focusNode,
    this.autofocus = false,
    this.maxLines = 1,
    this.textCapitalization,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool required;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Trailing widget (dropdown chevron, currency).
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Lines before the field scrolls; null grows with the text (notes).
  final int? maxLines;

  /// Defaults to sentences, but none for e-mail, URL, number, phone and code fields (S-253: the keyboard
  /// must not turn "you@bank" into "You@bank").
  final TextCapitalization? textCapitalization;

  bool get _literal => switch (keyboardType?.index) {
    final i? =>
      i == TextInputType.emailAddress.index ||
          i == TextInputType.url.index ||
          i == TextInputType.visiblePassword.index ||
          i == TextInputType.number.index ||
          i == TextInputType.phone.index,
    null => false,
  };

  @override
  State<UnderlineField> createState() => _UnderlineFieldState();
}

class _UnderlineFieldState extends State<UnderlineField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final lineColor = hasError ? c.oweText : (focused ? c.primary : c.divider);
    final l = AppLocalizations.of(context);
    final inputStyle = context.text.input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: widget.label.toUpperCase(),
                  children: [
                    if (widget.required)
                      TextSpan(
                        text: '*',
                        style: context.text.labelCaps.copyWith(color: c.oweText),
                      ),
                  ],
                ),
                semanticsLabel: widget.required ? '${widget.label}, ${l.required}' : widget.label,
                style: context.text.labelCaps.copyWith(color: c.textSecondary),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      inputFormatters: widget.inputFormatters,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: inputStyle,
                      maxLines: widget.maxLines,
                      minLines: 1,
                      textCapitalization:
                          widget.textCapitalization ??
                          (widget._literal
                              ? TextCapitalization.none
                              : TextCapitalization.sentences),
                      autocorrect: !widget._literal,
                      enableSuggestions: !widget._literal,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                        hintText: widget.hint,
                        hintStyle: inputStyle.copyWith(color: c.textSecondary),
                        // A long hint wraps instead of ending in "Type a name, t…" at large text (S-446).
                        hintMaxLines: 3,
                      ),
                    ),
                  ),
                  ?widget.suffix,
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: focused ? 1.5 : 1,
          width: double.infinity,
          child: focused || hasError
              ? ColoredBox(color: lineColor)
              : CustomPaint(painter: DashedLinePainter(color: lineColor, dash: 5, gap: 4)),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.s1),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.errorText!,
              style: context.text.bodySmall.w(500).copyWith(color: c.oweText),
            ),
          ),
        ],
      ],
    );
  }
}
