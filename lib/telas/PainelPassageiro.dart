import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uber/model/Destino.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {
  TextEditingController _controllerDestino = TextEditingController();
  List<String> itensMenu = ["Configurações", "Deslogar"];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
      CameraPosition(target: LatLng(-1.4430669411541555, -48.4590759598569));
  Set<Marker> _marcadores = {};
  String _idRequisicao;
  Position _localPassageiro;
  Map<String, dynamic> _dadosRequisicao;
  StreamSubscription<DocumentSnapshot> _streamSubscription;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "CHAMAR UBER";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;

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

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.high)
        .listen((Position position) {
      if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
        //Atualizar local passageiro
        UsuarioFirebase.atualizarDadosLocalizacao(
            _idRequisicao, position.latitude, position.longitude);

      } else {
        setState(() {
          _localPassageiro = position;
        });
        _statusUberNaoChamado();
      }
    });
  }

  _recuperarUltimalocalizacaoConhecida() async {
    Position position = await Geolocator.getLastKnownPosition();
    setState(() {
      if (position != null) {
        _exibirMarcadorPassageiro(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);
        _localPassageiro = position;
        _movimentarCamera(_posicaoCamera);
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
            "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {
    String enderecoDestino = _controllerDestino.text;

    if (enderecoDestino.isNotEmpty) {
      List<Location> locations = await locationFromAddress(enderecoDestino);

      if (locations != null && locations.length > 0) {
        Location position = locations[0];

        List<Placemark> listaEnderecos = await placemarkFromCoordinates(
            position.latitude, locations[0].longitude);
        if (listaEnderecos != null && listaEnderecos.length > 0) {
          Placemark endereco = listaEnderecos[0];
          Destino destino = Destino();
          destino.cidade = endereco.administrativeArea;
          destino.cep = endereco.postalCode;
          destino.bairro = endereco.subLocality;
          destino.rua = endereco.thoroughfare;
          destino.numero = endereco.subThoroughfare;

          destino.latitude = position.latitude;
          destino.longitude = position.longitude;

          String enderecoConfirmacao;
          enderecoConfirmacao = "\n Cidade: ${destino.cidade}";
          enderecoConfirmacao += "\n Rua: ${destino.rua}, ${destino.numero}";
          enderecoConfirmacao += "\n Bairro: ${destino.bairro}";
          enderecoConfirmacao += "\n Cep: ${destino.cep}";

          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text("Confirmação do endereço"),
                  content: Text(enderecoConfirmacao),
                  contentPadding: EdgeInsets.all(16),
                  actions: <Widget>[
                    FlatButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancelar",
                          style: TextStyle(color: Colors.red),
                        )),
                    FlatButton(
                        onPressed: () {
                          _salvarRequisicao(destino);
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Confirmar",
                          style: TextStyle(color: Colors.green),
                        )),
                  ],
                );
              });
        }
      }
    }
  }

  _salvarRequisicao(Destino destino) async {
    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro.latitude;
    passageiro.longitude = _localPassageiro.longitude;

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    //Salvar requisicao
    db.collection("requisicoes").doc(requisicao.id).set(requisicao.toMap());

    //Salvar requisicao ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db
        .collection("requisicao_ativa")
        .doc(passageiro.idUsuario)
        .set(dadosRequisicaoAtiva);

    if(_streamSubscription == null){
      _adicionarListenerRequisicao(requisicao.id);
    }

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _statusUberNaoChamado() {
    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal("CHAMAR UBER", Color(0xff1ebbd8), () {
      _chamarUber();
    });

    if(_localPassageiro != null){
      Position position = Position(
          latitude: _localPassageiro.latitude,
          longitude: _localPassageiro.longitude);
      _exibirMarcadorPassageiro(position);

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 16);

      _movimentarCamera(cameraPosition);
    }
  }

  _statusAguardando() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("CANCELAR", Colors.red, () {
      _cancelarUber();
    });

    double passageiroLat = _dadosRequisicao["passageiro"]["latitude"];
    double passageiroLon = _dadosRequisicao["passageiro"]["longitude"];

    Position position =
        Position(latitude: passageiroLat, longitude: passageiroLon);
    _exibirMarcadorPassageiro(position);

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 16);

    _movimentarCamera(cameraPosition);
  }

  _statusACaminho() {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal("Motorista a caminho", Colors.grey, null);

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(
        LatLng(latitudeMotorista, longitudeMotorista),
        LatLng(latitudePassageiro, longitudePassageiro)
    );

    //'southwest.latitude <= northeast.latitude': is not true
    var nLat, nLon, sLat, sLon;

    if( latitudeMotorista <=  latitudePassageiro ){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if( longitudeMotorista <=  longitudePassageiro ){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }
    //-23.560925, -46.650623
    _movimentarCameraBounds(
        LatLngBounds(
            northeast: LatLng(nLat, nLon), //nordeste
            southwest: LatLng(sLat, sLon) //sudoeste
        )
    );

  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
        CameraUpdate.newLatLngBounds(
            latLngBounds,
            100
        )
    );
  }

  _exibirDoisMarcadores(LatLng latLngMotorista, LatLng latLngPassageiro){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcador1 = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLngMotorista.latitude, latLngMotorista.longitude),
          infoWindow: InfoWindow(title: "Local motorista"),
          icon: icone);
      _listaMarcadores.add( marcador1 );
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcador2 = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLngPassageiro.latitude, latLngPassageiro.longitude),
          infoWindow: InfoWindow(title: "Local passageiro"),
          icon: icone);
      _listaMarcadores.add( marcador2 );
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _cancelarUber() async {
    User user = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;

    db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .update({"status": StatusRequisicao.CANCELADA}).then((_) {
      db.collection("requisicao_ativa").doc(user.uid).delete();
    });
  }

  _recuperarRequisicaoAtiva() async {
    User user = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot documentSnapshot = await db
        .collection("requisicao_ativa")
        .doc(user.uid)
        .get();

    if( documentSnapshot.data() != null ){

      Map<String, dynamic> dados = documentSnapshot.data();

      setState(() {
        _idRequisicao = dados["id_requisicao"];
      });

      _adicionarListenerRequisicao( _idRequisicao );

    }else{

      _statusUberNaoChamado();

    }
  }

  _adicionarListenerRequisicao(String idRequisicao) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    _streamSubscription = await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.data() != null) {
        Map<String, dynamic> dados = snapshot.data();

        setState(() {
          _idRequisicao = dados["id"];
          _dadosRequisicao = dados;
        });

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

  @override
  void initState() {
    super.initState();
    _recuperarRequisicaoAtiva();
    //_recuperarUltimalocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Painel Passageiro"),
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
              Visibility(
                visible: _exibirCaixaEnderecoDestino,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin:
                                        EdgeInsets.only(left: 20, bottom: 16),
                                    width: 10,
                                    height: 10,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                    ),
                                  ),
                                  hintText: "Meu Local",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(left: 15)),
                            ),
                          ),
                        )),
                    Positioned(
                        top: 55,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              controller: _controllerDestino,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin:
                                        EdgeInsets.only(left: 20, bottom: 16),
                                    width: 10,
                                    height: 10,
                                    child: Icon(
                                      Icons.local_taxi,
                                      color: Colors.black,
                                    ),
                                  ),
                                  hintText: "Digite Seu Destino",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(left: 15)),
                            ),
                          ),
                        )),
                  ],
                ),
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
        )
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription.cancel();
  }

}
