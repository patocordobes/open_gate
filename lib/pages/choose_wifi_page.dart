import 'dart:async';
import 'dart:convert';
import 'package:open_gate/manager/device_manager.dart';
import 'package:open_gate/models/models.dart';
import 'package:open_gate/repository/models_repository.dart';
import 'package:flutter/material.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';
import 'package:udp/udp.dart';
import 'package:provider/provider.dart';

class ChooseWifiPage extends StatefulWidget {
  const ChooseWifiPage({Key? key, this.create = true}) : super(key: key);
  final bool create;

  @override
  State<ChooseWifiPage> createState() => _ChooseWifiPageState();
}

class _ChooseWifiPageState extends State<ChooseWifiPage> {
  bool isLoaded = false;
  bool connectingToWiFi = false;
  late Device device;
  late DeviceManager deviceManager;
  late Timer timerGetting;
  late Timer timerRedirect ;
  bool scanButton = true;
  ModelsRepository modelsRepository = ModelsRepository();

  void initTimer(){
    timerGetting = Timer.periodic(Duration(seconds:2), (timer) {
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        if (device.connectionStatus == ConnectionStatus.local ) {
          device.deviceStatus = DeviceStatus.updating;
          device.wifiStatus = WifiStatus.getting;
          Map <String, dynamic> map = {
            "t": "devices/" + device.mac.toUpperCase().substring(3),
            "a": "getcw",
          };
          deviceManager.send(jsonEncode(map), true);
          map = {
            "t": "devices/" + device.mac.toUpperCase().substring(3),
            "a": "gettype",
          };
          deviceManager.send(jsonEncode(map), true);
          //timerGetting.cancel();
        }
      }
    });
  }
  @override
  void initState() {
    super.initState();
    deviceManager = context.read<DeviceManager>();
    if (widget.create){
      device = deviceManager.newDevice;
    }else {
      device = deviceManager.selectedDevice;
    }

    initTimer();
    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) async  {
      if (device.connectionStatus != ConnectionStatus.disconnected) {
        if (device.connectionStatus != ConnectionStatus.local && device.connectionStatus != ConnectionStatus.updating) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Solo puedes editar la red del porton localmente'),backgroundColor:Theme.of(context).errorColor),
          );
          Navigator.of(context).pop();
        }
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Se há perdido la coñexión con el porton!!!.'),backgroundColor:Theme.of(context).errorColor),
        );
        Navigator.of(context).pop();
      }
    });

  }
  @override
  void setState(fn) {
    if(mounted) {
      super.setState(fn);
    }
  }
  @override
  void dispose() {
    timerRedirect.cancel();
    timerGetting.cancel();
    super.dispose();
  }
  void refresh() async {
    timerGetting.cancel();
    initTimer();
  }
  @override
  Widget build(BuildContext context) {
    deviceManager = context.watch<DeviceManager>();
    if (widget.create){
      device = deviceManager.newDevice;
    }else {
      device = deviceManager.selectedDevice;
    }
    if(device.deviceStatus == DeviceStatus.updating) {
      isLoaded = false;
    }else{
      isLoaded = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Red del porton '),
        actions: [
          IconButton(icon: Icon(Icons.settings), onPressed: (){
            Navigator.of(context).pushNamed("/settings");
          }),
          IconButton(icon: Icon(Icons.refresh), onPressed: (){
            refresh();
          })
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
            children: getList()
        ),
      )
    );
  }
  List<Widget> getList(){
    List<Widget> list = [];
    list.add(
      Container(
        color:Theme.of(context).primaryColor,
        child: ListTile(
          leading: Icon(
            IconData(59653, fontFamily: 'signal_wifi'), size: 30,),
          title: Text('${device.name}'),
          subtitle: Text(
              (device.connectionStatus == ConnectionStatus.connecting)
                  ? "Conectando..."
                  : (device.connectionStatus ==
                  ConnectionStatus.disconnected)
                  ? "Desconectado"
                  : (device.connectionStatus == ConnectionStatus.local)
                  ? "Conectado localmente"
                  : (device.connectionStatus == ConnectionStatus.updating)?"Sincronizando...":"Conectado a traves del servidor"),
        )
      ),
    );

    if (device.deviceStatus == DeviceStatus.updating){
      list.add(LinearProgressIndicator());
    }
    list.add(
        ListTile(
          leading: (device.wifiStatus == WifiStatus.getting || device.wifiStatus == WifiStatus.connecting)?Container(child: CircularProgressIndicator(),height:16,width: 16,):Text(""),
          title: Text('Red conectada actualmente',style: TextStyle(color: Theme.of(context).primaryColor),),
        )
    );

    if (device.connectedToWiFi && device.currentWifiNetwork != null){
      list.add(
          ListTile(
            leading: Icon(IconData(59648 + (int.parse(device.currentWifiNetwork!.signalLevel!)), fontFamily: 'signal_wifi'),size: 30,),
            title: Text('${device.currentWifiNetwork!.ssid!}'),
            subtitle: Text('Conectada'),
            trailing: IconButton(icon: Icon(Icons.settings,color: Theme.of(context).accentColor,),onPressed: ()async {
              bool? result = await showDialog(context: context, builder: (_){
                return AlertDialog(
                  title: Text("¿Olvidar esta red?"),
                  content: Text("Una vez olvida la red tendra que reconectarse nuevamente"),
                  actions: [
                    TextButton(
                      child:Text("CANCELAR"),
                      onPressed: (){
                        Navigator.of(context).pop(false);
                      },
                    ),
                    TextButton(
                      child:Text("OLVIDAR ESTA RED"),
                      onPressed: (){
                        Navigator.of(context).pop(true);

                      },
                    )
                  ],

                );
              });
              if (result != null){
                if (result){
                  disconnectWiFi();
                  refresh();
                }
              }
            }),
          )
      );
    }else{
      list.add(
          ListTile(
            leading: Icon(Icons.signal_wifi_off),
            title: Text('Red desconectada'),
            subtitle: Text('Desconectada'),
          )
      );
    }
    list.add(Divider());

    list.add(
        ListTile(
          trailing: OutlinedButton.icon(
            icon: Icon(Icons.refresh,size:16),
            onPressed: scanButton? (){
              if (device.connectionStatus != ConnectionStatus.disconnected) {
                if (device.connectionStatus == ConnectionStatus.local ) {
                  setState(() {
                    scanButton = false;
                  });

                  device.deviceStatus = DeviceStatus.updating;
                  device.wifiStatus = WifiStatus.scanning;
                  Map <String, dynamic> map = {
                    "t": "devices/" + device.mac.toUpperCase().substring(3),
                    "a": "getw",
                  };
                  deviceManager.send(jsonEncode(map), true);
                  timerGetting.cancel();
                  Future.delayed(Duration(seconds: 4), (){
                    setState(() {
                      scanButton = true;
                    });
                    initTimer();
                  });

                }
              }
            } : null,
            label: Text("Escanear"),

          ),
          leading: (device.wifiStatus == WifiStatus.scanning)?Container(child: CircularProgressIndicator(),height:16,width: 16,):Text(""),
          title: Text('Redes que ve el porton',style: TextStyle(color: Theme.of(context).primaryColor),),
        )
    );

    if (device.wifiNetworkList.isNotEmpty) {
      device.wifiNetworkList.forEach((wifiNetwork) {
        if (device.ssid != wifiNetwork.ssid || device.wifiStatus == WifiStatus.disconnected) {
          int signal = 59648 +
              (int.parse(wifiNetwork.signalLevel!));
          ListTile listTile = ListTile(
            leading: Icon(
              IconData(signal, fontFamily: 'signal_wifi'), size: 30,),
            title: Text('${wifiNetwork.ssid!}'),
            trailing: (wifiNetwork.security != "")
                ? Icon(Icons.lock, size: 16)
                : Text(""),
            selected: false,
            onTap: () async {
              String? password = await showDialog(context: context,
                  builder: (builder) =>
                      EnterPasswordDialog(title: wifiNetwork.ssid!));
              if (password != null) {
                connectToWiFi(wifiNetwork, password);
              }
            },
          );
          list.add(listTile);
        }
      });

    }else{
      list.add(
          ListTile(
            leading: Text(""),
            title: Text('No se encontraron redes'),
          )
      );
    }
    list.add(Divider());
    list.add(getButtons());
    return list;
  }
  Widget getButtons() {
    if (widget.create) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: EdgeInsets.only(right: 16,left: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Paso 1 de 2"),
                )
              ),
              OutlinedButton(
                  child: Text(
                      "NO CONECTAR"
                  ),
                  onPressed: (device.wifiStatus == WifiStatus.connected || device.wifiStatus == WifiStatus.disconnected)?  () async {
                    device.connectedToWiFi = false;
                    device.ssid = "";


                    Map map = {
                      "t": "devices/" + device.mac.toUpperCase().substring(3),
                      "a": "get",
                    };

                    deviceManager.send(jsonEncode(map), true);
                    await Future.delayed(Duration(milliseconds: 1000));
                    Navigator.of(context).pushNamed("/change_name",
                        arguments: {
                          "create": true
                        });
                  } : null
              ),
              ElevatedButton(
                  child: Text(
                      "SIGUIENTE"
                  ),
                  onPressed: (device.wifiStatus != WifiStatus.connected || device.deviceStatus == DeviceStatus.updating)? null : () async {
                    device.ssid = device.currentWifiNetwork!.ssid!;

                    device.deviceStatus = DeviceStatus.updating;
                    Map map = {
                      "t": "devices/" + device.mac.toUpperCase().substring(3),
                      "a": "get",
                    };
                    deviceManager.send(jsonEncode(map), true);
                    timerRedirect.cancel();
                    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
                      if (device.deviceStatus == DeviceStatus.updated){
                        timerRedirect.cancel();
                        Navigator.of(context).pushNamed("/change_name",
                            arguments: {
                              "create": true
                            });
                      }
                    });
                    await Future.delayed(Duration(milliseconds: 3000),(){
                      timerRedirect.cancel();
                    });

                  }
              ),
            ],
          ),
        ),

      );
    }else{
      return Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: EdgeInsets.only(right: 16),
          child: ElevatedButton(
            child: Text(
                "LISTO"
            ),
            onPressed: () {
              Navigator.of(context).pop();
            }
          ),
        ),
      );
    }
  }

  Widget backdropFilter( Widget child) {
    if (isLoaded && !connectingToWiFi){
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
        )
      ],
    );
  }

  Future<void> connectToWiFi(WifiNetwork network, String password) async {
    device.deviceStatus = DeviceStatus.updating;
    device.wifiStatus = WifiStatus.connecting;
    device.connectionStatus = ConnectionStatus.updating;
    Map <String, dynamic> map = {
      "t":"devices/" + device.mac.toUpperCase().substring(3),
      "a":"connectwifi",
      "d":{
        "ssid":"${network.ssid.toString()}",
        "pass": password
      }
    };
    deviceManager.send(jsonEncode(map), true);
  }

  Future<void> disconnectWiFi() async {
    Map <String, dynamic> map = {
      "t":"devices/" + device.mac.toUpperCase().substring(3),
      "a":"disconnectw"
    };
    deviceManager.send(jsonEncode(map), true);
  }
}

