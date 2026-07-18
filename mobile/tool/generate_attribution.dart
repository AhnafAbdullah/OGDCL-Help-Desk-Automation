// Regenerates the encrypted build-attribution blob.
//
//   dart run tool/generate_attribution.dart "<attribution text>"
//
// Writes assets/attrib.bin and prints the SHA-256 digest of the plaintext.
// Paste that digest into `_expectedDigest` in
// lib/core/branding/attribution.dart, and the reversed-base64 of the text
// into `_fallbackEncoded` there, otherwise the runtime integrity check will
// (correctly) reject the new blob.
//
// The text is taken as an argument rather than a constant on purpose: it
// keeps the credit out of the source tree, so it can't be found by grepping
// the repo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_hdworkflow/core/branding/attribution_codec.dart';

void main(List<String> args) {
  if (args.length != 1 || args.single.trim().isEmpty) {
    stderr.writeln('Usage: dart run tool/generate_attribution.dart "<attribution text>"');
    exitCode = 64; // EX_USAGE
    return;
  }

  final attributionText = args.single;
  final blob = AttributionCodec.encryptToBlob(attributionText);

  // Round-trip immediately so a bad build fails here, not on a user's phone.
  final roundTripped = AttributionCodec.decryptBlob(blob);
  if (roundTripped != attributionText) {
    stderr.writeln('FAILED: round-trip mismatch ("$roundTripped").');
    exitCode = 1;
    return;
  }

  File('assets/attrib.bin').writeAsBytesSync(blob);

  final fallback =
      String.fromCharCodes(base64.encode(utf8.encode(attributionText)).runes.toList().reversed);

  stdout
    ..writeln('Wrote assets/attrib.bin (${blob.length} bytes)')
    ..writeln('Digest   (_expectedDigest)  : ${AttributionCodec.digestOf(attributionText)}')
    ..writeln('Fallback (_fallbackEncoded) : $fallback');
}
