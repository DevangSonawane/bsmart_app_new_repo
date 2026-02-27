import 'package:flutter_test/flutter_test.dart';
import 'package:b_smart/theme/design_tokens.dart';
import 'package:b_smart/theme/app_theme.dart';

void main() {
  test('design tokens and theme load', () {
    // Ensure design tokens exist
    expect(DesignTokens.instaPink, isNotNull);
    expect(DesignTokens.instaPurple, isNotNull);

    // Ensure theme can be constructed
    final theme = AppTheme.theme;
    expect(theme, isNotNull);
    expect(theme.primaryColor, DesignTokens.instaPurple);
  });
}

