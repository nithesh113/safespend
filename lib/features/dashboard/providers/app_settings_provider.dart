import 'package:flutter/material.dart';

/// Global constant for monthly income used in Safe-to-Spend calculations.
const double monthlyIncome = 350000.0; // ¥350,000

/// App-level settings and global state.
class AppSettingsProvider extends ChangeNotifier {
  double _monthlyIncome = 350000.0;

  double get monthlyIncome => _monthlyIncome;

  void setMonthlyIncome(double amount) {
    _monthlyIncome = amount;
    notifyListeners();
  }
}