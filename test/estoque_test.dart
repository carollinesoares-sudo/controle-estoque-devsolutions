import 'package:flutter_test/flutter_test.dart';
import 'package:json_todo_list_path/models/produto_model.dart';

void main() {
  const produtoInicial = Produto(
    id: 'produto-1',
    codigo: 'P-001',
    nome: 'Papel A4',
    categoria: 'Papelaria',
    unidade: 'pacote',
    custoUnitario: 25.5,
    estoqueAtual: 4,
    estoqueMinimo: 2,
  );
  const dadosIniciais = DadosEstoque(
    produtos: [produtoInicial],
    movimentacoes: [],
  );

  test('carrega produtos do formato JSON antigo', () {
    final produto = Produto.fromJson({
      'id': 'antigo-1',
      'nome': 'Caneta',
      'valor': 3.25,
    });

    expect(produto.nome, 'Caneta');
    expect(produto.custoUnitario, 3.25);
    expect(produto.estoqueAtual, 0);
    expect(produto.unidade, 'un');
  });

  test('entrada atualiza o saldo e registra o histórico', () {
    final atualizado = registrarMovimentacao(
      dados: dadosIniciais,
      produtoId: produtoInicial.id,
      tipo: TipoMovimentacao.entrada,
      quantidade: 3,
      observacao: 'Reposição',
      data: DateTime.utc(2026, 11, 19),
    );

    expect(atualizado.produtos.single.estoqueAtual, 7);
    expect(atualizado.movimentacoes.single.tipo, TipoMovimentacao.entrada);
    expect(atualizado.movimentacoes.single.quantidade, 3);
    expect(atualizado.movimentacoes.single.observacao, 'Reposição');
  });

  test('saída maior que o saldo é recusada sem alterar os dados', () {
    expect(
      () => registrarMovimentacao(
        dados: dadosIniciais,
        produtoId: produtoInicial.id,
        tipo: TipoMovimentacao.saida,
        quantidade: 5,
      ),
      throwsStateError,
    );

    expect(produtoInicial.estoqueAtual, 4);
    expect(dadosIniciais.movimentacoes, isEmpty);
  });

  test('saldo e movimentações sobrevivem à serialização JSON', () {
    final atualizado = registrarMovimentacao(
      dados: dadosIniciais,
      produtoId: produtoInicial.id,
      tipo: TipoMovimentacao.saida,
      quantidade: 1.5,
      data: DateTime.utc(2026, 11, 19, 10),
    );

    final carregado = DadosEstoque.fromJson(atualizado.toJson());
    expect(carregado.produtos.single.estoqueAtual, 2.5);
    expect(
      carregado.movimentacoes.single.data.toUtc(),
      DateTime.utc(2026, 11, 19, 10),
    );
  });
}
