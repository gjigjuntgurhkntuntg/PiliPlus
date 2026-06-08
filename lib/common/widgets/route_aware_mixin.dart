import 'package:flutter/widgets.dart';
import 'package:get/get_navigation/src/routes/default_route.dart'
    show GetPageRoute;

final routeObserver = RouteObserver<GetPageRoute>();

mixin RouteAwareMixin<T extends StatefulWidget> on State<T>, RouteAware {
  GetPageRoute? _routeAwareRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is GetPageRoute && route != _routeAwareRoute) {
      if (_routeAwareRoute != null) {
        routeObserver.unsubscribe(this);
      }
      routeObserver.subscribe(this, route);
      _routeAwareRoute = route;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _routeAwareRoute = null;
    super.dispose();
  }
}
