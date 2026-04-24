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

  String selectedMetric = "Power";

  List<FlSpot> chartData = [];
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

        double value = getSelectedValue();

        chartData.add(FlSpot(xIndex.toDouble(), value));
        xIndex++;

        if (chartData.length > 20) {
          chartData.removeAt(0);
        }
      });
    });
  }

  double getSelectedValue() {
    switch (selectedMetric) {
      case "Voltage":
        return voltage;
      case "Current":
        return current;
      case "Energy":
        return energy;
      default:
        return power;
    }
  }

  String getUnit() {
    switch (selectedMetric) {
      case "Voltage":
        return "V";
      case "Current":
        return "A";
      case "Energy":
        return "kWh";
      default:
        return "W";
    }
  }

  Widget infoCard(String title, String value, String unit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(
              "$value $unit",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChart() {
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: chartData,
            isCurved: true,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
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
      appBar: AppBar(title: const Text("MQTT Monitoring"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                infoCard("Voltage", voltage.toStringAsFixed(1), "V"),
                infoCard("Current", current.toStringAsFixed(2), "A"),
                infoCard("Power", power.toStringAsFixed(1), "W"),
                infoCard("Energy", energy.toStringAsFixed(2), "kWh"),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Realtime Graph",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: selectedMetric,
                  items: const [
                    DropdownMenuItem(value: "Power", child: Text("Power")),
                    DropdownMenuItem(value: "Voltage", child: Text("Voltage")),
                    DropdownMenuItem(value: "Current", child: Text("Current")),
                    DropdownMenuItem(value: "Energy", child: Text("Energy")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedMetric = value!;
                      chartData.clear();
                      xIndex = 0;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(child: buildChart()),

            const SizedBox(height: 10),

            Text(
              "Showing: $selectedMetric (${getUnit()})",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