class EnterPasswordDialog extends StatefulWidget{
  EnterPasswordDialog({required this.title});
  final String title;
  @override
  _EnterPasswordDialogState createState() => _EnterPasswordDialogState();
}

class _EnterPasswordDialogState extends State<EnterPasswordDialog> {
  TextEditingController _textFieldController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = false;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              //not sure if i need this
              
              controller: _textFieldController,
              decoration: InputDecoration(hintText: 'Contraseña'),
              maxLength: 20,
              obscureText: !_obscureText,
              validator: (value) {
                if (value == null) {
                  return 'Ingresa una contrasña ';
                }
                if (value.isEmpty) {
                  return ' Ingresa una contrasña';
                }
                return null;
              },
              onSaved: (value) {
              },
            ),
            GestureDetector(
              onTap: (){
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
              child: Row(
                children: [
                  Checkbox(value: _obscureText, onChanged: (value){
                    setState(() {
                      _obscureText = value!;
                    });

                  }),
                  Text("Mostrar contraseña")

              ],),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('CANCELAR'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        //this needs to validate if the typed value was the same as the
        //hardcoded password, it would run the _getImage() function
        //the same as the validator in the TextFormField
        TextButton(
          child: Text('CONECTAR'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              print("intentando");
              Navigator.of(context).pop(_textFieldController.text);
            }
            
          },
        ),
      ],
    );
  }
}
