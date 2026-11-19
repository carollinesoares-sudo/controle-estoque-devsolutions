import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_todo_list_path/models/produto_model.dart';

class MovimentacoesPage extends StatelessWidget {
  const MovimentacoesPage({
    required this.dados,
    required this.onRegistrar,
    required this.emailUsuario,
    super.key,
  });

  final DadosEstoque dados;
  final Future<void> Function(
    String produtoId,
    TipoMovimentacao tipo,
    double quantidade,
    String observacao,
    String emailCriador,
  )
  onRegistrar;
  final String emailUsuario;

  Future<void> _registrar(BuildContext context) async {
    final produtosDisponiveis = dados.produtos
        .where((produto) => produto.ativo)
        .toList();
    if (produtosDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre um produto ativo antes de movimentar o estoque.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final quantidade = TextEditingController();
    final observacao = TextEditingController();
    var produtoId = produtosDisponiveis.first.id;
    var tipo = TipoMovimentacao.entrada;

    try {
      final resultado = await showDialog<_FormularioMovimentacao>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nova movimentação'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: produtoId,
                        decoration: const InputDecoration(
                          labelText: 'Produto',
                          border: OutlineInputBorder(),
                        ),
                        items: produtosDisponiveis
                            .map(
                              (produto) => DropdownMenuItem(
                                value: produto.id,
                                child: Text(
                                  '${produto.nome} (${_quantidade(produto.estoqueAtual)} ${produto.unidade})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => produtoId = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<TipoMovimentacao>(
                        initialValue: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TipoMovimentacao.entrada,
                            child: Text('Entrada'),
                          ),
                          DropdownMenuItem(
                            value: TipoMovimentacao.saida,
                            child: Text('Saída'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => tipo = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantidade,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*([,.]\d*)?$'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = _numero(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Informe uma quantidade maior que zero';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: observacao,
                        maxLength: 160,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observação (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _FormularioMovimentacao(
                      produtoId: produtoId,
                      tipo: tipo,
                      quantidade: _numero(quantidade.text)!,
                      observacao: observacao.text.trim(),
                    ),
                  );
                },
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
      );

      if (resultado == null || !context.mounted) return;
      try {
        await onRegistrar(
          resultado.produtoId,
          resultado.tipo,
          resultado.quantidade,
          resultado.observacao,
          emailUsuario,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimentação registrada.')),
        );
      } on StateError catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar: $error')),
        );
      }
    } finally {
      quantidade.dispose();
      observacao.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtos = {
      for (final produto in dados.produtos) produto.id: produto,
    };
    final movimentacoes = [...dados.movimentacoes]
      ..sort((a, b) => b.data.compareTo(a.data));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _registrar(context),
          icon: const Icon(Icons.add),
          label: const Text('Registrar entrada ou saída'),
        ),
        const SizedBox(height: 16),
        Text(
          'Histórico',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (movimentacoes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhuma movimentação registrada.')),
            ),
          )
        else
          ...movimentacoes.map((movimentacao) {
            final produto = produtos[movimentacao.produtoId];
            final entrada = movimentacao.tipo == TipoMovimentacao.entrada;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entrada
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    entrada ? Icons.south_west : Icons.north_east,
                    color: entrada
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
                title: Text(produto?.nome ?? 'Produto removido'),
                subtitle: Text(
                  '${entrada ? 'Entrada' : 'Saída'} · ${_data(movimentacao.data)}'
                  '${movimentacao.observacao.isEmpty ? '' : '\n${movimentacao.observacao}'}'
                  '${movimentacao.emailCriador.isEmpty ? '' : '\nPor: ${movimentacao.emailCriador}'}',
                ),
                isThreeLine:
                    movimentacao.observacao.isNotEmpty ||
                    movimentacao.emailCriador.isNotEmpty,
                trailing: Text(
                  '${entrada ? '+' : '-'}${_quantidade(movimentacao.quantidade)}'
                  '${produto == null ? '' : ' ${produto.unidade}'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: entrada
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _FormularioMovimentacao {
  const _FormularioMovimentacao({
    required this.produtoId,
    required this.tipo,
    required this.quantidade,
    required this.observacao,
  });

  final String produtoId;
  final TipoMovimentacao tipo;
  final double quantidade;
  final String observacao;
}

double? _numero(String valor) =>
    double.tryParse(valor.trim().replaceAll(',', '.'));

String _quantidade(double valor) => valor == valor.roundToDouble()
    ? valor.toStringAsFixed(0)
    : valor.toString();

String _data(DateTime data) {
  final local = data.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year} às $hora:$minuto';
}
