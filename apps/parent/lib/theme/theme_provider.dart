import 'package:flutter/foundation.dart';

import '../theme/app_themes.dart';

/// ThemeProvider — manages app theme selection and persistence.
class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;

  AppTheme get currentTheme => _currentTheme;

  void setTheme(AppTheme theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
    }
  }
}
