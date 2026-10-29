import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_theme.dart';

/// Shared, store-themed building blocks for the "add product" and "add
/// service" publish flows.
///
/// These widgets are deliberately presentation-only: the flows keep their own
/// controllers, validation and API payloads untouched.
class PublishStyle {
  PublishStyle._();

  static const ink = BStoreColors.textPrimary;
  static const muted = Color(0xFF6B7385);
  static const soft = Color(0xFF98A0B3);
  static const fieldFill = Color(0xFFF7F8FA);
  static const fieldBorder = Color(0xFFE9EDF2);
  static const cardBorder = Color(0xFFEDF0F4);
  static const teal = BStoreColors.primary;
  static const tealSoft = BStoreColors.primarySoft;
  static const purple = BStoreColors.accentPurple;
  static const purpleSoft = BStoreColors.accentPurpleSoft;
  static const neon = Color(0xFF5EEAD4);
  static const danger = Color(0xFFE4544F);
  static const success = Color(0xFF17A673);
  static const canvas = Color(0xFFFFFBF6);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1030), Color(0xFF16215C), Color(0xFF2A1B5E)],
    stops: [0.0, 0.55, 1.0],
  );
}

InputDecoration publishInputDecoration({
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
  Widget? prefixIcon,
  double radius = 14,
  EdgeInsetsGeometry? contentPadding,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: const BorderSide(color: PublishStyle.fieldBorder),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: PublishStyle.soft,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      color: PublishStyle.ink,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: PublishStyle.fieldFill,
    counterText: '',
    isDense: true,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: PublishStyle.teal, width: 1.4),
    ),
  );
}

/// One step in the flow header.
class PublishStep {
  final String label;
  final String subtitle;
  final IconData icon;

