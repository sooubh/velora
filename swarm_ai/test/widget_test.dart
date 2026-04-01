import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:swarm_ai/shared/widgets/agent_card.dart';

void main() {
  testWidgets('agent card renders title and message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentCard(
            agentName: 'Orchestrator',
            emoji: '🎯',
            status: AgentRunStatus.running,
            message: 'Breaking down your query',
          ),
        ),
      ),
    );

    expect(find.text('Orchestrator'), findsOneWidget);
    expect(find.text('Breaking down your query'), findsOneWidget);
  });
}
