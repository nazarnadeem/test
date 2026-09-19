import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Reusable high-performance text field with glassmorphic styling,
/// animated focus border, floating label, and password visibility toggle.
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;
  final String? helperText;
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.helperText,
    this.initialValue,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  late FocusNode _focusNode;
  late TextEditingController _effectiveController;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _effectiveController = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _effectiveController.dispose();
      }
      _effectiveController = widget.controller ??
          TextEditingController(text: widget.initialValue ?? '');
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayHint = widget.hintText ?? widget.hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Field Label
        if (widget.label.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isFocused
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ),
              if (widget.helperText != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.helperText!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMutedDark,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
        ],

        // Input Container with subtle glow on focus
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: _effectiveController,
            focusNode: _focusNode,
            obscureText: widget.isPassword && _obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: displayHint,
              filled: true,
              fillColor: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: _isFocused
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textMutedDark
                              : AppColors.textSecondaryLight),
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: _obscureText
                            ? (isDark
                                ? AppColors.textMutedDark
                                : AppColors.textSecondaryLight)
                            : AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : widget.suffix,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
