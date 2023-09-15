import 'dart:io';

import 'package:fvm/exceptions.dart';
import 'package:fvm/fvm.dart';
import 'package:fvm/src/utils/helpers.dart';
import 'package:fvm/src/utils/which.dart';
import 'package:fvm/src/workflows/update_project_version.workflow.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_semver/pub_semver.dart';

import '../utils/logger.dart';

/// Checks if version is installed, and installs or exits
Future<void> useVersionWorkflow({
  required CacheFlutterVersion version,
  required Project project,
  bool force = false,
  String? flavor,
}) async {
  // If project use check that is Flutter project
  if (!project.isFlutter && !force) {
    final proceed = logger.confirm(
      'You are running "use" on a project that does not use Flutter. Would you like to continue?',
    );

    if (!proceed) exit(ExitCode.success.code);
  }

  // Checks if the project constraints are met
  checkProjectVersionCOnstraints(project, version);

  // Run install workflow
  updateSdkVersionWorkflow(
    project,
    version.name,
    flavor: flavor,
  );

  final versionLabel = cyan.wrap(version.printFriendlyName);
  // Different message if configured environment
  if (flavor != null) {
    logger.complete(
      'Project now uses Flutter SDK: $versionLabel on [$flavor] flavor.',
    );
  } else {
    logger.complete(
      'Project now uses Flutter SDK : $versionLabel',
    );
  }

  if (version.flutterExec == which('flutter')) {
    logger.detail('Flutter SDK is already in your PATH');
    return;
  }

  if (isVsCode()) {
    logger
      ..spacer
      ..notice(
        'Running on VsCode, please restart the terminal to apply changes.',
      )
      ..info('You can then use "flutter" command within the VsCode terminal.');
  }

  return;
}

void checkProjectVersionCOnstraints(
  Project project,
  CacheFlutterVersion version,
) {
  // Checks if the project constraints are met
  final flutterSdkVersion = version.flutterSdkVersion;

  if (flutterSdkVersion != null) {
    final allowedInConstraint = project.sdkConstraint?.allows(
          Version.parse(flutterSdkVersion),
        ) ??
        true;

    final releaseMessage =
        'Flutter SDK: ${version.name} does not meet your project constraints. ';

    final notReleaseMessage =
        'Flutter SDK: ${version.name} $flutterSdkVersion is not allowed in your project constraints. ';

    final message = version.isRelease ? releaseMessage : notReleaseMessage;

    if (!allowedInConstraint) {
      logger.notice(message);
      final confirm = logger.confirm(
        'Would you like to continue?',
      );

      if (!confirm) {
        throw AppException(
          'Version $flutterSdkVersion not allowed, in project constraints',
        );
      }
    }
  }
}
