import 'package:bgm_app/widgets/common/content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KeepAliveSection preserves state outside the list viewport', (
    tester,
  ) async {
    var initCount = 0;
    var disposeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView(
            children: [
              KeepAliveSection(
                child: SizedBox(
                  height: 120,
                  child: _LifecycleProbe(
                    onInit: () => initCount++,
                    onDispose: () => disposeCount++,
                  ),
                ),
              ),
              for (var index = 0; index < 30; index++)
                const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );

    expect(initCount, 1);
    expect(disposeCount, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(disposeCount, 0);

    await tester.drag(find.byType(ListView), const Offset(0, 1600));
    await tester.pumpAndSettle();
    expect(initCount, 1);
    expect(disposeCount, 0);
  });
}

class _LifecycleProbe extends StatefulWidget {
  final VoidCallback onInit;
  final VoidCallback onDispose;

  const _LifecycleProbe({required this.onInit, required this.onDispose});

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
