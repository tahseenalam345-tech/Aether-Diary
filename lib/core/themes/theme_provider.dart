import 'package:flutter_riverpod/flutter_riverpod.dart';

// This is our global brain for the theme. 
// true = AMOLED Pitch Black, false = Standard Dark Mode
// It defaults to true (AMOLED).
final themeProvider = StateProvider<bool>((ref) => true);