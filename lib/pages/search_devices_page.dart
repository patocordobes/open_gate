import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:open_gate/models/models.dart';
import 'package:open_gate/pages/pages.dart';
import 'package:open_gate/repository/models_repository.dart';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:wifi_configuration_2/wifi_configuration_2.dart';
import 'package:system_settings/system_settings.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


class SearchDevicesPage extends StatefulWidget {
  const SearchDevicesPage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<SearchDevicesPage> createState() => _SearchDevicesPageState();
}
class _SearchDevicesPageState extends State<SearchDevicesPage> with WidgetsBindingObserver {
  ModelsRepository modelsRepository = ModelsRepository();
  bool _isInForeground = true;
  bool loading = false;
  late Timer timerRedirect;
  late DeviceManager deviceManager;
  late WifiConfiguration wifiConfiguration;


  @override
  void initState() {
    deviceManager = context.read<DeviceManager>();
    timerRedirect = Timer.periodic(Duration(milliseconds:1), (timer) {});
    refresh();
    WidgetsBinding.instance!.addObserver(this);

    super.initState();
  }

  @override
  void setState(fn) {
    if(mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    timerRedirect.cancel();

    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isInForeground = state == AppLifecycleState.resumed;
    });
    print("is resumed $_isInForeground");
    if (_isInForeground) {
      deviceManager.updateNewDeviceConnection();
    }
  }

  void refresh() async {
    await Future.delayed(Duration(seconds:1),);

    wifiConfiguration = WifiConfiguration();
    deviceManager.udpReceiver.close();
    deviceManager.update(updateWifi: true);
    deviceManager.status = ManagerStatus.updating ;
    deviceManager.notifyListeners();
    wifiConfiguration.connectToWifi("", "", ""); //TODO descomennatar esto para la release

  }
  @override
  Widget build(BuildContext context) {
    deviceManager = context.watch<DeviceManager>();
    if (deviceManager.status == DeviceStatus.updating){
      loading = true;
    }else{
      loading = false;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          children: getDevicesScanned()
        ),
      )
    );
  }

  List<Widget> getDevicesScanned() {
    List<Widget> list = [];
    if (loading){
      list.add(LinearProgressIndicator());
    }
    list.add(
        ListTile(
            leading:(loading)? Container(child: CircularProgressIndicator(),height:16,width: 16,):Text(""),
            title: Text('Portones escaneados',style: TextStyle(color: Theme.of(context).primaryColor),)
        )
    );

    if (deviceManager.scannedDevices.isNotEmpty) {

      deviceManager.scannedDevices.forEach((device) {
        list.add(
          OpenContainer(
            openBuilder: (_, closeContainer) => ChooseWifiPage(create:true),
            tappable: false,
            closedColor: Theme.of(context).dialogBackgroundColor,
            closedBuilder: (_, openContainer) => SearchedDeviceWidget(device: device,onTap: () async {

              if (device.connectionStatus != ConnectionStatus.local) {
                deviceManager.selectNewDevice(device);
                bool connected = await wifiConfiguration.isConnectedToWifi("${deviceManager.newDevice.name}");
                if (connected){
                  deviceManager.updateNewDeviceConnection();
                  await Future.delayed(Duration(seconds: 3));
                  if (deviceManager.newDevice
                      .connectionStatus !=
                      ConnectionStatus.local) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                          'Si tienes los datos activados, tienes que desactivarlos.'),
                        action: SnackBarAction(
                          label: "Ir a desactivar datos",
                          onPressed: () {
                            SystemSettings.dataUsage();
                          },
                        ),
                      ),
                    );
                  }
                }else{
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Conectate a la red 'Gate_${device.mac.toUpperCase().substring(3)}'"),
                      action: SnackBarAction(
                        label:"Ir a redes",
                        onPressed: (){
                          SystemSettings.wifi();
                        },
                      ),
                    ),
                  );
                }
                timerRedirect.cancel();
                timerRedirect =
                Timer.periodic(Duration(milliseconds: 1), (timer) {
                  if (_isInForeground) {
                    if (deviceManager.newDevice.connectionStatus ==
                        ConnectionStatus.connecting) {
                      timerRedirect.cancel();
                      print("siuuu");

                      wifiConfiguration.isConnectedToWifi(
                          "${deviceManager.newDevice.name}").then((
                          connected) async {
                        if (connected) {
                          deviceManager.update(updateWifi: false);
                          deviceManager.updateDeviceConnection(
                              deviceManager.newDevice);
                          timerRedirect.cancel();
                          timerRedirect = Timer.periodic(
                              Duration(milliseconds: 1), (timer) {
                            if (mounted && deviceManager.newDevice
                                .connectionStatus ==
                                ConnectionStatus.local) {
                              print("siuuu");
                              timerRedirect.cancel();
                              openContainer();
                            }
                          });
                          Future.delayed(
                              Duration(milliseconds: 3000), () {
                            timerRedirect.cancel();
                          });
                        } else {
                          deviceManager.disconnectDevice(
                              deviceManager.newDevice);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(
                                'Debe seleccionar la red correcta.')),
                          );
                        }
                      });
                    } else {
                      print("noooooooooooooooo");
                    }
                  }
                });
              } else {
                openContainer();
              }

            },),
          ),
        );
      });
    }else{
      list.add(Text("No se encontraron Portones"));
    }
    list.add(Divider());
    list.add(
      TextButton.icon(
          label: Text("Escanear codigo QR"),
          icon: Icon(Icons.qr_code),
          onPressed: () async {
            var statusCamera = await Permission.camera.request();
            var statusStorage = await Permission.storage.request();
            if (statusStorage.isGranted && statusCamera.isGranted){
              String? cameraScanResult = await scanner.scan();

              Map<String, dynamic> map = jsonDecode(cameraScanResult!);
              try{
                Device device = Device.fromQRCode(map);
                modelsRepository.createDevice(device: device).then((value) {});
                Navigator.of(context).pop();
                showDialog(context: context, builder: (_) {


                  return AlertDialog(
                    title: Text("Porton '${device.name}' agregado exitosamente"),
                    content: SingleChildScrollView(
                      child: Text(
                          "Ahora ya puedes utilizar el porton que acabas de escanear"),
                    ),
                  );
                });

              }catch(e){
                showDialog(context: context, builder: (_) {


                  return AlertDialog(
                    title: Text("No se apodido agregar el porton"),
                    content: SingleChildScrollView(
                      child: Text(
                          "El codigo que has escaneado no es valido o la version de la app no corresponde con el codigo qr"),
                    ),
                  );
                });
              }
            }else{
              if (statusStorage.isPermanentlyDenied || statusCamera.isPermanentlyDenied){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: SingleChildScrollView(
                        child: Column(
                          children: [
                            Text('Debes permitir los dos permisos para poder scanear'),
                            Center(
                              child:OutlinedButton(
                                child: Text("Abrir permisos"),
                                onPressed: (){
                                  openAppSettings();
                                },
                              )
                            )
                          ],
                        ),
                      ),backgroundColor:Theme.of(context).errorColor),
                );
              }
            }

          }
      )
    );
    list.add(ListTile(
      leading: Icon(Icons.info_outline),
      subtitle: Text("Presiona un Porton para configurarlo\n"),
    ));

    list.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: (){
              SystemSettings.wifi();
            },
            icon: Icon(Icons.network_wifi),
            label: Text("Ir a redes"),
          ),
          OutlinedButton.icon(
            onPressed: (){
              Clipboard.setData(ClipboardData(text: "OpenGate1234"));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Contraseña copiada al portapapeles")));
            },
            icon: Icon(Icons.copy),
            label: Text("Password"),
          )
        ],
      )
    );
    list.add(
      ListTile(
          leading: Text("1."),

          title: Text("Conenctate a la red Gate_XX:XX:XX:XX:XX"),
          subtitle: Text("Contraseña: OpenGate1234, Si no es posible debe ser porque alguien la cambio (puedes cambiarla solo reseteando el dispositivo)")
      )
    );
    list.add(
      Divider()
    );
    list.add(
        ListTile(
          leading: Text("2."),
          title: Text("Ignora el mensaje que te aparece en las notificaciones 'Ingresar a esta red'"),
          subtitle: Text("Si lo apretas simplemente vuelve"),
        )
    );
    return list;
  }
}

class SearchedDeviceWidget extends StatelessWidget {
  SearchedDeviceWidget({required this.device, required this.onTap});
  final Device device;
  final void Function() onTap;
  @override
  Widget build(BuildContext context){
    return ListTile(
      leading: (device.softwareStatus == SoftwareStatus.outdated)? Icon(Icons.new_releases,size: 30):Icon(
        IconData(59653, fontFamily: 'signal_wifi'),size: 30,),
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

      onTap: onTap,
    );
  }
}