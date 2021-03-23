import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {
  String idRequisicao;

  Corrida(this.idRequisicao);

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
      CameraPosition(target: LatLng(-1.4430669411541555, -48.4590759598569));
  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequisicao;

  //Controles para exibição na tela
  String _textoBotao = "ACEITAR CORRIDA";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _mensagemStatus = "";
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.high)
        .listen((Position position) {
      if (position != null) {
        if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
          if (_statusRequisicao != StatusRequisicao.AGUARDANDO) {
            //Atualizar local motorista
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao, position.latitude, position.longitude);

          } else {
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _recuperarUltimalocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      //Atualizar localização em tempo real do motorista
    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").doc(idRequisicao).get();

    _adicionarListenerRequisicao();
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    await db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        setState(() {
          _dadosRequisicao = snapshot.data();
        });

        Map<String, dynamic> dados = snapshot.data();
        setState(() {
          _statusRequisicao = dados["status"];
        });

        switch (_statusRequisicao) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal("ACEITAR CORRIDA", Color(0xff1ebbd8), () {
      _aceitarCorrida();
    });

    if(_localMotorista != null){
      double motoristaLat = _localMotorista.latitude;
      double motoristaLng = _localMotorista.longitude;

      Position position =
      Position(latitude: motoristaLat, longitude: motoristaLng);
      _exibirMarcador(position, "imagens/motorista.png", "Motorista");

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 16);

      _movimentarCamera(cameraPosition);
    }
  }

  _statusACaminho() {
    setState(() {
      _mensagemStatus = "A caminho do passageiro";
    });
    _alterarBotaoPrincipal("Iniciar Corrida", Color(0xff1ebbd8), () {
      _iniciarCorrida();
    });
    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(
      LatLng(latitudeMotorista, longitudeMotorista),
      LatLng(latitudePassageiro, longitudePassageiro),
    );

    var nLat, nLon, sLat, sLon;

    if (latitudeMotorista <= latitudePassageiro) {
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    } else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if (longitudeMotorista <= longitudePassageiro) {
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    } else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBound(LatLngBounds(
        northeast: LatLng(nLat, nLon), southwest: LatLng(sLat, sLon)));
  }

  _iniciarCorrida() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes").doc(_idRequisicao).update({
      "origem": {
        "latitude": _dadosRequisicao["motorista"]["latitude"],
        "longitude": _dadosRequisicao["motorista"]["longitude"]
      },
      "status": StatusRequisicao.VIAGEM
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .doc(idPassageiro)
        .update({"status": StatusRequisicao.VIAGEM});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .doc(idMotorista)
        .update({"status": StatusRequisicao.VIAGEM});
  }

  _movimentarCameraBound(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _exibirDoisMarcadores(LatLng latLng1, LatLng latLng2) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcador1 = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLng1.latitude, latLng1.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);
      _listaMarcadores.add(marcador1);
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcador2 = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLng2.latitude, latLng2.longitude),
          infoWindow: InfoWindow(title: "Local Passageiro"),
          icon: icone);
      _listaMarcadores.add(marcador2);
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });
  }

  _aceitarCorrida() async {
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();

    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes").doc(_idRequisicao).update({
      "motorista": motorista.toMap(),
      "status": StatusRequisicao.A_CAMINHO
    }).then((_) {
      //Atualizar requisicao ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa").doc(idPassageiro).update({
        "motorista": motorista.toMap(),
        "status": StatusRequisicao.A_CAMINHO
      });

      //Salvar requisicao ativa para motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista").doc(idMotorista).set({
        "id_requisicao": _idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _idRequisicao = widget.idRequisicao;
    //adicionar listener para mudanças na requisicao
    _adicionarListenerRequisicao();
    //_recuperarUltimalocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Painel Passageiro - ${_mensagemStatus}")),
        body: Container(
          child: Stack(
            children: <Widget>[
              GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _posicaoCamera,
                onMapCreated: _onMapCreated,
                //myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: _marcadores,
              ),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: RaisedButton(
                      onPressed: _funcaoBotao,
                      child: Text(
                        _textoBotao,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      color: _corBotao,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    ),
                  ))
            ],
          ),
        ));
  }
}
