import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MqttPage());
  }
}

class MqttPage extends StatefulWidget {
  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  late MqttServerClient client;

  double voltage = 0;
  double current = 0;
  double power = 0;
  double energy = 0;

  List<FlSpot> powerSpots = [];
  int xIndex = 0;

  @override
  void initState() {
    super.initState();
    connectMQTT();
  }

  Future<void> connectMQTT() async {
    client = MqttServerClient(
      '94a3a8628a2940f3a97c37538f50b219.s1.eu.hivemq.cloud',
      'flutter_client',
    );

    client.port = 8883;
    client.secure = true;
    client.keepAlivePeriod = 20;

    client.connectionMessage = MqttConnectMessage()
        .authenticateAs('freeAkses1', 'freeAkses1')
        .withClientIdentifier('flutter_client')
        .startClean();

    try {
      await client.connect();
      debugPrint("MQTT Connected");
    } catch (e) {
      debugPrint("Failed: $e");
      return;
    }

    client.subscribe('iot/pzem', MqttQos.atMostOnce);

    client.updates!.listen((event) {
      final recMess = event[0].payload as MqttPublishMessage;

      final msg = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      final data = jsonDecode(msg);

      setState(() {
        voltage = (data['voltage'] ?? 0).toDouble();
        current = (data['current'] ?? 0).toDouble();
        power = (data['power'] ?? 0).toDouble();
        energy = (data['energy'] ?? 0).toDouble();

        powerSpots.add(FlSpot(xIndex.toDouble(), power));
        xIndex++;

        if (powerSpots.length > 20) {
          powerSpots.removeAt(0);
        }
      });
    });
  }

  Widget infoCard(String title, String value, String unit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text(
              "$value $unit",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChart() {
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(show: true),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: powerSpots,
              dotData: FlDotData(show: false),
              barWidth: 3,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("MQTT Power Monitor"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 1.6,
              physics: NeverScrollableScrollPhysics(),
              children: [
                infoCard("Voltage", voltage.toStringAsFixed(1), "V"),
                infoCard("Current", current.toStringAsFixed(2), "A"),
                infoCard("Power", power.toStringAsFixed(1), "W"),
                infoCard("Energy", energy.toStringAsFixed(2), "kWh"),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Realtime Power Graph",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Expanded(child: buildChart()),
          ],
        ),
      ),
    );
  }
}
