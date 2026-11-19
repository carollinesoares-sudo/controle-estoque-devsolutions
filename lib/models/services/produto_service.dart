import 'dart:convert';
import 'dart:io';
import 'package:json_todo_list_path/models/produto_model.dart';
import 'package:path_provider/path_provider.dart';

class ProdutoService {
  static const String _fileName = 'estoque.json';
  static const String _legacyFileName = 'produtos.json';

  Future<File> _getFile(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$name');
  }

  Future<DadosEstoque> carregarDados() async {
    final file = await _getFile(_fileName);
    if (await file.exists()) {
      final decoded = json.decode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'O arquivo de estoque possui formato inválido.',
        );
      }
      return DadosEstoque.fromJson(decoded);
    }

    final legacyFile = await _getFile(_legacyFileName);
    if (!await legacyFile.exists()) {
      return const DadosEstoque(produtos: [], movimentacoes: []);
    }

    final decoded = json.decode(await legacyFile.readAsString());
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'O arquivo antigo de produtos possui formato inválido.',
      );
    }
    final dadosMigrados = DadosEstoque(
      produtos: decoded
          .map((item) => Produto.fromJson(item as Map<String, dynamic>))
          .toList(),
      movimentacoes: const [],
    );
    await salvarDados(dadosMigrados);
    return dadosMigrados;
  }

  Future<void> salvarDados(DadosEstoque dados) async {
    final file = await _getFile(_fileName);
    await file.writeAsString(json.encode(dados.toJson()), flush: true);
  }

  Future<List<Produto>> carregarProdutos() async =>
      (await carregarDados()).produtos;

  Future<void> salvarProdutos(List<Produto> produtos) async {
    final dadosAtuais = await carregarDados();
    await salvarDados(
      DadosEstoque(
        produtos: produtos,
        movimentacoes: dadosAtuais.movimentacoes,
      ),
    );
  }
}
