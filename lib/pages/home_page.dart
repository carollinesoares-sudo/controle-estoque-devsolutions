import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:json_todo_list_path/models/produto_model.dart';
import 'package:json_todo_list_path/pages/movimentacoes_page.dart';
import 'package:json_todo_list_path/pages/produtos_page.dart';
import 'package:json_todo_list_path/models/services/produto_service.dart';
import 'package:json_todo_list_path/services/stock_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.userId, required this.email, super.key});

  final String userId;
  final String email;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StockRepository _repository;
  late Stream<DadosEstoque> _dadosStream;
  int _pagina = 0;
  bool _importando = false;

  @override
  void initState() {
    super.initState();
    _repository = StockRepository(userId: widget.userId);
    _dadosStream = _repository.watchData();
  }

  void _reconectar() {
    setState(() => _dadosStream = _repository.watchData());
  }

  Future<void> _sair() async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível encerrar a sessão: ${error.message}'),
        ),
      );
    }
  }

  Future<void> _importarDadosLocais() async {
    if (_importando) return;
    setState(() => _importando = true);
    try {
      final dadosLocais = await ProdutoService().carregarDados();
      if (!mounted) return;
      if (dadosLocais.produtos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não há produtos locais para importar.'),
          ),
        );
        return;
      }

      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importar dados deste aparelho?'),
          content: Text(
            'Serão importados ${dadosLocais.produtos.length} produtos e '
            '${dadosLocais.movimentacoes.length} movimentações para a conta '
            '${widget.email}. A importação não substitui dados já existentes na nuvem.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmado != true) return;
      final quantidade = await _repository.importarDadosLocais(dadosLocais);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            quantidade == 0
                ? 'Os dados locais já foram importados anteriormente.'
                : '$quantidade produtos importados para a nuvem.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar os dados: $error')),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _registrarMovimentacao(
    String produtoId,
    TipoMovimentacao tipo,
    double quantidade,
    String observacao,
    String emailCriador,
  ) {
    return _repository.registrarTransacao(
      produtoId: produtoId,
      tipo: tipo,
      quantidade: quantidade,
      observacao: observacao,
      emailCriador: emailCriador,
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Visão geral', 'Produtos', 'Movimentações'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_pagina]),
        actions: [
          if (widget.email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Tooltip(
                  message: widget.email,
                  child: Text(
                    widget.email,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Reconectar ao estoque',
            onPressed: _reconectar,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (acao) {
              if (acao == 'importar') _importarDadosLocais();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'importar',
                enabled: !_importando,
                child: Text(
                  _importando
                      ? 'Importando dados locais...'
                      : 'Importar dados locais',
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DadosEstoque>(
        stream: _dadosStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErroCarregamento(
              mensagem:
                  'Não foi possível sincronizar o estoque: ${snapshot.error}',
              onTentar: _reconectar,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dados = snapshot.data!;
          return IndexedStack(
            index: _pagina,
            children: [
              _Dashboard(dados: dados),
              ProdutosPage(
                produtos: dados.produtos,
                onSalvarProduto: _repository.salvarProduto,
                onAlternarAtivo: _repository.alternarProdutoAtivo,
              ),
              MovimentacoesPage(
                dados: dados,
                emailUsuario: widget.email,
                onRegistrar: _registrarMovimentacao,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pagina,
        onDestinationSelected: (index) => setState(() => _pagina = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_circle_outlined),
            selectedIcon: Icon(Icons.swap_vert_circle),
            label: 'Movimentações',
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.dados});

  final DadosEstoque dados;

  @override
  Widget build(BuildContext context) {
    final produtosAtivos = dados.produtos
        .where((produto) => produto.ativo)
        .toList();
    final abaixoDoMinimo = produtosAtivos
        .where((produto) => produto.estoqueBaixo)
        .toList();
    final valorTotal = produtosAtivos.fold<double>(
      0,
      (total, produto) => total + produto.estoqueAtual * produto.custoUnitario,
    );
    final movimentacaoPorProduto = <String, double>{};
    for (final movimentacao in dados.movimentacoes) {
      movimentacaoPorProduto.update(
        movimentacao.produtoId,
        (total) => total + movimentacao.quantidade,
        ifAbsent: () => movimentacao.quantidade,
      );
    }
    final produtosMaisMovimentados = produtosAtivos.toList()
      ..sort(
        (a, b) => (movimentacaoPorProduto[b.id] ?? 0).compareTo(
          movimentacaoPorProduto[a.id] ?? 0,
        ),
      );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Resumo do estoque',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Acompanhe os produtos e identifique o que precisa de reposição.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 3 : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _Indicador(
                    titulo: 'Produtos ativos',
                    valor: '${produtosAtivos.length}',
                    icone: Icons.inventory_2_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _Indicador(
                    titulo: 'Valor estimado',
                    valor: _formatarMoeda(valorTotal),
                    icone: Icons.payments_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _Indicador(
                    titulo: 'Abaixo do mínimo',
                    valor: '${abaixoDoMinimo.length}',
                    icone: Icons.warning_amber_rounded,
                    destaque: abaixoDoMinimo.isNotEmpty,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Precisa de reposição',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (abaixoDoMinimo.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('Tudo certo!'),
              subtitle: Text('Nenhum produto está abaixo do mínimo.'),
            ),
          )
        else
          ...abaixoDoMinimo.map(
            (produto) => Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(produto.nome),
                subtitle: Text(
                  'Saldo: ${_formatarQuantidade(produto.estoqueAtual)} '
                  '${produto.unidade} · mínimo: '
                  '${_formatarQuantidade(produto.estoqueMinimo)} ${produto.unidade}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Mais movimentados',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (dados.movimentacoes.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.swap_vert),
              title: Text('Ainda não há movimentações'),
              subtitle: Text('Registre uma entrada ou saída para iniciar.'),
            ),
          )
        else
          ...produtosMaisMovimentados
              .take(5)
              .map(
                (produto) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: Text(produto.nome),
                    trailing: Text(
                      '${_formatarQuantidade(movimentacaoPorProduto[produto.id] ?? 0)} '
                      '${produto.unidade}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        Text(
          'Valor estimado calculado pelo saldo atual multiplicado pelo custo unitário.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.titulo,
    required this.valor,
    required this.icone,
    this.destaque = false,
  });

  final String titulo;
  final String valor;
  final IconData icone;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cor = destaque
        ? Colors.deepOrange
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErroCarregamento extends StatelessWidget {
  const _ErroCarregamento({required this.mensagem, required this.onTentar});

  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(mensagem, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onTentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

String _formatarMoeda(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

String _formatarQuantidade(double valor) => valor == valor.roundToDouble()
    ? valor.toStringAsFixed(0)
    : valor.toString();
