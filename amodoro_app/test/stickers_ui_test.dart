import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:amodoro_app/screens/sticker_editor_screen.dart';
import 'package:amodoro_app/screens/sticker_collection_screen.dart';
import 'package:amodoro_app/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('StickerEditorScreen renders Neo-Pastel UI elements in initial state',
      (WidgetTester tester) async {
    final api = AmodoroApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: StickerEditorScreen(api: api),
      ),
    );

    // Verify header and empty state buttons exist
    expect(find.text('CREAR STICKER'), findsOneWidget);
    expect(find.text('Crea un sticker para tu pareja'), findsOneWidget);
    expect(find.text('ELEGIR DE LA GALERÍA'), findsOneWidget);
    expect(find.text('TOMAR FOTO CON CÁMARA'), findsOneWidget);
  });

  testWidgets('StickerCollectionScreen renders header and create button',
      (WidgetTester tester) async {
    final api = AmodoroApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: StickerCollectionScreen(api: api),
      ),
    );

    // Initial frame shows header and CREAR button
    expect(find.text('STICKERS'), findsOneWidget);
    expect(find.text('CREAR'), findsOneWidget);
  });
}
