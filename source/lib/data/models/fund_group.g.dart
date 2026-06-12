// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FundGroup _$FundGroupFromJson(Map<String, dynamic> json) => FundGroup(
  id: json['id'] as String,
  name: json['name'] as String,
  fundIds: (json['fundIds'] as List<dynamic>).map((e) => e as String).toList(),
  description: json['description'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$FundGroupToJson(FundGroup instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'fundIds': instance.fundIds,
  'description': instance.description,
  'createdAt': instance.createdAt.toIso8601String(),
};
