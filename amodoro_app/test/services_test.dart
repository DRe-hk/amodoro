import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:amodoro_app/services/local_lock.dart';
import 'package:amodoro_app/models/amodoro_models.dart';
import 'package:amodoro_app/widgets/amodoro_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('LocalLockService', () {
    test('generates valid RFC 4122 UUID v4 deviceId and persists it', () async {
      final lockService = LocalLockService();
      final id1 = await lockService.getDeviceId();
      expect(id1.length, 36);
      expect(id1[14], '4'); // Version 4
      expect(['8', '9', 'a', 'b'].contains(id1[19].toLowerCase()), true); // Variant RFC 4122

      // Second call should return the exact same persisted ID
      final id2 = await lockService.getDeviceId();
      expect(id2, id1);
    });

    test('hashes PIN with PBKDF2 and verifies correctly', () async {
      final lockService = LocalLockService();
      expect(await lockService.isPinConfigured(), false);

      await lockService.saveLocalPin('4242', 2);
      expect(await lockService.isPinConfigured(), true);
      expect(await lockService.getPinVersion(), 2);

      // Correct PIN
      final verified = await lockService.verifyLocalPin('4242');
      expect(verified, true);

      // Wrong PIN
      final wrong = await lockService.verifyLocalPin('0000');
      expect(wrong, false);
    });

    test('escalates lockout on 5 consecutive failed attempts', () async {
      final lockService = LocalLockService();
      await lockService.saveLocalPin('1111', 1);

      expect(await lockService.getRemainingLockoutSeconds(), 0);

      // 4 failed attempts: not locked out yet
      for (int i = 0; i < 4; i++) {
        final res = await lockService.verifyLocalPin('9999');
        expect(res, false);
        expect(await lockService.getRemainingLockoutSeconds(), 0);
      }

      // 5th failed attempt: 30s lockout
      final res5 = await lockService.verifyLocalPin('9999');
      expect(res5, false);
      final remaining = await lockService.getRemainingLockoutSeconds();
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(30));

      // Attempting with correct PIN while locked out fails
      final lockedAttempt = await lockService.verifyLocalPin('1111');
      expect(lockedAttempt, false);
    });
  });

  group('StickerModel', () {
    test('serializes and deserializes correctly', () {
      final sticker = StickerModel(
        id: 7,
        ownerId: 2,
        mediaId: 44,
        mediaUrl: 'https://amodoro.drehk.dev/api/media/44',
        createdAt: '2026-11-06T00:00:00Z',
        isMine: true,
      );
      final json = sticker.toJson();
      final fromJson = StickerModel.fromJson(json);

      expect(fromJson.id, 7);
      expect(fromJson.ownerId, 2);
      expect(fromJson.mediaId, 44);
      expect(fromJson.mediaUrl, 'https://amodoro.drehk.dev/api/media/44');
      expect(fromJson.isMine, true);
    });

    test('defaults isMine to false when omitted or false in JSON', () {
      final json = {
        'id': 10,
        'ownerId': 1,
        'mediaId': 99,
        'mediaUrl': '/api/media/99',
      };
      final fromJson = StickerModel.fromJson(json);
      expect(fromJson.isMine, false);
    });
  });

  group('AmodoroImage', () {
    test('sets and retains default global authentication token', () {
      AmodoroImage.setAuthToken('test-bearer-token-123');
      expect(AmodoroImage.defaultAuthToken, 'test-bearer-token-123');
    });
  });
}
