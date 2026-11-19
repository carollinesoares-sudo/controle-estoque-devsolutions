import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:json_todo_list_path/models/produto_model.dart';

class StockRepository {
  StockRepository({required this.userId});

  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  DocumentReference<Map<String, dynamic>> get _userReference =>
      _firestore.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _products =>
      _userReference.collection('products');

  CollectionReference<Map<String, dynamic>> get _movements =>
      _userReference.collection('movements');

  Stream<DadosEstoque> watchData() {
    final controller = StreamController<DadosEstoque>();
    List<Produto>? produtos;
    List<Movimentacao>? movimentacoes;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    produtosSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    movimentacoesSubscription;

    void publicarSePronto() {
      if (produtos == null || movimentacoes == null) return;
      controller.add(
        DadosEstoque(produtos: produtos!, movimentacoes: movimentacoes!),
      );
    }

    controller.onListen = () {
      produtosSubscription = _products.snapshots().listen(
        (snapshot) {
          produtos = snapshot.docs
              .map(
                (document) =>
                    Produto.fromJson({...document.data(), 'id': document.id}),
              )
              .toList();
          publicarSePronto();
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
        },
      );
      movimentacoesSubscription = _movements
          .orderBy('data', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              movimentacoes = snapshot.docs
                  .map(
                    (document) => Movimentacao.fromJson({
                      ...document.data(),
                      'id': document.id,
                    }),
                  )
                  .toList();
              publicarSePronto();
            },
            onError: (Object error, StackTrace stackTrace) {
              controller.addError(error, stackTrace);
            },
          );
    };
    controller.onCancel = () async {
      await produtosSubscription?.cancel();
      await movimentacoesSubscription?.cancel();
    };
    return controller.stream;
  }

  Future<void> salvarProduto(Produto produto) async {
    final codigo = produto.codigo.trim();
    if (produto.id.isEmpty ||
        codigo.isEmpty ||
        produto.nome.trim().isEmpty ||
        produto.categoria.trim().isEmpty ||
        produto.unidade.trim().isEmpty ||
        !produto.custoUnitario.isFinite ||
        produto.custoUnitario < 0 ||
        !produto.estoqueAtual.isFinite ||
        produto.estoqueAtual < 0 ||
        !produto.estoqueMinimo.isFinite ||
        produto.estoqueMinimo < 0) {
      throw ArgumentError('Os dados do produto são inválidos.');
    }

    final produtoReference = _products.doc(produto.id);
    final codigoReference = _codeReference(codigo);
    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(produtoReference);
      final codeSnapshot = await transaction.get(codigoReference);
      final oldCode = currentSnapshot.data()?['codigo']?.toString();
      final codigoAnterior = oldCode == null || oldCode.isEmpty
          ? null
          : _codeReference(oldCode);

      final codigoOcupadoPorOutroProduto =
          codeSnapshot.exists &&
          codeSnapshot.data()?['productId'] != produto.id;
      if (codigoOcupadoPorOutroProduto) {
        throw StateError('Esse código já está cadastrado.');
      }

      if (codigoAnterior != null &&
          codigoAnterior.path != codigoReference.path) {
        transaction.delete(codigoAnterior);
      }

      transaction.set(codigoReference, {'productId': produto.id});
      transaction.set(produtoReference, {
        ...produto.toJson(),
        'codigo': codigo,
        'estoqueAtual':
            currentSnapshot.data()?['estoqueAtual'] ?? produto.estoqueAtual,
        'lastMovementId': currentSnapshot.data()?['lastMovementId'],
        'createdAt':
            currentSnapshot.data()?['createdAt'] ??
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> alternarProdutoAtivo(Produto produto) async {
    await _products.doc(produto.id).update({
      'ativo': !produto.ativo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> importarDadosLocais(DadosEstoque dados) async {
    if (dados.produtos.isEmpty) return 0;

    final metadataReference = _userReference
        .collection('metadata')
        .doc('localJsonImportV1');
    final metadata = await metadataReference.get();
    if (metadata.data()?['state'] == 'completed') return 0;

    final existingProducts = await _products.limit(1).get();
    final existingMovements = await _movements.limit(1).get();
    final importInProgress = metadata.data()?['state'] == 'inProgress';
    if (!importInProgress &&
        (existingProducts.docs.isNotEmpty ||
            existingMovements.docs.isNotEmpty)) {
      throw StateError(
        'Esta conta já possui dados na nuvem. A importação local foi cancelada para evitar duplicações.',
      );
    }

    await metadataReference.set({
      'state': 'inProgress',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final writes =
        <
          ({
            DocumentReference<Map<String, dynamic>> reference,
            Map<String, dynamic> data,
          })
        >[];
    final idsImportados = <String>{};
    final codigosImportados = <String>{};
    final idsProdutosImportados = <String, String>{};

    for (var index = 0; index < dados.produtos.length; index++) {
      final produto = dados.produtos[index];
      var id = produto.id.trim();
      if (id.isEmpty || id.contains('/') || !idsImportados.add(id)) {
        id = 'local-import-$index';
        idsImportados.add(id);
      }

      var codigo = produto.codigo.trim();
      if (codigo.isEmpty || !codigosImportados.add(codigo.toLowerCase())) {
        codigo = 'IMPORT-${index + 1}';
        codigosImportados.add(codigo.toLowerCase());
      }
      if (codigo.length > 60) {
        codigo = '${codigo.substring(0, 50)}-${index + 1}';
      }
      idsProdutosImportados[produto.id] = id;

      final produtoImportado = Produto(
        id: id,
        codigo: codigo,
        nome: produto.nome.trim().isEmpty ? 'Produto importado' : produto.nome,
        categoria: produto.categoria.trim().isEmpty
            ? 'Geral'
            : produto.categoria,
        unidade: produto.unidade.trim().isEmpty ? 'un' : produto.unidade,
        custoUnitario: produto.custoUnitario,
        estoqueAtual: produto.estoqueAtual,
        estoqueMinimo: produto.estoqueMinimo,
        ativo: produto.ativo,
      );
      writes.add((
        reference: _products.doc(id),
        data: {
          ...produtoImportado.toJson(),
          'lastMovementId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ));
      writes.add((reference: _codeReference(codigo), data: {'productId': id}));
    }

    for (final movimento in dados.movimentacoes) {
      final productId = idsProdutosImportados[movimento.produtoId];
      if (productId == null ||
          !movimento.quantidade.isFinite ||
          movimento.quantidade <= 0) {
        continue;
      }
      final movementId =
          movimento.id.trim().isEmpty || movimento.id.contains('/')
          ? 'local-movement-${writes.length}'
          : movimento.id;
      final importedMovement = Movimentacao(
        id: movementId,
        produtoId: productId,
        tipo: movimento.tipo,
        quantidade: movimento.quantidade,
        data: movimento.data,
        observacao: movimento.observacao,
        criadoPor: userId,
        emailCriador: '',
      );
      writes.add((
        reference: _movements.doc(importedMovement.id),
        data: importedMovement.toJson(),
      ));
    }

    for (var start = 0; start < writes.length; start += 400) {
      final batch = _firestore.batch();
      for (final write in writes.skip(start).take(400)) {
        batch.set(write.reference, write.data, SetOptions(merge: true));
      }
      await batch.commit();
    }
    await metadataReference.set({
      'state': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return dados.produtos.length;
  }

  Future<void> registrarTransacao({
    required String produtoId,
    required TipoMovimentacao tipo,
    required double quantidade,
    required String observacao,
    required String emailCriador,
  }) async {
    if (produtoId.isEmpty || !quantidade.isFinite || quantidade <= 0) {
      throw ArgumentError('Os dados da movimentação são inválidos.');
    }

    final produtoReference = _products.doc(produtoId);
    final movimentacaoReference = _movements.doc();
    final data = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final produtoSnapshot = await transaction.get(produtoReference);
      final productData = produtoSnapshot.data();
      if (productData == null) {
        throw StateError('O produto selecionado não foi encontrado.');
      }

      final produto = Produto.fromJson({...productData, 'id': produtoId});
      final dadosAtualizados = registrarMovimentacao(
        dados: DadosEstoque(produtos: [produto], movimentacoes: const []),
        produtoId: produtoId,
        tipo: tipo,
        quantidade: quantidade,
        observacao: observacao,
        data: data,
        movimentacaoId: movimentacaoReference.id,
        criadoPor: userId,
        emailCriador: emailCriador,
      );
      final produtoAtualizado = dadosAtualizados.produtos.single;
      final movimentacao = dadosAtualizados.movimentacoes.single;

      transaction.update(produtoReference, {
        'estoqueAtual': produtoAtualizado.estoqueAtual,
        'lastMovementId': movimentacaoReference.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movimentacaoReference, movimentacao.toJson());
    });
  }

  DocumentReference<Map<String, dynamic>> _codeReference(String code) {
    final normalizedCode = Uri.encodeComponent(code.trim().toLowerCase());
    return _userReference.collection('productCodes').doc(normalizedCode);
  }
}
