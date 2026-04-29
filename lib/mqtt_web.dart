import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createClient(String host, String clientId) {
  final client = MqttBrowserClient.withPort(
    'wss://$host:8884/mqtt',
    clientId,
    8884,
  );

  client.websocketProtocols = ['mqtt'];

  return client;
}
