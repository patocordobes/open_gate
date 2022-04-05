import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';

import '../models/models.dart';

class StepTwoPage extends StatefulWidget{
  @override
  State<StepTwoPage> createState() => _StepTwoPageState();
}

class _StepTwoPageState extends State<StepTwoPage> {
  List<WifiNetwork> wifiNetworkList = [];
  bool loading = false;
  late WifiNetwork wifiNetworkSelected;
  late DeviceManager deviceManager;
  late Timer timerRedirect;

  @override
  void initState() {
    deviceManager = context.read<DeviceManager>();
    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {});
    getWifiList();
    super.initState();
  }
  void refresh(){
    getWifiList();
  }
  void dispose() {
    timerRedirect.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    deviceManager = context.watch<DeviceManager>();
    //getWifiList();
    return Scaffold(
        appBar: AppBar(
          title: Text("Paso 2"),
          actions: [
            IconButton(icon: Icon(Icons.settings), onPressed: (){
              Navigator.of(context).pushNamed("/settings");
            }),
            IconButton(icon: Icon(Icons.refresh), onPressed: (){
              refresh();
            }),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
              children: getList()
          ),
        )
    );
  }

  List<Widget> getList()  {
    List<Widget> list = [];
    if (loading){
      list.add(
        LinearProgressIndicator()
      );
    }
    list.add(
      ListTile(
          leading: Text("1."),
          title: Text("Selecciona la red a la que conectaste tu porton"),
          subtitle: Text("Si no aparece debes conectar tu porton a una que este cerca de tu celular")
      )
    );
    list.add(
      Divider()
    );
    if (wifiNetworkList.isNotEmpty) {

      /*wifiNetworkList.forEach((wifiNetwork) {

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

          },
        );
        list.add(listTile);
      });*/
      list.add(
          Column(
            children:
            wifiNetworkList.map((data) => RadioListTile(
              title: Text("${data.ssid}"),
              subtitle: Text("Mac: ${data.bssid}"),
              groupValue: wifiNetworkSelected,
              value: data,
              onChanged: (val) {
                setState(() {

                  wifiNetworkSelected = data;
                });
              },
            )).toList(),
          )
      );
      list.add(Divider());
      list.add(

          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: EdgeInsets.only(right: 16,left: 16),
              child: Row(
                children: [
                  Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Paso 2 de 3"),
                      )
                  ),
                  ElevatedButton(
                      child: Text(
                          "SIGUIENTE"
                      ),
                      onPressed: () async {
                        WifiConfiguration wifiConfiguration = WifiConfiguration();
                        bool connected = await wifiConfiguration.isConnectedToWifi("${wifiNetworkSelected.ssid}");
                        if (connected){
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bien estas conectado a la red ${wifiNetworkSelected.ssid}, Intentando conexion con el porton")));
                          deviceManager.newDevice.ssid = wifiNetworkSelected.ssid.toString();
                          deviceManager.newDevice.connectedToWiFi = true;
                          deviceManager.updateNewDeviceConnection();
                          deviceManager.updateDevicesConnection();
                          timerRedirect.cancel();
                          timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {
                            if (deviceManager.newDevice.connectionStatus == ConnectionStatus.local) {
                              print("siuuu");
                              timerRedirect.cancel();
                              Navigator.of(context).pushNamed("/change_name", arguments: {"create":true});
                            }else{

                              Future.delayed(Duration(milliseconds:4000),(){
                                timerRedirect.cancel();
                              });
                            }
                          });
                        }
                      }
                  ),
                ],
              ),
            ),
          )
      );

    }else{
      list.add(
          ListTile(
            leading: Text(""),
            title: Text('No se encontraron redes'),
          )
      );

    }


    return list;
  }
  Future getWifiList() async {
    setState(() {
      loading = true;
    });

    var wifiConfiguration = WifiConfiguration();

    List<WifiNetwork> list = await wifiConfiguration.getWifiList() as List<WifiNetwork>;
    List<WifiNetwork> wifiNetworkList = [];

    list.forEach((wifiNetwork) {
      if (wifiNetwork.ssid != "Gate_${wifiNetwork.bssid!.toUpperCase().substring(3)}") {
        wifiNetworkList.add(wifiNetwork);
      }
    });
    this.wifiNetworkList = wifiNetworkList;
    wifiNetworkSelected = wifiNetworkList[0];
    setState(() {
      loading = false;
    });
  }
}