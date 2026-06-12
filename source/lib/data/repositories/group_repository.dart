import 'dart:convert';
import '../models/fund_group.dart';
import '../services/drive_service.dart';

class GroupRepository {
  final DriveService _drive;
  static const String _fileName = 'groups.json';

  GroupRepository(this._drive);

  Future<List<FundGroup>> getGroups({bool forceRefresh = false}) async {
    final String? jsonString = await _drive.readFile(_fileName, forceRefresh: forceRefresh);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => FundGroup.fromJson(j)).toList();
    } catch (e) {
      print('Error parsing groups: $e');
      return [];
    }
  }

  Future<void> saveGroups(List<FundGroup> groups) async {
    final String jsonString = jsonEncode(groups.map((g) => g.toJson()).toList());
    await _drive.writeFile(_fileName, jsonString);
  }

  Future<void> addGroup(FundGroup group) async {
    final groups = await getGroups();
    groups.add(group);
    await saveGroups(groups);
  }

  Future<void> removeGroup(String id) async {
    final groups = await getGroups();
    groups.removeWhere((g) => g.id == id);
    await saveGroups(groups);
  }
}