  const PublishStep({
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

/// Dark "seller studio" hero used at the top of both publish flows.
class PublishFlowHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final int step;
  final List<PublishStep> steps;
  final double completion;
  final VoidCallback onBack;
  final String? draftLabel;
  final VoidCallback? onSaveDraft;
  final bool saving;
  final ValueChanged<int> onStepTap;

  const PublishFlowHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.step,
    required this.steps,
    required this.completion,
    required this.onBack,
    required this.onStepTap,
    this.draftLabel,
    this.onSaveDraft,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final current = steps[(step - 1).clamp(0, steps.length - 1)];
    final pct = (completion.clamp(0.0, 1.0) * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      decoration: BoxDecoration(
        gradient: PublishStyle.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: PublishStyle.teal.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -66,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PublishStyle.teal.withValues(alpha: 0.48),
                    PublishStyle.teal.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -46,
            bottom: -76,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PublishStyle.purple.withValues(alpha: 0.42),
                    PublishStyle.purple.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 14,
              16,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _GlassIconButton(
                      icon: LucideIcons.chevronLeft,
                      label: 'Back',
                      onTap: onBack,
                    ),
                    const Spacer(),
                    if (onSaveDraft != null)
                      _GlassTextButton(
                        label:
                            saving ? 'Saving…' : (draftLabel ?? 'Save draft'),
                        icon: saving ? null : LucideIcons.fileText,
                        onTap: saving ? null : onSaveDraft,
                        busy: saving,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFC7D0EE),
                          fontSize: 9.5,
                          letterSpacing: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: PublishStyle.neon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PublishStyle.neon.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '$pct% ready',
                        style: const TextStyle(
                          color: PublishStyle.neon,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Step $step of ${steps.length} · ${current.label}',
                  style: const TextStyle(
                    color: Color(0xFF9AA3C7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onStepTap(i + 1),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: i + 1 < step
                                      ? PublishStyle.neon
                                      : i + 1 == step
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (i + 1 < step) ...[
                                    const Icon(
                                      LucideIcons.check,
                                      size: 11,
                                      color: PublishStyle.neon,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      steps[i].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: i + 1 <= step
                                            ? Colors.white
                                            : const Color(0xFF8B95BB),
                                        fontSize: 10.5,
                                        fontWeight: i + 1 == step
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i != steps.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;

  const _GlassTextButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 13, color: Colors.white),
            if (busy || icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White card with a tone badge, title and subtitle — mirrors the numbered
/// section cards in the web app.
class PublishSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final List<Widget> children;

  const PublishSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.accent = PublishStyle.teal,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PublishStyle.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: PublishStyle.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: PublishStyle.soft,
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
          Container(height: 1, color: PublishStyle.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _spaced(children, 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status pill used in card headers.
class PublishPill extends StatelessWidget {
  final String label;
  final Color color;

  const PublishPill({
    super.key,
    required this.label,
    this.color = PublishStyle.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Label + filled text field used across both flows.
class PublishField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool required;
  final int? maxLength;
  final int maxLines;
  final int minLines;
  final TextInputType? keyboardType;
  final String? prefixText;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  const PublishField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.required = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType,
    this.prefixText,
    this.helper,
    this.onChanged,
    this.enabled = true,
    this.textInputAction,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: PublishFieldLabel(label, required: required)),
            if (maxLength != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => Text(
                  '${value.text.length}/$maxLength',
                  style: const TextStyle(
                    color: PublishStyle.soft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
          cursorColor: PublishStyle.teal,
          style: TextStyle(
            color: enabled ? PublishStyle.ink : PublishStyle.soft,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          decoration: publishInputDecoration(
            hint: hint,
            prefixText: prefixText,
            suffixIcon: suffixIcon,
            contentPadding: maxLines > 1
                ? const EdgeInsets.fromLTRB(14, 13, 14, 13)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(
              color: PublishStyle.soft,
              fontSize: 10.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class PublishFieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const PublishFieldLabel(this.label, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: PublishStyle.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: PublishStyle.danger),
            ),
        ],
      ),
    );
  }
}

/// Filled dropdown matching [PublishField].
class PublishSelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String? hint;
  final bool required;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;
  final IconData? icon;

  const PublishSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.required = false,
    this.labelBuilder,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PublishFieldLabel(label, required: required),
        const SizedBox(height: 7),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 340,
          dropdownColor: Colors.white,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 18,
            color: PublishStyle.muted,
          ),
          style: const TextStyle(
            color: PublishStyle.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  style: const TextStyle(
                    color: PublishStyle.soft,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder?.call(item) ?? item.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
          decoration: publishInputDecoration(
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 17, color: PublishStyle.muted),
          ),
        ),
      ],
    );
  }
}

/// Tinted switch row used inside section cards.
class PublishSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  const PublishSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: PublishStyle.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublishStyle.fieldBorder),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: PublishStyle.teal),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: PublishStyle.soft,
                      fontSize: 10.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Selectable option card (delivery method, pricing mode…).
class PublishChoiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const PublishChoiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected ? PublishStyle.tealSoft : PublishStyle.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? PublishStyle.teal : PublishStyle.fieldBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: selected ? PublishStyle.teal : PublishStyle.muted,
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? PublishStyle.teal : Colors.transparent,
                    border: Border.all(
                      color: selected ? PublishStyle.teal : PublishStyle.soft,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? const Icon(LucideIcons.check,
                          size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: PublishStyle.ink,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PublishStyle.soft,
                  fontSize: 9.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom action bar shared by both flows.
class PublishFooter extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback? onBack;
  final bool busy;

  const PublishFooter({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onPrimary,
    required this.primaryLabel,
    this.onBack,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: PublishStyle.cardBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: busy ? null : onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PublishStyle.ink,
                  side: const BorderSide(color: PublishStyle.fieldBorder),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _GradientButton(
              label: primaryLabel,
              busy: busy,
              onTap: busy ? null : onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const _GradientButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !busy ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 52,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF09A0A0), Color(0xFF066B70)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x33078D92),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight,
                            size: 16, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class PublishChecklistItem {
  final String label;
  final bool done;

  const PublishChecklistItem(this.label, this.done);
}

/// "Ready to publish" checklist, mirroring the web completeness card.
class PublishChecklistCard extends StatelessWidget {
  final List<PublishChecklistItem> items;

  const PublishChecklistCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.done).length;
    final pct = items.isEmpty ? 0 : (done / items.length * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PublishStyle.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: PublishStyle.purpleSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 17,
                  color: PublishStyle.purple,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Listing readiness',
                  style: TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: PublishStyle.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: items.isEmpty ? 0 : done / items.length,
              minHeight: 6,
              backgroundColor: PublishStyle.fieldFill,
              valueColor: const AlwaysStoppedAnimation(PublishStyle.teal),
            ),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < items.length; i++) ...[
            _ChecklistRow(label: items[i].label, done: items[i].done),
            if (i != items.length - 1) const SizedBox(height: 9),
          ],
          if (done == items.length && items.isNotEmpty) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: PublishStyle.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.badgeCheck,
                      size: 15, color: PublishStyle.teal),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Everything looks good — ready to publish.',
                      style: TextStyle(
                        color: PublishStyle.teal,
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;

  const _ChecklistRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? PublishStyle.success : PublishStyle.fieldFill,
            border: Border.all(
              color: done ? PublishStyle.success : PublishStyle.fieldBorder,
            ),
          ),
          child: done
              ? const Icon(LucideIcons.check, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done ? PublishStyle.ink : PublishStyle.soft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "what customers will see" card.
class PublishPreviewCard extends StatelessWidget {
  final Widget image;
  final List<Widget> children;
  final String label;

  const PublishPreviewCard({
    super.key,
    required this.image,
    required this.children,
    this.label = 'Listing preview',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PublishStyle.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: PublishStyle.tealSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.eye,
                    size: 15, color: PublishStyle.teal),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const PublishPill(label: 'LIVE'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 96, height: 96, child: image),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _spaced(children, 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashed rounded container used for photo drop zones.
class PublishDashedBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final Color borderColor;

  const PublishDashedBox({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 18,
    this.color = const Color(0xFFF4FBF9),
    this.borderColor = const Color(0xFFB9E3DD),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          radius: radius,
          color: borderColor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final double radius;
  final Color color;

  _DashedRRectPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          Radius.circular(radius),
        ),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// Soft inline hint (tips, requirement notes).
class PublishHint extends StatelessWidget {
  final String text;
  final IconData icon;

  const PublishHint({
    super.key,
    required this.text,
    this.icon = LucideIcons.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PublishStyle.tealSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: PublishStyle.teal),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PublishStyle.teal,
                fontSize: 10.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add another" text button with a soft pill background.
class PublishAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const PublishAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = LucideIcons.plus,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: PublishStyle.tealSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: PublishStyle.teal),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: PublishStyle.teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Removable small value chip.
class PublishValueChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const PublishValueChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
      decoration: BoxDecoration(
        color: PublishStyle.fieldFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PublishStyle.fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PublishStyle.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              LucideIcons.x,
              size: 13,
              color: PublishStyle.soft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used inside step content (outside a card).
class PublishStepIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const PublishStepIntro({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PublishStyle.ink,
            fontSize: 19,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: PublishStyle.soft,
            fontSize: 11.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

List<Widget> _spaced(List<Widget> children, double gap) {
  if (children.isEmpty) return children;
  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    spaced.add(children[i]);
    if (i != children.length - 1) spaced.add(SizedBox(height: gap));
  }
  return spaced;
}
