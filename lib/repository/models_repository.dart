import 'dart:async';
import 'package:open_gate/dao/device_dao.dart';
import 'package:open_gate/dao/user_dao.dart';
import 'package:open_gate/models/models.dart';


class ModelsRepository {
  final userDao = UserDao();
  final deviceDao = DeviceDao();

  Future<void> createUser({required User user}) async {
    // write token with the user to the database
    int result = await userDao.createUser(user);
    print("id $result created");
  }


  Future<User> get getUser async {
    Map<String, dynamic> map = await userDao.selectUser();
    User user = User.fromDatabaseJson(map);
    return user;
  }


  Future<void> createDevice({required Device device}) async {
    // write token with the user to the database
    int result = await deviceDao.createDevice(device);
    print("device $result created");
  }
  Future<void> updateDevice({required Device device}) async {
    // write token with the user to the database
    int result = await deviceDao.updateDevice(device);
    print(device.toDatabaseJson());
    print("device $result updated");
  }
  Future<void> deleteDevice({required Device device}) async {
    // write token with the user to the database
    int result = await deviceDao.deleteDevice(device);
    print(device.toDatabaseJson());
    print("device $result deleted");
  }

  Future<List<Device>> getDevices() async {
    List<Map<String, dynamic>> listMap = await deviceDao.selectDevices();
    List<Device> devices = [];
    listMap.forEach((device){
      devices.add(Device.fromDatabaseJson(device));
    });
    return devices;
  }
}
