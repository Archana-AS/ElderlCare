import 'package:firebase_database/firebase_database.dart';

Future<String> getPublicUrl() async {
  const String dbPath = 'latest_url';
  final ref = FirebaseDatabase.instance.ref(dbPath);
  final DataSnapshot snapshot = await ref.get();

  if (snapshot.exists && snapshot.value is String) {
    return snapshot.value as String;
  } else {
    throw Exception("URL data not found or is invalid at path: /$dbPath");
  }
}
