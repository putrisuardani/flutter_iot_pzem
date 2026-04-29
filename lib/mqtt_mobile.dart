import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createClient(String host, String clientId) {
  final client = MqttServerClient(host, clientId);

  client.port = 8883;
  client.secure = true;

  return client;
}
