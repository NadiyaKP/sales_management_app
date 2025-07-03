import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugPreferencesScreen extends StatefulWidget {
  const DebugPreferencesScreen({super.key});

  @override
  State<DebugPreferencesScreen> createState() => _DebugPreferencesScreenState();
}

class _DebugPreferencesScreenState extends State<DebugPreferencesScreen> {
  Map<String, dynamic> preferencesMap = {};

  @override
  void initState() {
    super.initState();
    loadSharedPreferences();
  }

  Future<void> loadSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    Map<String, dynamic> tempMap = {};
    for (String key in keys) {
      tempMap[key] = prefs.get(key);
    }

    setState(() {
      preferencesMap = tempMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Shared Preferences')),
      body: preferencesMap.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: preferencesMap.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text('${entry.value}'),
                );
              }).toList(),
            ),
    );
  }
}
