import 'package:json_annotation/json_annotation.dart';

part 'fund_nav.g.dart';

@JsonSerializable()
class FundNAV {
  final String date;
  final double nav;

  FundNAV({required this.date, required this.nav});

  factory FundNAV.fromJson(Map<String, dynamic> json) => _$FundNAVFromJson(json);
  Map<String, dynamic> toJson() => _$FundNAVToJson(this);
}

@JsonSerializable()
class FundHistory {
  final String schemeCode;
  final String schemeName;
  final List<FundNAV> data;
  final DateTime timestamp;

  FundHistory({
    required this.schemeCode,
    required this.schemeName,
    required this.data,
    required this.timestamp,
  });

  factory FundHistory.fromJson(Map<String, dynamic> json) => _$FundHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$FundHistoryToJson(this);
}
