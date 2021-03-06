import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/Usuario.dart';

class UsuarioFirebase {
  static Future<User> getUsuarioAtual() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    return await auth.currentUser;
  }

  static Future<Usuario> getDadosUsuarioLogado() async {
    User firebaseUser = await getUsuarioAtual();
    String idUsuario = firebaseUser.uid;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot =
        await db.collection("usuarios").doc(idUsuario).get();

    Map<String, dynamic> dados = snapshot.data();
    String tipoUsuario = dados["tipoUsuario"];
    String email = dados["email"];
    String nome = dados["nome"];

    Usuario usuario = Usuario();
    usuario.idUsuario = idUsuario;
    usuario.tipoUsuario = tipoUsuario;
    usuario.email = email;
    usuario.nome = nome;

    return usuario;
  }

  static atualizarDadosLocalizacao(
      String idRequisicao, double lat, double lng) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    Usuario motorista = await getDadosUsuarioLogado();
    motorista.latitude = lat;
    motorista.longitude = lng;
    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": motorista.toMap()
    });
  }
}
