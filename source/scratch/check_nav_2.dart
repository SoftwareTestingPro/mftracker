import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.mfapi.in/mf'));
  try {
    final response = await dio.get('/122639');
    if (response.statusCode == 200) {
      final data = response.data;
      print('Scheme: ${data['meta']['scheme_name']}');
      final latest = data['data'][0];
      print('Latest NAV: ${latest['nav']} on ${latest['date']}');
    } else {
      print('Failed to fetch data: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
