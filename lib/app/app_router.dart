part of 'app.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const residentDashboard = '/resident';
  static const officialDashboard = '/official';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const requestDocuments = '/documents/request';
  static const myDocumentRequests = '/documents/mine';
  static const pendingRequests = '/documents/pending';
  static const manageDocumentTypes = '/documents/types';
  static const documentViewer = '/documents/viewer';
  static const announcements = '/announcements';
  static const announcementDetail = '/announcements/detail';
  static const postAnnouncement = '/announcements/post';
  static const fileComplaint = '/complaints/file';
  static const viewComplaintsAdmin = '/complaints/admin';
  static const emergencyContacts = '/hotlines/emergency';
  static const manageHotlines = '/hotlines/manage';
  static const viewHotlines = '/hotlines/view';
  static const addEditHotline = '/hotlines/edit';
  static const transparency = '/transparency';
  static const approvalPanel = '/official/approval';
  static const residentsDirectory = '/official/residents';
  static const statistics = '/statistics';
}

class DocumentViewerArgs {
  const DocumentViewerArgs({
    required this.title,
    required this.fileBytes,
    required this.fileType,
  });

  final String title;
  final Uint8List fileBytes;
  final String fileType;
}

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return _route(settings, const LoginPage());
      case AppRoutes.register:
        return _route(settings, const RegisterPage());
      case AppRoutes.residentDashboard:
        return _route(settings, const ResidentDashboard());
      case AppRoutes.officialDashboard:
        return _route(settings, const OfficialDashboard());
      case AppRoutes.profile:
        return _route(settings, const ProfilePage());
      case AppRoutes.notifications:
        return _route(settings, const NotificationsPage());
      case AppRoutes.requestDocuments:
        return _route(settings, const RequestDocumentsPage());
      case AppRoutes.myDocumentRequests:
        return _route(settings, const MyDocumentRequestsPage());
      case AppRoutes.pendingRequests:
        return _route(settings, const PendingRequestsPage());
      case AppRoutes.manageDocumentTypes:
        return _route(settings, const ManageDocumentTypesPage());
      case AppRoutes.announcements:
        return _route(settings, const AnnouncementsPage());
      case AppRoutes.postAnnouncement:
        return _route(settings, const PostAnnouncementPage());
      case AppRoutes.fileComplaint:
        return _route(settings, const FileComplaintPage());
      case AppRoutes.viewComplaintsAdmin:
        return _route(settings, const ViewComplaintsAdminPage());
      case AppRoutes.emergencyContacts:
        return _route(settings, const EmergencyContactsPage());
      case AppRoutes.manageHotlines:
        return _route(settings, const ManageHotlinesPage());
      case AppRoutes.viewHotlines:
        return _route(settings, const ViewHotlinesPage());
      case AppRoutes.transparency:
        return _route(settings, const TransparencyPage());
      case AppRoutes.residentsDirectory:
        return _route(settings, const ResidentsDirectoryPage());
      case AppRoutes.statistics:
        return _route(settings, const StatisticsPage());
      case AppRoutes.approvalPanel:
        final barangay = settings.arguments as String? ?? '';
        return _route(settings, ApprovalPanelPage(officialBarangay: barangay));
      case AppRoutes.announcementDetail:
        final announcementId = settings.arguments as String? ?? '';
        return _route(settings, AnnouncementDetailPage(announcementId: announcementId));
      case AppRoutes.addEditHotline:
        return _route(settings, AddEditHotlinePage(hotlineId: settings.arguments as String?));
      case AppRoutes.documentViewer:
        final args = settings.arguments;
        if (args is DocumentViewerArgs) {
          return _route(
            settings,
            DocumentViewerPage(
              title: args.title,
              fileBytes: args.fileBytes,
              fileType: args.fileType,
            ),
          );
        }
        return _route(
          settings,
          const ErrorState(
            title: 'Document unavailable',
            message: 'Document route arguments are missing.',
          ),
        );
      default:
        return _route(
          settings,
          const ErrorState(
            title: 'Page not found',
            message: 'The requested screen is not registered.',
          ),
        );
    }
  }

  static Route<dynamic> _route(RouteSettings settings, Widget page) {
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
