import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bago_system/app/app.dart';

void main() {
  test('all registered named routes create a Material route', () {
    final routes = <RouteSettings>[
      const RouteSettings(name: AppRoutes.login),
      const RouteSettings(name: AppRoutes.register),
      const RouteSettings(name: AppRoutes.residentDashboard),
      const RouteSettings(name: AppRoutes.officialDashboard),
      const RouteSettings(name: AppRoutes.profile),
      const RouteSettings(name: AppRoutes.notifications),
      const RouteSettings(name: AppRoutes.requestDocuments),
      const RouteSettings(name: AppRoutes.myDocumentRequests),
      const RouteSettings(name: AppRoutes.pendingRequests),
      const RouteSettings(name: AppRoutes.manageDocumentTypes),
      const RouteSettings(name: AppRoutes.announcements),
      const RouteSettings(name: AppRoutes.postAnnouncement),
      const RouteSettings(name: AppRoutes.fileComplaint),
      const RouteSettings(name: AppRoutes.viewComplaintsAdmin),
      const RouteSettings(name: AppRoutes.emergencyContacts),
      const RouteSettings(name: AppRoutes.manageHotlines),
      const RouteSettings(name: AppRoutes.viewHotlines),
      const RouteSettings(name: AppRoutes.transparency),
      const RouteSettings(name: AppRoutes.residentsDirectory),
      const RouteSettings(name: AppRoutes.statistics),
      const RouteSettings(name: AppRoutes.approvalPanel, arguments: 'Barangay San Isidro'),
      const RouteSettings(name: AppRoutes.announcementDetail, arguments: 'announcement-42'),
      const RouteSettings(name: AppRoutes.addEditHotline, arguments: 'hotline-17'),
      RouteSettings(
        name: AppRoutes.documentViewer,
        arguments: DocumentViewerArgs(
          title: 'Transparency Report',
          fileBytes: Uint8List.fromList(const [37, 80, 68, 70]),
          fileType: 'pdf',
        ),
      ),
    ];

    for (final settings in routes) {
      expect(AppRouter.onGenerateRoute(settings), isA<MaterialPageRoute<dynamic>>());
    }
  });
}
