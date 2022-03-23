import 'package:open_gate/pages/pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments ;
    print("route: ${settings.name}");


    switch (settings.name) {
      case '/devices':
        return MaterialPageRoute(builder: (_) => DevicesPage(title: "Portones",));
      case '/search_devices':
        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 1000),
          pageBuilder: (context, animation, secondaryAnimation) => const SearchDevicesPage(title: "Buscar Portones",),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.bounceOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
                position: animation.drive(tween),
                child: child,
            );
          },
        );

      case '/choose_wifi':
        Map<String, dynamic> map = args as Map<String, dynamic>;
        print(map);
        bool create = true;

        if (map['create'] != null) {
          create = map['create'];
        }
        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) => ChooseWifiPage(create: create),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.ease;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      case "/device_configuration": 
        Map<String, dynamic> map = args as Map<String, dynamic>;
        print(map);
        bool create = true;
        if (map['create'] != null) {
          create = map['create'];
        }
        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => DeviceSettingsPage(create:create),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      case "/device":
        Map<String, dynamic> map = args as Map<String, dynamic>;
        print(map);



        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => DevicePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      case "/update_device":
        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => UpdateDevicePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      case "/edit_device":

        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => EditDevicePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      case '/settings':
        return PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 1000),
          pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(title: "Configuracion"),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, -1.0);
            const end =  Offset(0.0, 0.0);
            const curve = Curves.bounceOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );


      default:
        return MaterialPageRoute(builder: (_) => DevicesPage(title: "Portones",));
    }
  }
}
