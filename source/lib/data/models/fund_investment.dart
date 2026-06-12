import 'package:json_annotation/json_annotation.dart';

part 'fund_investment.g.dart';

@JsonSerializable()
class FundInvestment {
  final String id;
  final String schemeCode;
  final String schemeName;
  final DateTime investmentDate;
  final double investmentAmount;
  final double units;
  final double nav;
  final String type; // 'purchase' or 'redeem'
  final String? purchaseMode; // 'lumpsum' or 'sip'
  final String? sipFrequency;
  final String? amcName;
  final String? category;
  final String? sipGroupId;
  final bool? isSipOngoing;
  final DateTime? sipEndDate;

  FundInvestment({
    required this.id,
    required this.schemeCode,
    required this.schemeName,
    required this.investmentDate,
    required this.investmentAmount,
    required this.units,
    required this.nav,
    this.type = 'purchase',
    this.purchaseMode,
    this.sipFrequency,
    this.amcName,
    this.category,
    this.sipGroupId,
    this.isSipOngoing,
    this.sipEndDate,
  });

  factory FundInvestment.fromJson(Map<String, dynamic> json) => _$FundInvestmentFromJson(json);
  Map<String, dynamic> toJson() => _$FundInvestmentToJson(this);

  FundInvestment copyWith({
    String? id,
    String? schemeCode,
    String? schemeName,
    DateTime? investmentDate,
    double? investmentAmount,
    double? units,
    double? nav,
    String? type,
    String? purchaseMode,
    String? sipFrequency,
    String? amcName,
    String? category,
    String? sipGroupId,
    bool? isSipOngoing,
    DateTime? sipEndDate,
  }) {
    return FundInvestment(
      id: id ?? this.id,
      schemeCode: schemeCode ?? this.schemeCode,
      schemeName: schemeName ?? this.schemeName,
      investmentDate: investmentDate ?? this.investmentDate,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      units: units ?? this.units,
      nav: nav ?? this.nav,
      type: type ?? this.type,
      purchaseMode: purchaseMode ?? this.purchaseMode,
      sipFrequency: sipFrequency ?? this.sipFrequency,
      amcName: amcName ?? this.amcName,
      category: category ?? this.category,
      sipGroupId: sipGroupId ?? this.sipGroupId,
      isSipOngoing: isSipOngoing ?? this.isSipOngoing,
      sipEndDate: sipEndDate ?? this.sipEndDate,
    );
  }
}
