import 'package:flutter/material.dart';
import '../services/automation_service.dart';

class AutomationRulesScreen extends StatefulWidget {
  const AutomationRulesScreen({super.key});

  @override
  State<AutomationRulesScreen> createState() => _AutomationRulesScreenState();
}

class _AutomationRulesScreenState extends State<AutomationRulesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    await AutomationService.instance.initialize();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final rules = AutomationService.instance.rules;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Automation Rules'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueAccent.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Automation rules run automatically in the background after you create a PDF or scan a document, saving you time without extra clicks!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Card(
                  color: const Color(0xFF1A1A1A),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: SwitchListTile(
                    title: Text(rule.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Trigger: ${rule.trigger.name}\nActions: ${rule.actions.map((a) => a.name).join(", ")}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    value: rule.isEnabled,
                    onChanged: (val) async {
                      await AutomationService.instance.toggleRule(rule.id);
                      setState(() {}); // Refresh UI
                    },
                    activeThumbImage: null, // Keep UI clean
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future expansion: Create custom automation rule
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom rule creation coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
