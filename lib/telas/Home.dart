import 'package:flutter/material.dart';
import 'package:uber/model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  String _msgErro = "";
  bool _carregando = false;

  _validarCampos() {
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    if (email.isNotEmpty && email.contains("@")) {
      if (senha.length >= 6) {
        Usuario usuario = Usuario();
        usuario.email = email;
        usuario.senha = senha;

        _logarUsuario(usuario);
      } else {
        setState(() {
          _msgErro = "A senha deve conter mais de 6 caracteres.";
        });
      }
    } else {
      setState(() {
        _msgErro = "O E-mail deve conter '@'";
      });
    }
  }

  _redirecionaPainelPorTipoUsuario(String idUsuario) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot snapshot =
        await db.collection("usuarios").doc(idUsuario).get();

    Map<String, dynamic> dados = snapshot.data();
    String tipoUsuario = dados["tipoUsuario"];

    setState(() {
      _carregando = false;
    });

    switch (tipoUsuario) {
      case "motorista":
        Navigator.pushReplacementNamed(context, "/painel-motorista");
        break;
      case "passageiro":
        Navigator.pushReplacementNamed(context, "/painel-passageiro");
        break;
    }
  }

  _logarUsuario(Usuario usuario) {
    setState(() {
      _carregando = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;

    auth
        .signInWithEmailAndPassword(
            email: usuario.email, password: usuario.senha)
        .then((firebaseUser) {
      _redirecionaPainelPorTipoUsuario(firebaseUser.user.uid);
    }).catchError((error) {
      print("Erro: ${error}");
      setState(() {
        _msgErro =
            "Erro ao autenticar usuário, verifique e-mail e senha e tente novamente";
        _carregando = false;
      });
    });
  }

  _verificaUsuarioLogado() async{
    FirebaseAuth auth = FirebaseAuth.instance;
    User usuarioLogado = await auth.currentUser;
    if(usuarioLogado != null){
      String idUsuario = usuarioLogado.uid;
      _redirecionaPainelPorTipoUsuario(idUsuario);
    }
  }

  @override
  void initState() {
    super.initState();
    _verificaUsuarioLogado();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("imagens/fundo.png"), fit: BoxFit.cover)),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Image.asset(
                    "imagens/logo.png",
                    width: 200,
                    height: 150,
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "E-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6))),
                ),
                TextField(
                    controller: _controllerSenha,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    style: TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                        hintText: "Senha",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)))),
                Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                    onPressed: () {
                      _validarCampos();
                    },
                    child: Text(
                      "Entrar",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: Color(0xff1ebbd8),
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: GestureDetector(
                      child: Text(
                        "Não tem conta? cadastre-se!",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, "/cadastro");
                      },
                    ),
                  ),
                ),
                _carregando
                    ? Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                            backgroundColor: Colors.white,
                          ),
                        ),
                      )
                    : Container(),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _msgErro,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
