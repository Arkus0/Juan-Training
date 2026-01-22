import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final ids = args.isNotEmpty
      ? args.map(int.parse).toList()
      : [9, 12, 20, 51, 158, 1000, 1012, 1022, 1079, 1080];
  const preferredLang = 4; // Spanish
  const fallbackLang = 2; // English

  for (final id in ids) {
    print('\n--- ID $id ---');
    try {
      final infoUrl = 'https://wger.de/api/v2/exerciseinfo/$id/';
      final infoResp = await http.get(Uri.parse(infoUrl)).timeout(Duration(seconds: 8));
      if (infoResp.statusCode != 200) {
        print('exerciseinfo $id -> status ${infoResp.statusCode}');
        continue;
      }
      final infoJson = jsonDecode(infoResp.body) as Map<String, dynamic>;

      // direct name on exerciseinfo
      final directName = (infoJson['name'] as String?)?.trim();
      if (directName != null && directName.isNotEmpty) {
        print('Name (exerciseinfo direct): $directName');
        continue;
      }

      // try translations array
      final translations = (infoJson['translations'] as List<dynamic>?) ?? [];
      String? chosenName;
      int? chosenTransId;
      for (final t in translations) {
        if (t is Map<String, dynamic>) {
          final lang = t['language'];
          final tname = (t['name'] as String?)?.trim();
          if (lang == preferredLang && tname != null && tname.isNotEmpty) {
            chosenName = tname;
            break;
          }
          if (lang == fallbackLang && tname != null && tname.isNotEmpty) {
            chosenName = tname; // keep as candidate
          }
          // capture translation id for fallback to /exercise/
          if (lang == fallbackLang && chosenTransId == null) {
            final tid = t['id'];
            if (tid is int) chosenTransId = tid;
          }
        }
      }

      if (chosenName != null) {
        print('Name from translations: $chosenName');
        continue;
      }

      // If translations didn't provide name, try /exercise/{transId}/ if available
      if (chosenTransId != null) {
        final exUrl = 'https://wger.de/api/v2/exercise/$chosenTransId/';
        try {
          final exResp = await http.get(Uri.parse(exUrl)).timeout(Duration(seconds: 8));
          if (exResp.statusCode == 200 && exResp.body.isNotEmpty) {
            final exJson = jsonDecode(exResp.body) as Map<String, dynamic>;
            final exName = (exJson['name'] as String?)?.trim();
            if (exName != null && exName.isNotEmpty) {
              print('Name from /exercise/ (trans id $chosenTransId): $exName');
              continue;
            }
          } else {
            print('/exercise/$chosenTransId -> status ${exResp.statusCode}');
          }
        } catch (e) {
          print('Error fetching /exercise/$chosenTransId: $e');
        }
      }

      // As a last attempt, try /exercise/$id/ directly
      try {
        final exResp2 = await http.get(Uri.parse('https://wger.de/api/v2/exercise/$id/')).timeout(Duration(seconds: 8));
        if (exResp2.statusCode == 200 && exResp2.body.isNotEmpty) {
          final exJson2 = jsonDecode(exResp2.body) as Map<String, dynamic>;
          final exName2 = (exJson2['name'] as String?)?.trim();
          if (exName2 != null && exName2.isNotEmpty) {
            print('Name from /exercise/$id/: $exName2');
            continue;
          }
        } else {
          print('/exercise/$id -> status ${exResp2.statusCode}');
        }
      } catch (e) {
        print('Error fetching /exercise/$id: $e');
      }

      print('No name found for ID $id via translations or /exercise.');
    } catch (e) {
      print('Error processing $id: $e');
    }
    await Future.delayed(Duration(milliseconds: 200));
  }
}
