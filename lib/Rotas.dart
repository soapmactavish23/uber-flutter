import 'package:flutter/material.dart';
import 'package:uber/telas/Cadastro.dart';
import 'package:uber/telas/Home.dart';
import 'package:uber/telas/PainelMotorista.dart';
import 'package:uber/telas/PainelPassageiro.dart';

class Rotas {
  static Route<dynamic> gerarRotas(RouteSettings settings) {
    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => Home());
        break;
      case "/cadastro":
        return MaterialPageRoute(builder: (_) => Cadastro());
        break;
      case "/painelPassageiro":
        return MaterialPageRoute(builder: (_) => PainelPassageiro());
        break;
      case "/painelMotorista":
        return MaterialPageRoute(builder: (_) => PainelMotorista());
        break;
      default:
        _erroRota();
    }
  }

  static Route<dynamic> _erroRota(){
    return MaterialPageRoute(
      builder: (_){
        return Scaffold(
          appBar: AppBar(
            title: Text("Tela não encontrada"),
          ),
          body: Center(
            child: Text("Tela não encontrada!"),
          ),
        );
      }
    );
  }

}
