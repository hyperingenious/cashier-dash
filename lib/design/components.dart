import 'package:flutter/material.dart';

import 'tokens.dart';

/// Flat surface with a 1px border and no shadow. The default container in
/// this app — replaces the old `GlassContainer` for new code. Keep nesting
/// shallow; do not stack surfaces.
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.color = DS.surface,
    this.border = true,
    this.radius = DS.r8,
    this.borderColor,
    this.onTap,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final bool border;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border:
            border ? Border.all(color: borderColor ?? DS.border) : null,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

/// 8px circle for state. Pair with caption text in a row.
class StatusDot extends StatelessWidget {
  const StatusDot(this.color, {super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Compact pill chip, used for state on rows / tiles. Background is a tinted
/// surface, foreground is the same hue at full strength.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  Color _bg() {
    if (tone == DS.green) return DS.greenSurface;
    if (tone == DS.amber) return DS.amberSurface;
    if (tone == DS.red) return DS.redSurface;
    if (tone == DS.violet) return DS.violetSurface;
    if (tone == DS.blue) return DS.blueSurface;
    return DS.greySurface;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(DS.r4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(tone, size: 6),
          const SizedBox(width: 6),
          Text(label, style: DS.caption(color: tone)),
        ],
      ),
    );
  }
}

/// Right-aligned tabular money number. Use everywhere prices are shown so
/// columns of digits line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.size = 13,
    this.weight = FontWeight.w500,
    this.color,
    this.symbol = '₹',
  });

  final double amount;
  final double size;
  final FontWeight weight;
  final Color? color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$symbol${amount.toStringAsFixed(2)}',
      textAlign: TextAlign.right,
      style: DS.number(size: size, color: color, weight: weight),
    );
  }
}

/// Small icon button for inline row actions (28×28). Quieter than the default
/// Material IconButton.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? DS.red : (color ?? DS.textMuted);
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DS.r6),
        child: SizedBox(
          width: DS.iconBtn,
          height: DS.iconBtn,
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

/// "EYEBROW" + optional trailing action. Use on top of grouped lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.trailing,
  });

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, DS.s8, 0, DS.s6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: DS.eyebrow()),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 1px row separator. Use inside data lists.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: const Divider(height: 1, thickness: 1, color: DS.divider),
    );
  }
}

/// Horizontal label/value row, common in summaries.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final Widget value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasis ? DS.bodyStrong() : DS.body(color: DS.textMuted),
          ),
        ),
        DefaultTextStyle.merge(
          style: emphasis
              ? DS.number(size: 14, weight: FontWeight.w600)
              : DS.number(),
          child: value,
        ),
      ],
    );
  }
}
