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
  Position _localMotorista;

  //Controles para exibição na tela
  String _textoBotao = "ACEITAR CORRIDA";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

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
      _exibirMarcadorPassageiro(position);

      _posicaoCamera = CameraPosition(target: LatLng(
          position.latitude,
          position.longitude),
          zoom: 16
      );

      //_movimentarCamera(_posicaoCamera);

      setState(() {
        _localMotorista = position;
      });

    });
  }

  _recuperarUltimalocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();
    setState(() {
      if (position != null) {
        _exibirMarcadorPassageiro(position);
        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 16);
        //_movimentarCamera(_posicaoCamera);

        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").doc(idRequisicao).get();
    _dadosRequisicao = documentSnapshot.data();
    _adcionarListenerRequisicao();
  }

  _adcionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];
    await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        Map<String, dynamic> dados = snapshot.data();
        String status = dados["status"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.FINALIZADA:
            break;
          case StatusRequisicao.VIAGEM:
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal("ACEITAR CORRIDA", Color(0xff1ebbd8), () {
      _aceitarCorrida();
    });
  }

  _statusACaminho() {
    _alterarBotaoPrincipal("A caminho do passageiro", Colors.grey, null);
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

    if(latitudeMotorista <= latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if(longitudeMotorista <= longitudePassageiro){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBound(
        LatLngBounds(
          northeast: LatLng(nLat, nLon),
          southwest: LatLng(sLat, sLon)
        )
    );
    
  }

  _movimentarCameraBound(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
      CameraUpdate.newLatLngBounds(
        latLngBounds,
        100
      )
    );
  }

  _exibirDoisMarcadores(LatLng latLng1, LatLng latLng2){
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
          icon: icone
      );
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
          icon: icone
      );
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
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").doc(idRequisicao).update({
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
        "id_requisicao": idRequisicao,
        "id_usuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimalocalizacaoConhecida();
    _adicionarListenerLocalizacao();
    _recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Painel Passageiro")),
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
