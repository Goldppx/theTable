import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:html/parser.dart' as html;
import 'package:pointycastle/export.dart';

class CasPage {
  const CasPage({required this.salt, required this.execution, required this.lt, required this.captchaSwitch});
  final String salt, execution, lt, captchaSwitch;
  factory CasPage.parse(String source) {
    final document = html.parse(source);
    final form = document.querySelector('#pwdFromId');
    String field(String key) => form?.querySelector('[id="$key"], [name="$key"]')?.attributes['value'] ?? '';
    final salt = field('pwdEncryptSalt');
    final execution = field('execution');
    if (form == null || utf8.encode(salt.trim()).length != 16 || execution.isEmpty) {
      throw const FormatException('统一认证页面结构已变化，请更新应用');
    }
    final captchaSwitch = RegExp(r'''captchaSwitch\s*=\s*["']([^"']*)["']''').firstMatch(source)?.group(1) ?? '';
    return CasPage(salt: salt, execution: execution, lt: field('lt'), captchaSwitch: captchaSwitch);
  }
}

class CasCrypto {
  static const alphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
  static String _randomAscii(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }
  /// UEM functions 7876/7878: UTF8, AES-128-CBC, PKCS7, Base64 ciphertext.
  static String encrypt(String value, String salt, {String? prefix, String? iv}) {
    final key = Uint8List.fromList(utf8.encode(salt.trim()));
    if (key.length != 16) throw const FormatException('认证密钥长度错误');
    final noise = prefix ?? _randomAscii(64);
    final vector = Uint8List.fromList(utf8.encode(iv ?? _randomAscii(16)));
    if (noise.length != 64 || vector.length != 16) throw ArgumentError('Invalid CAS random prefix or IV');
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(true, PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(ParametersWithIV(KeyParameter(key), vector), null));
    return base64Encode(cipher.process(Uint8List.fromList(utf8.encode('$noise$value'))));
  }
  static String sliderSign(Map<String, dynamic> payload, String smallImage, {String? prefix, String? iv}) {
    final bytes = base64Decode(smallImage);
    if (bytes.length < 16) throw const FormatException('滑块图片缺少签名密钥');
    final key = String.fromCharCodes(bytes.sublist(bytes.length - 16));
    return encrypt(jsonEncode(payload), key, prefix: prefix, iv: iv);
  }
}

class SliderChallenge {
  SliderChallenge.fromJson(Map<String, dynamic> json)
      : bigImage = json['bigImage'] as String,
        smallImage = json['smallImage'] as String,
        tagWidth = double.tryParse('${json['tagWidth']}') ?? 0;
  final String bigImage, smallImage;
  final double tagWidth;
}
