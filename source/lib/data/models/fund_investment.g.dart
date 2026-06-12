// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_investment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FundInvestment _$FundInvestmentFromJson(Map<String, dynamic> json) =>
    FundInvestment(
      id: json['id'] as String,
      schemeCode: json['schemeCode'] as String,
      schemeName: json['schemeName'] as String,
      investmentDate: DateTime.parse(json['investmentDate'] as String),
      investmentAmount: (json['investmentAmount'] as num).toDouble(),
      units: (json['units'] as num).toDouble(),
      nav: (json['nav'] as num).toDouble(),
      type: json['type'] as String? ?? 'purchase',
      purchaseMode: json['purchaseMode'] as String?,
      sipFrequency: json['sipFrequency'] as String?,
      amcName: json['amcName'] as String?,
      category: json['category'] as String?,
      sipGroupId: json['sipGroupId'] as String?,
      isSipOngoing: json['isSipOngoing'] as bool?,
      sipEndDate: json['sipEndDate'] == null
          ? null
          : DateTime.parse(json['sipEndDate'] as String),
    );

Map<String, dynamic> _$FundInvestmentToJson(FundInvestment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'schemeCode': instance.schemeCode,
      'schemeName': instance.schemeName,
      'investmentDate': instance.investmentDate.toIso8601String(),
      'investmentAmount': instance.investmentAmount,
      'units': instance.units,
      'nav': instance.nav,
      'type': instance.type,
      'purchaseMode': instance.purchaseMode,
      'sipFrequency': instance.sipFrequency,
      'amcName': instance.amcName,
      'category': instance.category,
      'sipGroupId': instance.sipGroupId,
      'isSipOngoing': instance.isSipOngoing,
      'sipEndDate': instance.sipEndDate?.toIso8601String(),
    };
