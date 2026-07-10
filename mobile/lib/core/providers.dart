import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));
