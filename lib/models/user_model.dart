import 'package:flutter/widgets.dart';

class User with ChangeNotifier {
  int id;


  User(
      {
        this.id = 0,
      }
      );
  factory User.fromDatabaseJson(Map<String, dynamic> data) => User(
    id: data['id'],

  );
  Map<String, dynamic> toDatabaseJson() => {
    "id": this.id,
  };

}
