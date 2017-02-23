// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/plugin/protocol/protocol.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../integration_tests.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisErrorIntegrationTest);
    defineReflectiveTests(NoAnalysisErrorsIntegrationTest);
    defineReflectiveTests(NoAnalysisErrorsIntegrationTest_Driver);
  });
}

class AbstractAnalysisErrorIntegrationTest
    extends AbstractAnalysisServerIntegrationTest {
  test_detect_simple_error() {
    String pathname = sourcePath('test.dart');
    writeFile(
        pathname,
        '''
main() {
  print(null) // parse error: missing ';'
}''');
    standardAnalysisSetup();
    return analysisFinished.then((_) {
      expect(currentAnalysisErrors[pathname], isList);
      List<AnalysisError> errors = currentAnalysisErrors[pathname];
      expect(errors, hasLength(1));
      expect(errors[0].location.file, equals(pathname));
    });
  }

  test_super_mixins_disabled() async {
    String pathname = sourcePath('test.dart');
    writeFile(
        pathname,
        '''
class Test extends Object with C {
  void foo() {}
}
abstract class B {
  void foo() {}
}
abstract class C extends B {
  void bar() {
    super.foo();
  }
}
''');
    standardAnalysisSetup();
    await analysisFinished;
    expect(currentAnalysisErrors[pathname], isList);
    List<AnalysisError> errors = currentAnalysisErrors[pathname];
    expect(errors, hasLength(2));
    Set<String> allErrorMessages =
        errors.map((AnalysisError e) => e.message).toSet();
    expect(
        allErrorMessages,
        contains(
            "The class 'C' can't be used as a mixin because it extends a class other than Object."));
    expect(
        allErrorMessages,
        contains(
            "The class 'C' can't be used as a mixin because it references 'super'."));
  }

  test_super_mixins_enabled() async {
    String pathname = sourcePath('test.dart');
    writeFile(
        pathname,
        '''
class Test extends Object with C {
  void foo() {}
}
abstract class B {
  void foo() {}
}
abstract class C extends B {
  void bar() {
    super.foo();
  }
}
''');
    await sendAnalysisUpdateOptions(
        new AnalysisOptions()..enableSuperMixins = true);
    standardAnalysisSetup();
    await analysisFinished;
    expect(currentAnalysisErrors[pathname], isList);
    List<AnalysisError> errors = currentAnalysisErrors[pathname];
    expect(errors, isEmpty);
  }
}

@reflectiveTest
class AnalysisErrorIntegrationTest
    extends AbstractAnalysisErrorIntegrationTest {}

@reflectiveTest
class NoAnalysisErrorsIntegrationTest
    extends AbstractAnalysisServerIntegrationTest {
  @override
  Future startServer(
          {bool checked: true, int diagnosticPort, int servicesPort}) =>
      server.start(
          checked: checked,
          diagnosticPort: diagnosticPort,
          enableNewAnalysisDriver: enableNewAnalysisDriver,
          noErrorNotification: true,
          servicesPort: servicesPort);

  test_detect_simple_error() {
    String pathname = sourcePath('test.dart');
    writeFile(
        pathname,
        '''
main() {
  print(null) // parse error: missing ';'
}''');
    standardAnalysisSetup();
    return analysisFinished.then((_) {
      expect(currentAnalysisErrors[pathname], isNull);
    });
  }
}

@reflectiveTest
class NoAnalysisErrorsIntegrationTest_Driver
    extends NoAnalysisErrorsIntegrationTest {
  @override
  bool get enableNewAnalysisDriver => true;

  @failingTest
  @override
  test_detect_simple_error() {
    // Errors are reported with noErrorNotification: true (#28869).
    return super.test_detect_simple_error();
  }
}
