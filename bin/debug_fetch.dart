import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final ids = args.isNotEmpty ? args.map(int.parse).toList() : [9,12,20,51,158];
  for (final id in ids) {
    for (final lang in [4,2,1]) {
      final url = 'https://wger.de/api/v2/exerciseinfo/$id/?language=$lang';
      try {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        print('ID $id lang=$lang status=${r.statusCode}');
        if (r.statusCode == 200) {
          try {
            final j = jsonDecode(r.body);
            print(jsonEncode({'name': j['name'], 'short': (j['description'] as String?)?.substring(0, (j['description'] as String?)?.length.clamp(0, 80) ?? 0)}));
          } catch (e) {
            print('  parse error: $e');
            print('  body: ${r.body.substring(0, r.body.length > 200 ? 200 : r.body.length)}');
          }
        } else {
          print('  body: ${r.body.substring(0, r.body.length > 200 ? 200 : r.body.length)}');
        }
      } catch (e) {
        print('ID $id lang=$lang error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
