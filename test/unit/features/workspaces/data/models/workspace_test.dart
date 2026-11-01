import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('Workspace.channelsLabel', () {
    Workspace workspace(int channels) => Workspace(
      id: 'org-1',
      name: 'Cybertron',
      avatar: '',
      channelsCount: channels,
    );

    test('uses the plural for zero and many channels', () {
      expect(workspace(0).channelsLabel, '0 channels');
      expect(workspace(5).channelsLabel, '5 channels');
    });

    test('uses the singular for one channel', () {
      expect(workspace(1).channelsLabel, '1 channel');
    });
  });
}
