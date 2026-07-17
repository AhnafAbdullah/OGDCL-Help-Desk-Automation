import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hdworkflow/core/branding/attribution.dart';
import 'package:flutter_hdworkflow/core/branding/attribution_codec.dart';

/// The credit is deliberately absent from lib/ and tool/, so the expected
/// value is reconstructed here rather than written as a literal — that keeps
/// `grep -r "Air University" lib tool` clean while still pinning the text.
final _expected = utf8.decode(base64.decode('QnVpbHQgYnkgQWlyIFVuaXZlcnNpdHkgQ1MtMjM='));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('codec round-trips the attribution text', () {
    final blob = AttributionCodec.encryptToBlob(_expected);
    expect(AttributionCodec.decryptBlob(blob), _expected);
  });

  test('encrypted blob is not readable as plaintext', () {
    final blob = AttributionCodec.encryptToBlob(_expected);
    expect(String.fromCharCodes(blob).contains('Air University'), isFalse);
  });

  test('a tampered blob fails the digest check', () {
    final blob = AttributionCodec.encryptToBlob('Built by Someone Else');
    // Decrypts fine, but must not match the pinned digest.
    expect(
      AttributionCodec.digestOf(AttributionCodec.decryptBlob(blob)),
      isNot(AttributionCodec.digestOf(_expected)),
    );
  });

  test('Attribution.load() decrypts the shipped asset to the credit', () async {
    expect(await Attribution.load(), _expected);
  });
}
