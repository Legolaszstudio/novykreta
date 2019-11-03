import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cipher2/cipher2.dart';
import 'package:novynotifier/marks_tab.dart';
import 'config.dart' as config;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity/connectivity.dart';

TextEditingController codeController =
    TextEditingController(text: "klik035046001");
TextEditingController userController = TextEditingController();
TextEditingController passController = TextEditingController();
var status = "No status";
var i = 0;
var agent = 'Kreta.Ellenorzo';
var response, token;
int markCount = 0;
bool gotToken;

void onLoad() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String passKey = config.passKey;
  String codeKey = config.codeKey;
  String userKey = config.userKey;
  String iv = config.iv;
  if (prefs.getString("code") != null) {
    String decryptedCode = await Cipher2.decryptAesCbc128Padding7(
        prefs.getString("code"), codeKey, iv);
    String decryptedUser = await Cipher2.decryptAesCbc128Padding7(
        prefs.getString("user"), userKey, iv);
    String decryptedPass = await Cipher2.decryptAesCbc128Padding7(
        prefs.getString("password"), passKey, iv);
    codeController.text = decryptedCode;
    userController.text = decryptedUser;
    passController.text = decryptedPass;
  }
}

void auth() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.none) {
    status = "No internet connection was detected";
  } else {
    var res = await http.get('https://www.e-szivacs.org/mirror/settings.json');
    if (res.statusCode != 200)
      throw Exception('get error: statusCode= ${res.statusCode}');
    //print(res.body);
    if (res.statusCode == 200) {
      var pJson = json.decode(res.body);
      agent = pJson['CurrentUserAgent'];
      print(agent);
    } else {
      print("Error geting agent");
    }
    String code = codeController.text;
    String user = userController.text;
    String pass = passController.text;
    if (code == "" || user == "" || pass == "") {
      status = "Missing Input";
    } else {
      var headers = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'User-Agent': '$agent',
      };

      var data =
          'institute_code=$code&userName=$user&password=$pass&grant_type=password&client_id=919e0c1c-76a2-4646-a2fb-7085bbbf3c56';
      try {
        response = await http.post('https://$code.e-kreta.hu/idp/api/v1/Token',
            headers: headers, body: data);
        //print(response.body);
        /*var url = 'https://novy.vip/api/login.php?code=$code&user=$user&pass=$pass';
    var response = await http.get(url);*/
        print(response.body);
        if (response.statusCode == 200) {
          var parsedJson = json.decode(response.body);
          //print('Response body: ${response.body}');
          status = parsedJson['token_type'];
          if (status == '' || status == null) {
            if (parsedJson["error_description"] == '' ||
                parsedJson["error_description"] == null) {
              status = "Invalid username/password";
            } else {
              status = parsedJson["error_description"];
            }
          } else {
            status = "OK";
            token = parsedJson["access_token"];
          }
          //print(status);
        } else if (response.statusCode == 401) {
          var parsedJson = json.decode(response.body);
          if (parsedJson["error_description"] == '' ||
              parsedJson["error_description"] == null) {
            status = "Invalid username/password";
          } else {
            status = parsedJson["error_description"];
          }
          //print('Response status: ${response.statusCode}');
        } else {
          status = 'post error: statusCode= ${response.statusCode}';
          throw Exception('post error: statusCode= ${response.statusCode}');
        }
      } on SocketException {
        status = "Invalid InstituteCode";
      }
    }
    if (status == "OK") {
      var headers = {
        'Authorization': 'Bearer $token',
        'User-Agent': '$agent',
      };

      var res = await http.get(
          'https://$code.e-kreta.hu/mapi/api/v1/Student?fromDate=null&toDate=null',
          headers: headers);
      if (res.statusCode != 200)
        throw Exception('get error: statusCode= ${res.statusCode}');
      if (res.statusCode == 200) {
        var dJson = json.decode(res.body);
        var eval = dJson["Evaluations"];
        eval.forEach((element) => markCount += 1);
      }
    }
  }
}

void save() async {
  //Variables
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  //Inputs
  String key = config.passKey;
  String codeKey = config.codeKey;
  String userKey = config.userKey;
  String code = codeController.text;
  String user = userController.text;
  String pass = passController.text;
  //Encryption
  String iv = config.iv;
  String nonce = await Cipher2
      .generateNonce(); // generate a nonce for gcm mode we use later
  if (status == "OK") {
    int count = markCount;
    String encryptedPass =
        await Cipher2.encryptAesCbc128Padding7(pass, key, iv);
    String encryptedUser =
        await Cipher2.encryptAesCbc128Padding7(user, userKey, iv);
    String encryptedCode =
        await Cipher2.encryptAesCbc128Padding7(code, codeKey, iv);
    //TODO: getCount variable
    prefs.setInt("count", count);

    prefs.setString("password", encryptedPass);
    prefs.setString("code", encryptedCode);
    prefs.setString("user", encryptedUser);
    //String decryptedString = await Cipher2.decryptAesCbc128Padding7(encryptedString, key, iv);
  }
  /*
  print("prefs:");
  print(prefs.getString("password"));
  print(prefs.getString("code"));
  print(prefs.getString("user"));
  */
}

class LoginPage extends StatefulWidget {
  static String tag = 'login-page';
  @override
  _LoginPageState createState() => new _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    onLoad();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Hero(
      tag: 'hero',
      child: CircleAvatar(
        backgroundColor: Colors.black,
        radius: 60.0,
        child: Image.asset('assets/home.png'),
      ),
    );

    final code = TextFormField(
      controller: codeController,
      keyboardType: TextInputType.text,
      autofocus: false,
      decoration: InputDecoration(
        hintText: 'InstituteCode',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
      ),
    );

    final user = TextFormField(
      controller: userController,
      keyboardType: TextInputType.text,
      autofocus: false,
      decoration: InputDecoration(
        hintText: 'Username',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
      ),
    );

    final password = TextFormField(
      controller: passController,
      autofocus: false,
      obscureText: true,
      decoration: InputDecoration(
        hintText: 'Password',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
      ),
    );

    final loginButton = Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: RaisedButton(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        onPressed: () {
          auth();
          /*
          Navigator.of(context).pushNamed(HomePage.tag);
          runApp(HomePage(post: fetchPost()));
          */
          new Timer(const Duration(seconds: 3), () => _ackAlert(context));
        },
        padding: EdgeInsets.all(12),
        color: Colors.lightBlueAccent,
        child: Text('Log In', style: TextStyle(color: Colors.white)),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(left: 24.0, right: 24.0),
          children: <Widget>[
            logo,
            SizedBox(height: 48.0),
            code,
            SizedBox(height: 8.0),
            user,
            SizedBox(height: 8.0),
            password,
            SizedBox(height: 24.0),
            loginButton,
          ],
        ),
      ),
    );
  }
}

Future<void> _ackAlert(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Status'),
        content: Text(status),
        actions: <Widget>[
          FlatButton(
            child: Text('Ok'),
            onPressed: () {
              Navigator.of(context).pop();
              if (status == "OK") {
                save();
                Navigator.pushNamed(context, MarksTab.tag);
              }
            },
          ),
        ],
      );
    },
  );
}
