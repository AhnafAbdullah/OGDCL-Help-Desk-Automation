import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'attribution_codec.dart';

/// Loads the build attribution credit from the encrypted blob at
/// `assets/attrib.bin`, verifying it hasn't been tampered with before it's
/// shown on the login screen. The plaintext is deliberately not written
/// anywhere in this source tree — regenerate the blob with
/// `dart run tool/generate_attribution.dart "<text>"`.
///
/// Removal resistance, honestly scoped:
///  - The credit is never a plaintext literal in the source or in the APK's
///    string table, so it can't be found by grepping or by `strings`.
///  - The decrypted value is checked against [_expectedDigest]; editing or
///    replacing the blob with different text is rejected.
///  - If the blob is deleted, corrupted, or swapped, [load] falls back to an
///    independently-encoded copy ([_fallbackEncoded]) rather than showing
///    nothing — so deleting the asset does not remove the credit.
///
/// This is tamper-resistance, not security: the key ships inside the app, so
/// anyone with the source (or enough patience with the binary) can still
/// defeat it. There is no client-side way around that.
class Attribution {
  Attribution._();

  /// SHA-256 of the expected plaintext. Regenerate with
  /// `dart run tool/generate_attribution.dart` if the text ever changes.
  static const _expectedDigest =
      '6f79c381273a8be973fcb8472220be8bcb2258aa047e8a43f7cc22a0c0f6c0f2';

  /// Base64 of the UTF-8 plaintext, reversed. A second, independent
  /// representation so that deleting assets/attrib.bin doesn't silently drop
  /// the credit — and so the two copies must both be found to remove it.
  static const _fallbackEncoded = '=MjMtM1QgkHdpNnclZXauVFIylWQgknYgQHbpVnQ';

  static const _assetKey = 'assets/attrib.bin';

  static String? _cached;

  /// Returns the attribution text. Never throws and never returns empty —
  /// a broken/missing blob degrades to the fallback copy.
  static Future<String> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    String? value;
    try {
      final data = await rootBundle.load(_assetKey);
      final blob = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final decrypted = AttributionCodec.decryptBlob(Uint8List.fromList(blob));
      if (AttributionCodec.digestOf(decrypted) == _expectedDigest) {
        value = decrypted;
      }
    } catch (_) {
      // Missing or corrupt blob — fall through to the fallback below.
    }

    value ??= _decodeFallback();
    _cached = value;
    return value;
  }

  static String _decodeFallback() =>
      utf8.decode(base64.decode(String.fromCharCodes(_fallbackEncoded.runes.toList().reversed)));
}
