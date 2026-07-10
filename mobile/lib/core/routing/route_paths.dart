class RoutePaths {
  RoutePaths._();

  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const tickets = '/tickets';
  static const notifications = '/notifications';
  static const newTicket = '/tickets/new';

  static String ticketDetail(int id) => '/tickets/$id';
  static String comingSoon(String module) => '/coming-soon/$module';
}
