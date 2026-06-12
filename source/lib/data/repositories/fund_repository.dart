import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/fund_investment.dart';
import '../services/drive_service.dart';

class FundRepository {
  final DriveService _drive;
  static const String _fileName = 'investments.json';

  FundRepository(this._drive);

  Future<List<FundInvestment>> getInvestments({bool forceRefresh = false}) async {
    debugPrint('FundRepository: Reading $_fileName (force: $forceRefresh)...');
    final String? jsonString = await _drive.readFile(_fileName, forceRefresh: forceRefresh);
    if (jsonString == null) {
      debugPrint('FundRepository: No $_fileName found on Drive.');
      return [];
    }
    debugPrint('FundRepository: Fetched JSON string (length: ${jsonString.length})');

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final list = jsonList.map((j) => FundInvestment.fromJson(j)).toList();
      debugPrint('FundRepository: Successfully parsed ${list.length} investments.');
      return list;
    } catch (e) {
      debugPrint('FundRepository: Error parsing investments: $e');
      return [];
    }
  }

  Future<void> saveInvestments(List<FundInvestment> investments) async {
    final String jsonString = jsonEncode(investments.map((i) => i.toJson()).toList());
    await _drive.writeFile(_fileName, jsonString);
  }

  Future<void> addInvestment(FundInvestment investment) async {
    final investments = await getInvestments();
    investments.add(investment);
    await saveInvestments(investments);
  }

  Future<void> addInvestments(List<FundInvestment> newItems) async {
    final investments = await getInvestments();
    investments.addAll(newItems);
    await saveInvestments(investments);
  }

  Future<void> removeInvestment(String id) async {
    final investments = await getInvestments();
    investments.removeWhere((i) => i.id == id);
    await saveInvestments(investments);
  }

  Future<void> removeInvestments(List<String> ids) async {
    final investments = await getInvestments();
    investments.removeWhere((i) => ids.contains(i.id));
    await saveInvestments(investments);
  }

  Future<void> updateInvestment(FundInvestment investment) async {
    final investments = await getInvestments();
    final index = investments.indexWhere((i) => i.id == investment.id);
    if (index != -1) {
      investments[index] = investment;
      await saveInvestments(investments);
    }
  }
}
