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

  test('Windows packaging uses the independent PortWeave identity', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    final mainCpp = File('windows/runner/main.cpp').readAsStringSync();
    final makeConfig =
        loadYaml(
              File('windows/packaging/exe/make_config.yaml').readAsStringSync(),
            )
            as YamlMap;
    final inno = File(
      'windows/packaging/exe/inno_setup.iss',
    ).readAsStringSync();

    expect(cmake, contains('project(PortWeave LANGUAGES CXX)'));
    expect(cmake, contains('set(BINARY_NAME "PortWeave")'));
    expect(rc, contains('VALUE "CompanyName", "io.github.minggle"'));
    expect(rc, contains('VALUE "FileDescription", "PortWeave"'));
    expect(rc, contains('VALUE "InternalName", "PortWeave"'));
    expect(rc, contains('VALUE "OriginalFilename", "PortWeave.exe"'));
    expect(rc, contains('VALUE "ProductName", "PortWeave"'));
    expect(mainCpp, contains('window.Create(L"PortWeave"'));

    final appId = makeConfig['app_id'] as String;
    expect(
      appId,
      matches(
        RegExp(
          r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(appId, isNot('728B3532-C74B-4870-9068-BE70FE12A3E6'));
    expect(makeConfig['app_name'], 'PortWeave');
    expect(makeConfig['display_name'], 'PortWeave');
    expect(makeConfig['executable_name'], 'PortWeave.exe');
    expect(makeConfig['publisher'], 'Minggle');
    expect(makeConfig['publisher_url'], 'https://github.com/Minggle/PortWeave');

    expect(inno, contains('PortWeave,FlClashCore,FlClashHelperService'));
    expect(inno, contains("Schemes := ['portweave'];"));
    expect(inno, contains(r'io.github.minggle\PortWeave'));
    expect(inno, isNot(contains(r'com.follow\clash')));
    expect(inno, isNot(contains("'flclash'")));
  });
}
