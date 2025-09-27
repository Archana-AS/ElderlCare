import 'package:mysql_client/mysql_client.dart';

Future<String> getPublicUrl() async {
  MySQLConnection? conn;
  const DB_URL = 'mysql://project_fortycourt:117375f4f8594cdd6211ee81756a14a779688625@yethg8.h.filess.io:3307/project_fortycourt';
  String url='';

  final uri = Uri.parse(DB_URL);
  final host = uri.host;
  final port = uri.port;
  final user = uri.userInfo.split(':')[0];
  final password = uri.userInfo.split(':')[1];
  final dbName = uri.pathSegments.first;

  try {
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: dbName,
    );
    await conn.connect();
    var result = await conn.execute("SELECT public_url FROM filessio");
    url = result.rows.first.assoc()['public_url'] ?? '';

  } catch (e) {
    print("public url error: $e");

  } finally {
    if (conn != null && conn.connected) {
      await conn.close();
    }
  }

  return url;
}
