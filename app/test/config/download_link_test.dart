import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/config/download_link.dart';

void main() {
  test('añade la ruta de descarga a la base del entorno', () {
    expect(
      downloadLinkFrom('https://mykcal-bk-api.cruzerick.com'),
      'https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk',
    );
  });

  test('una barra final en la base no produce // ', () {
    expect(
      downloadLinkFrom('https://mykcal-bk-dev-api.cruzerick.com/'),
      'https://mykcal-bk-dev-api.cruzerick.com/descargar/mykcal.apk',
    );
  });

  test('una base sin https:// es un error de configuración', () {
    expect(() => downloadLinkFrom('http://x.com'), throwsStateError);
    expect(() => downloadLinkFrom(''), throwsStateError);
  });
}
