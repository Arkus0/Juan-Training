import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final ids = [9,12,20,51,158,1000,1012,1022,1079,1080];
  final endpoints = [
    (int id, int lang) => 'https://wger.de/api/v2/exercise/$id/',
    (int id, int lang) => 'https://wger.de/api/v2/exercise/$id/?language=\$lang',
    (int id, int lang) => 'https://wger.de/api/v2/exerciseinfo/$id/?language=\$lang',
  ];
  for (final id in ids) {
    print('\n=== ID $id ===');
    for (final ep in endpoints) {
      for (final lang in [4,2,1]) {
        final url = ep(id, lang).replaceAll('\$lang', lang.toString());
        try {
          final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds:8));
          stdout.write('EP $url => ${r.statusCode}');
          if (r.statusCode == 200 && r.body.isNotEmpty) {
            try {
              final j = jsonDecode(r.body);
              final name = j is Map && j.containsKey('name') ? j['name'] : (j is Map && j.containsKey('exercise') ? j['exercise'] : null);
              final desc = j is Map && j.containsKey('description') ? ((j['description'] as String?)?.replaceAll('\n',' ') ?? '') : '';
              stdout.write(' | name=$name');
              if (desc.isNotEmpty) stdout.write(' | desc=${desc.substring(0, desc.length>80?80:desc.length)}');
            } catch (e) {
              stdout.write(' | parse-error');
            }
          } else if (r.body.isNotEmpty) {
            stdout.write(' | body-empty-or-non200');
          }
          print('');
        } catch (e) {
          print('EP $url error: $e');
        }
        await Future.delayed(const Duration(milliseconds:150));
      }
    }
  }
}
