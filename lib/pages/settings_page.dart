import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ModelsRepository modelsRepository = ModelsRepository();
  late User user;


  @override
  initState() {
    super.initState();
    modelsRepository.getUser.then((user) {
      setState(() {
        this.user = user;
      });

    });

  }
  @override
  void dispose() {

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool isscrolled){
            return <Widget>[
              SliverAppBar(
                  title: Text(widget.title),
                  pinned:false,
                  floating: true,
                  forceElevated: isscrolled,
              ),
            ];
          },
          body:Center(
            child: Column(
              children: [
                ListTile(
                  title: Text("Información de la aplicación"),
                  leading: Icon(Icons.info_outline),
                  onTap: (){
                    showDialog<void>(
                      context: context,

                      // false = user must tap button, true = tap outside dialog
                      builder: (BuildContext dialogContext) {
                        return AboutDialog();
                      },
                    );
                  },
                ),

              ],
            )
        ),
      ),
    );
  }
}