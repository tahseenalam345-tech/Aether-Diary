import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final userNameProvider = AsyncNotifierProvider<UserNameNotifier, String?>(() {
  return UserNameNotifier();
});

class UserNameNotifier extends AsyncNotifier<String?> {
  final _storage = const FlutterSecureStorage();
  static const _key = 'aether_user_name';

  @override
  Future<String?> build() async {
    // App start hoty hi secure storage se naam nikalega
    return await _storage.read(key: _key);
  }

  Future<void> setName(String name) async {
    // Naam save karega aur UI ko instantly update karega
    await _storage.write(key: _key, value: name.trim());
    state = AsyncValue.data(name.trim());
  }
}