import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:open_gate/routes/route_generator.dart';
import 'package:open_gate/themes/themes.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeviceManager()),

          ],
          child: MyApp(),
        )
    );
  //WidgetsFlutterBinding.ensureInitialized();
  //SystemChrome.setPreferredOrientations(
 //     [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);


  ModelsRepository modelsRepository = ModelsRepository();
  try {
    await modelsRepository.getUser;
  }catch (e){
    modelsRepository.createUser(user: User());
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyApp createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Open Gate',
      theme: CustomTheme.lightTheme,
      highContrastTheme: CustomTheme.lightTheme,
      darkTheme: CustomTheme.darkTheme,
      onGenerateRoute: RouteGenerator.generateRoute,

    );
  }


}