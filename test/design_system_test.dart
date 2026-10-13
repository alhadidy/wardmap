import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/components.dart';
import 'package:wardmap/roles.dart';
import 'package:wardmap/theme.dart';

/// WCAG contrast ratio between two colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', lightTheme()),
    ('dark', darkTheme()),
  ]) {
    group('$name theme', () {
      test('text is readable on every surface (WCAG AA, 4.5:1)', () {
        final c = theme.colorScheme;
        for (final bg in [c.surface, theme.scaffoldBackgroundColor]) {
          expect(contrast(c.onSurface, bg), greaterThan(4.5));
          expect(contrast(c.onSurfaceVariant, bg), greaterThan(4.5));
        }
        expect(contrast(c.onPrimary, c.primary), greaterThan(4.5));
      });

      test('every status pill color is readable', () {
        final tones = theme.extension<ToneColors>()!;
        for (final t in Tone.values) {
          expect(
            contrast(tones.foreground(t), tones.background(t)),
            greaterThan(4.5),
            reason: t.name,
          );
        }
      });

      testWidgets('shared components draw', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  const BrandMark(),
                  const StatusPill('No note in 24h', tone: Tone.danger),
                  const Notice('Logged out'),
                  RoleAvatar(StaffRole.consultant),
                  const BedBadge(3),
                  const SectionHeader('Care team'),
                  const InfoGrid([InfoItem('MRN', '445566')]),
                ],
              ),
            ),
          ),
        );
        expect(find.text('No note in 24h'), findsOneWidget);
        expect(find.text('CON'), findsOneWidget);
        expect(find.text('CARE TEAM'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  test('roles are colored by seniority', () {
    expect(RoleAvatar.toneOf(StaffRole.consultant), Tone.brand);
    expect(RoleAvatar.toneOf(StaffRole.r1), Tone.info);
    expect(RoleAvatar.toneOf(StaffRole.rotator), Tone.neutral);
  });
}
