import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Linux packaging teardown', () {
    for (final format in ['deb', 'rpm']) {
      test('$format removes the Helper unit only on a real uninstall', () {
        final config =
            loadYaml(
                  File(
                    'linux/packaging/$format/make_config.yaml',
                  ).readAsStringSync(),
                )
                as YamlMap;
        final scripts = (config['postuninstall_scripts'] as YamlList)
            .cast<String>();

        expect(scripts.first, contains('exit 0'));
        expect(
          scripts,
          contains('rm -f /etc/systemd/system/flclash-helper.service'),
        );
        expect(
          scripts.any((script) => script.contains('systemctl daemon-reload')),
          isTrue,
        );
      });
    }
  });

  test('every Linux package names the GTK application id as its window '
      'class', () {
    final applicationId = RegExp(
      r'set\(APPLICATION_ID "([^"]+)"\)',
    ).firstMatch(File('linux/CMakeLists.txt').readAsStringSync())!.group(1);

    for (final format in ['deb', 'rpm', 'appimage']) {
      final config =
          loadYaml(
                File(
                  'linux/packaging/$format/make_config.yaml',
                ).readAsStringSync(),
              )
              as YamlMap;
      expect(config['startup_wm_class'], applicationId, reason: format);
    }
  });

  test('rpm keeps the Core bytes the Helper was built against', () {
    final config =
        loadYaml(
              File('linux/packaging/rpm/make_config.yaml').readAsStringSync(),
            )
            as YamlMap;
    final macros = (config['spec_macros'] as YamlList).cast<String>();

    expect(macros, contains('%global debug_package %{nil}'));
    expect(macros, contains('%global __os_install_post %{nil}'));
  });

  test('macOS packaging uses the independent PortWeave identity', () {
    final appInfo = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final dmg =
        loadYaml(
              File('macos/packaging/dmg/make_config.yaml').readAsStringSync(),
            )
            as YamlMap;
    final packageScript = File('tool/package_macos.sh').readAsStringSync();
    final plist = File('macos/Runner/Info.plist').readAsStringSync();

    expect(appInfo, contains('PRODUCT_NAME = PortWeave'));
    expect(
      appInfo,
      contains('PRODUCT_BUNDLE_IDENTIFIER = io.github.minggle.portweave'),
    );
    expect(dmg['title'], 'PortWeave');
    expect(dmg['contents'].toString(), contains('PortWeave.app'));
    expect(packageScript, contains('PortWeave.app'));
    expect(packageScript, contains('io.github.minggle.portweave'));
    expect(plist, contains('<string>portweave</string>'));
    expect(plist, isNot(contains('<string>flclash</string>')));
    expect(plist, isNot(contains('<string>clash</string>')));
    expect(plist, isNot(contains('<string>clashmeta</string>')));
  });
}
