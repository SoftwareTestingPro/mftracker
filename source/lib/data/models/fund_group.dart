import 'package:json_annotation/json_annotation.dart';

part 'fund_group.g.dart';

@JsonSerializable()
class FundGroup {
  final String id;
  final String name;
  final List<String> fundIds; // List of FundInvestment IDs
  final String? description;
  final DateTime createdAt;

  FundGroup({
    required this.id,
    required this.name,
    required this.fundIds,
    this.description,
    required this.createdAt,
  });

  factory FundGroup.fromJson(Map<String, dynamic> json) => _$FundGroupFromJson(json);
  Map<String, dynamic> toJson() => _$FundGroupToJson(this);
}
