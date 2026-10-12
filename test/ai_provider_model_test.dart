import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/models/ai_provider.dart';

void main() {
  group('AiProvider model', () {
    test('fromJson parses minimal fields', () {
      final json = <String, dynamic>{
        'id': 'p1',
        'name': 'OpenAI',
        'enabled': true,
        'url': 'https://api.openai.com/v1',
        'model': 'gpt-4o-mini',
        'fallbackPriority': 1,
      };
      final p = AiProvider.fromJson(json);
      expect(p.id, 'p1');
      expect(p.name, 'OpenAI');
      expect(p.enabled, true);
      expect(p.url, 'https://api.openai.com/v1');
      expect(p.model, 'gpt-4o-mini');
      expect(p.fallbackPriority, 1);
    });

    test('toJson excludes empty optional fields', () {
      final p = const AiProvider(
        id: 'x',
        name: 'X',
        enabled: false,
        url: 'u',
        model: 'm',
      );
      final json = p.toJson();
      expect(json.containsKey('api_key'), false);
      expect(json.containsKey('loginUrl'), false);
      expect(json.containsKey('logoUrl'), false);
    });

    test('copyWith overrides fields', () {
      final p = const AiProvider(
        id: 'x',
        name: 'X',
        enabled: false,
        url: 'u',
        model: 'm',
        fallbackPriority: 0,
      );
      final p2 = p.copyWith(enabled: true, fallbackPriority: 5, name: 'Y');
      expect(p2.enabled, true);
      expect(p2.fallbackPriority, 5);
      expect(p2.name, 'Y');
      expect(p2.url, 'u');
    });
  });
}
