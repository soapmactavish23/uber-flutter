import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/util/StatusRequisicao.dart';

class PainelMotorista extends StatefulWidget {
  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {
  List<String> itensMenu = ["Configurações", "Deslogar"];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore _db = FirebaseFirestore.instance;

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  Stream<QuerySnapshot> _adicionarListenerRequisicoes() {
    final stream = _db
        .collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();

    stream.listen((dados) {
      _controller.add(dados);
    });
  }

  @override
  void initState() {
    super.initState();

    //adicionar listener para recuperar requisições
    _adicionarListenerRequisicoes();
  }

  @override
  Widget build(BuildContext context) {
    var mensagemCarregando = Center(
      child: Column(
        children: <Widget>[
          Text("Carregando Requisições"),
          CircularProgressIndicator()
        ],
      ),
    );

    var mensagemNaoTemDados = Center(
      child: Text(
        "Você não tem nenhuma requisição",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
        appBar: AppBar(
          title: Text("Painel Motorista"),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: _escolhaMenuItem,
              itemBuilder: (context) {
                return itensMenu.map((String item) {
                  return PopupMenuItem(child: Text(item), value: item);
                }).toList();
              },
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _controller.stream,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return mensagemCarregando;
                break;
              case ConnectionState.active:
              case ConnectionState.done:
                if (snapshot.hasError) {
                  return Text("Erro ao carregar os dados!");
                } else {
                  QuerySnapshot querySnapshot = snapshot.data;
                  if (querySnapshot.docs.length == 0) {
                    return mensagemNaoTemDados;
                  } else {
                    return ListView.separated(
                      itemCount: querySnapshot.docs.length,
                      separatorBuilder: (context, indice) =>
                          Divider(height: 2, color: Colors.grey),
                      itemBuilder: (context, indice) {
                        List<DocumentSnapshot> requisicoes =
                            querySnapshot.docs.toList();
                        DocumentSnapshot item = requisicoes[indice];
                        String idRequisicao = item["id"];
                        String nomePassageiro = item["passageiro"]["nome"];
                        String rua = item["destino"]["rua"];
                        String numero = item["destino"]["numero"];

                        return ListTile(
                          title: Text(nomePassageiro),
                          subtitle: Text("Destino: ${rua}, ${numero}"),
                          onTap: (){
                            Navigator.pushNamed(
                              context,
                              "/corrida",
                              arguments: idRequisicao
                            );
                          },
                        );

                      },
                    );
                  }
                }
                break;
            }
          },
        ));
  }
}
