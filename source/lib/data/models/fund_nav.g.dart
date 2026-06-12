// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_nav.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FundNAV _$FundNAVFromJson(Map<String, dynamic> json) =>
    FundNAV(date: json['date'] as String, nav: (json['nav'] as num).toDouble());

Map<String, dynamic> _$FundNAVToJson(FundNAV instance) => <String, dynamic>{
  'date': instance.date,
  'nav': instance.nav,
};

FundHistory _$FundHistoryFromJson(Map<String, dynamic> json) => FundHistory(
  schemeCode: json['schemeCode'] as String,
  schemeName: json['schemeName'] as String,
  data: (json['data'] as List<dynamic>)
      .map((e) => FundNAV.fromJson(e as Map<String, dynamic>))
      .toList(),
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$FundHistoryToJson(FundHistory instance) =>
    <String, dynamic>{
      'schemeCode': instance.schemeCode,
      'schemeName': instance.schemeName,
      'data': instance.data,
      'timestamp': instance.timestamp.toIso8601String(),
    };
