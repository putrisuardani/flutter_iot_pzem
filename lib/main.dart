import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MqttPage(),
    );
  }
}

class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  WebSocketChannel? channel;
  StreamSubscription? subscription;

  double voltage = 0;
  double current = 0;
  double power = 0;
  double energy = 0;

  String selectedMetric = 'Power';
  String connectionStatus = 'Menghubungkan...';

  List<FlSpot> chartData = [];
  int xIndex = 0;

  // Sesuaikan dengan alamat komputer yang menjalankan Express.
  // Android Emulator: ws://10.0.2.2:3000
  // Flutter Web di komputer yang sama: ws://localhost:3000
  // HP fisik: ws://IP_KOMPUTER:3000
  static const String wsUrl = 'ws://192.168.25.182:3000';

  @override
  void initState() {
    super.initState();
    connectBackend();
  }

  void connectBackend() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      subscription = channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message.toString());

            if (decoded is! Map) return;

            final data = Map<String, dynamic>.from(decoded);

            final newVoltage = (data['voltage'] as num?)?.toDouble();
            final newCurrent = (data['current'] as num?)?.toDouble();
            final newPower = (data['power'] as num?)?.toDouble();
            final newEnergy = (data['energy'] as num?)?.toDouble();

            if (newVoltage == null ||
                newCurrent == null ||
                newPower == null ||
                newEnergy == null) {
              debugPrint('Format telemetry tidak valid: $data');
              return;
            }

            if (!mounted) return;

            setState(() {
              voltage = newVoltage;
              current = newCurrent;
              power = newPower;
              energy = newEnergy;

              chartData.add(FlSpot(xIndex.toDouble(), getSelectedValue()));

              xIndex++;

              if (chartData.length > 20) {
                chartData.removeAt(0);
              }

              connectionStatus = 'Terhubung';
            });
          } catch (e) {
            debugPrint('Gagal membaca data: $e');
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            connectionStatus = 'Koneksi bermasalah';
          });

          debugPrint('WebSocket error: $error');
        },
        onDone: () {
          if (!mounted) return;

          setState(() {
            connectionStatus = 'Koneksi terputus';
          });
        },
      );
    } catch (e) {
      connectionStatus = 'Gagal menghubungkan';
      debugPrint('Gagal membuat koneksi WebSocket: $e');
    }
  }

  double getSelectedValue() {
    switch (selectedMetric) {
      case 'Voltage':
        return voltage;
      case 'Current':
        return current;
      case 'Energy':
        return energy;
      default:
        return power;
    }
  }

  String getUnit() {
    switch (selectedMetric) {
      case 'Voltage':
        return 'V';
      case 'Current':
        return 'A';
      case 'Energy':
        return 'kWh';
      default:
        return 'W';
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
              '$value $unit',
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
    subscription?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PLTS Monitoring'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: connectionStatus == 'Terhubung'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(connectionStatus),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                childAspectRatio: 1.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  infoCard('Voltage', voltage.toStringAsFixed(1), 'V'),
                  infoCard('Current', current.toStringAsFixed(2), 'A'),
                  infoCard('Power', power.toStringAsFixed(1), 'W'),
                  infoCard('Energy', energy.toStringAsFixed(2), 'kWh'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Realtime Graph',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: selectedMetric,
                    items: const [
                      DropdownMenuItem(value: 'Power', child: Text('Power')),
                      DropdownMenuItem(
                        value: 'Voltage',
                        child: Text('Voltage'),
                      ),
                      DropdownMenuItem(
                        value: 'Current',
                        child: Text('Current'),
                      ),
                      DropdownMenuItem(value: 'Energy', child: Text('Energy')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        selectedMetric = value;
                        chartData.clear();
                        xIndex = 0;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 300, child: buildChart()),
              const SizedBox(height: 10),
              Text(
                'Showing: $selectedMetric (${getUnit()})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
