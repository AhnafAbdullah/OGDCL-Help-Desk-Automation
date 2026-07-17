import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Shared AES-256-CBC codec for the build-attribution blob
/// (`assets/attrib.bin`). Used both by the runtime loader and by
/// `tool/generate_attribution.dart`, so the two can never drift apart.
///
/// This is deliberate obfuscation, not real secrecy: the key ships inside
/// the app, so anyone determined enough can recover the plaintext. The point
/// is that the credit line is not a greppable string in the source or in the
/// APK, and that swapping/deleting the blob is detected rather than silently
/// honoured.
class AttributionCodec {
  AttributionCodec._();

  /// Key material is assembled at runtime from fragments so the passphrase
  /// never appears as one contiguous literal in the compiled binary.
  static const List<String> _fragments = <String>[
    'ogdcl',
    '::hd',
    '-attrib',
    '::v1',
    '::au',
    '-cs23',
  ];

  static Key _key() {
    final passphrase = _fragments.join();
    // SHA-256 gives us exactly the 32 bytes AES-256 wants.
    return Key(Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes));
  }

  /// Encrypts [plaintext] into the on-disk blob layout: a 16-byte IV
  /// followed by the AES-256-CBC ciphertext.
  static Uint8List encryptToBlob(String plaintext) {
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key(), mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]);
  }

  /// Reverses [encryptToBlob]. Throws if [blob] is truncated or corrupt.
  static String decryptBlob(Uint8List blob) {
    if (blob.length <= 16) {
      throw const FormatException('Attribution blob is truncated.');
    }
    final iv = IV(Uint8List.sublistView(blob, 0, 16));
    final cipherText = Uint8List.sublistView(blob, 16);
    final encrypter = Encrypter(AES(_key(), mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted(cipherText), iv: iv);
  }

  /// Hex SHA-256 of the plaintext, used as the tamper check.
  static String digestOf(String plaintext) =>
      sha256.convert(utf8.encode(plaintext)).toString();
}
