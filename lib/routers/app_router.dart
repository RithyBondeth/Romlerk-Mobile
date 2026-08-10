import 'package:auto_route/auto_route.dart';
import 'package:romlerk_mobile/features/navigation/inbox/presentation/pages/inbox_page.dart';
import 'package:romlerk_mobile/features/navigation/search/presentation/pages/search_page.dart';
import 'package:romlerk_mobile/features/navigation/today/presentation/today_page.dart';
import 'package:romlerk_mobile/features/navigation/upcoming/presentation/pages/upcoming_page.dart';
import 'package:romlerk_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:romlerk_mobile/features/setting/presentation/pages/setting_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    // Main Navigation
    AutoRoute(page: TodayRoute.page, path: '/today'),
    AutoRoute(page: UpComingRoute.page, path: '/upcoming'),
    AutoRoute(page: InboxRoute.page, path: '/inbox'),
    AutoRoute(page: SearchRoute.page, path: '/search'),

    // Sub Navigation
    AutoRoute(page: OnBoardingRoute.page, path: '/onboarding'),
    AutoRoute(page: SettingRoute.page, path: '/setting'),
  ];
}
