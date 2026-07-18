class RoutePaths {
  RoutePaths._();

  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const complaints = '/complaints';
  static const parking = '/parking';
  static const visitors = '/visitors';
  static const notifications = '/notifications';

  // New Complaint has no route of its own — it opens as a modal popup from
  // wherever the circular "New Complaint" button lives (see AppShell).

  static String complaintDetail(int id) => '/complaints/$id';
  static String comingSoon(String module) => '/coming-soon/$module';
}
