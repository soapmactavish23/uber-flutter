import 'package:flutter/material.dart';
import 'package:uber/telas/Cadastro.dart';
import 'package:uber/telas/Corrida.dart';
import 'package:uber/telas/Home.dart';
import 'package:uber/telas/PainelMotorista.dart';
import 'package:uber/telas/PainelPassageiro.dart';

class Rotas {
  static Route<dynamic> gerarRotas(RouteSettings settings) {

    final args = settings.arguments;

    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => Home());
        break;
      case "/cadastro":
        return MaterialPageRoute(builder: (_) => Cadastro());
        break;
      case "/painel-passageiro":
        return MaterialPageRoute(builder: (_) => PainelPassageiro());
        break;
      case "/painel-motorista":
        return MaterialPageRoute(builder: (_) => PainelMotorista());
        break;
      case "/corrida":
        return MaterialPageRoute(builder: (_) => Corrida(args));
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
