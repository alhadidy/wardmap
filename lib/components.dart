/// Small building blocks every screen shares, so the app looks the same
/// everywhere. Colors and sizes come from theme.dart.
/// See docs/design-system.md for when to use each.
library;

import 'package:flutter/material.dart';

import 'roles.dart';
import 'theme.dart';

/// The Wardmap logo: a white cross on a teal rounded square (the same
/// drawing as the app icon in web/icons).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final arm = size * 0.5;
    final bar = arm * 0.34;
    Widget piece(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(bar * 0.18),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Palette.teal,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [piece(bar, arm), piece(arm, bar)],
      ),
    );
  }
}

/// A short status label in a colored capsule, e.g. "Discharged" or
/// "No note in 24h". The [tone] says how much attention it needs.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = context.tones.foreground(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: context.tones.background(tone),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: Space.xs),
          ],
          Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// A full-width message box: why you were logged out, what went wrong.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.tone = Tone.info, this.icon});

  final String message;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = context.tones.foreground(tone);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: context.tones.background(tone),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ??
                (tone == Tone.danger
                    ? Icons.error_outline
                    : Icons.info_outline),
            size: 20,
            color: fg,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round badge with a person's role ("CON", "R3"), colored by seniority:
/// consultants and admins teal, residents blue, everyone else grey.
class RoleAvatar extends StatelessWidget {
  const RoleAvatar(this.role, {super.key, this.size = 40});

  final StaffRole role;
  final double size;

  static Tone toneOf(StaffRole role) => switch (role.rank) {
    >= 90 => Tone.brand,
    >= 10 => Tone.info,
    _ => Tone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final tone = toneOf(role);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tones.background(tone),
        shape: BoxShape.circle,
      ),
      child: Text(
        role.short,
        style: context.text.labelMedium?.copyWith(
          color: context.tones.foreground(tone),
          fontSize: size * (role.short.length > 2 ? 0.28 : 0.34),
        ),
      ),
    );
  }
}

/// A small heading above a group of content, with an optional action on the
/// right (e.g. "Care team" + Add).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Space.lg,
        bottom: Space.sm,
        left: Space.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One fact about something: a small grey label over its value.
class InfoItem extends StatelessWidget {
  const InfoItem(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodySmall),
        const SizedBox(height: 2),
        Text(
          value == null || value!.isEmpty ? '—' : value!,
          style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Facts laid out in two columns (one on very narrow screens).
class InfoGrid extends StatelessWidget {
  const InfoGrid(this.items, {super.key});

  final List<InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth < 280 ? 1 : 2;
        final width = (box.maxWidth - Space.lg * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.lg,
          runSpacing: Space.lg,
          children: [for (final i in items) SizedBox(width: width, child: i)],
        );
      },
    );
  }
}

/// What to show when a list has nothing in it. Scrollable, so it still
/// works inside a pull-to-refresh.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xxl * 2,
      ),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: context.colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A list's spinner while it loads.
class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Cards in a scrolling column with even gaps. [bottom] leaves room for a
/// floating button.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children, this.bottom = Space.xl});

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, bottom),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// A content column that stays readable on wide screens (tablets, desktop
/// browsers) by capping its width.
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A patient's bed number in a small tile at the start of a row. Without a
/// bed it shows a dash.
class BedBadge extends StatelessWidget {
  const BedBadge(this.label, {super.key});

  final Object? label;

  @override
  Widget build(BuildContext context) {
    final hasBed = label != null;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasBed
            ? context.colors.primaryContainer
            : context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'BED',
            style: context.text.labelSmall?.copyWith(
              fontSize: 9,
              color: hasBed
                  ? context.colors.onPrimaryContainer
                  : context.colors.onSurfaceVariant,
            ),
          ),
          Text(
            hasBed ? '$label' : '—',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: context.text.titleMedium?.copyWith(
              height: 1.1,
              color: hasBed
                  ? context.colors.onPrimaryContainer
                  : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A date or time that opens a picker when tapped, drawn like a text field
/// so forms look even.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  /// Shows a clear button when given.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
              Padding(
                padding: const EdgeInsets.only(right: Space.md),
                child: Icon(icon),
              ),
            ],
          ),
        ),
        child: Text(
          value ?? 'Not set',
          style: value == null
              ? context.text.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                )
              : context.text.bodyLarge,
        ),
      ),
    );
  }
}
