import 'dart:math';

class FinancialCalculations {
  /// XIRR calculation using Newton-Raphson method
  static double calculateXIRR(List<Map<String, dynamic>> cashFlows, double currentValue) {
    if (cashFlows.isEmpty) return 0;

    final List<Map<String, dynamic>> allCashFlows = List.from(cashFlows);
    allCashFlows.add({'date': DateTime.now(), 'amount': currentValue});

    allCashFlows.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final filteredFlows = allCashFlows.where((cf) => (cf['amount'] as double).abs() > 0.01).toList();
    if (filteredFlows.length < 2) return 0;

    final uniqueDates = filteredFlows.map((cf) => (cf['date'] as DateTime).toIso8601String().split('T')[0]).toSet();
    if (uniqueDates.length <= 1) return 0;

    // Safety check: If all cash flows have the same sign, XIRR is mathematically undefined.
    // If all are negative (investments) and current value is 0, return -100.
    final bool hasPositive = filteredFlows.any((cf) => (cf['amount'] as double) > 0);
    final bool hasNegative = filteredFlows.any((cf) => (cf['amount'] as double) < 0);
    if (!hasPositive || !hasNegative) {
      if (hasNegative && !hasPositive) return -100.0;
      return 0;
    }

    double rate = 0.1; // Initial guess: 10%
    const int maxIterations = 100;
    const double tolerance = 0.0001;

    for (int i = 0; i < maxIterations; i++) {
      double npv = 0;
      double derivativeNPV = 0;

      for (final cf in filteredFlows) {
        final daysDiff = (cf['date'] as DateTime).difference(filteredFlows[0]['date'] as DateTime).inDays;
        final years = daysDiff / 365.25;
        final discountFactor = pow(1 + rate, -years);

        final amount = cf['amount'] as double;
        npv += amount * discountFactor;
        derivativeNPV += amount * (-years) * discountFactor / (1 + rate);
      }

      if (npv.abs() < tolerance) return rate * 100;
      if (derivativeNPV.abs() < 1e-10) break;

      rate = rate - npv / derivativeNPV;
      if (rate > 1000.0) rate = 1000.0;
      if (rate < -0.99) rate = -0.99;
    }

    return rate * 100;
  }

  static double calculateCAGR(double currentValue, double investmentAmount, DateTime startDate) {
    final now = DateTime.now();
    final years = now.difference(startDate).inDays / 365.25;

    if (years <= 0 || investmentAmount <= 0) return 0;
    
    double cagr = (pow(currentValue / investmentAmount, 1 / years) - 1) * 100;
    if (cagr > 100000) cagr = 100000;
    return cagr;
  }
}
