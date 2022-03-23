import 'package:flutter/material.dart';
CustomTheme currentTheme = CustomTheme();

class CustomTheme extends ChangeNotifier{
  static ThemeData get lightTheme {
    return ThemeData(
      appBarTheme: AppBarTheme(

      ),
      primaryColor: Color(0xFF37B5E8),
      accentColor: Colors.green,
      brightness: Brightness.light,

    );
  }
  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: Color(0xFF0084B5),
      accentColor: Colors.green[800],
      brightness: Brightness.dark,

    );
  }
}