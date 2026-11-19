import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_todo_list_path/models/produto_model.dart';

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({
    required this.produtos,
    required this.onSalvarProduto,
    required this.onAlternarAtivo,
    super.key,
  });

  final List<Produto> produtos;
  final Future<void> Function(Produto produto) onSalvarProduto;
  final Future<void> Function(Produto produto) onAlternarAtivo;

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  final TextEditingController _buscaController = TextEditingController();
  String _categoriaSelecionada = 'Todas';
  bool _mostrarInativos = false;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<Produto> get _produtosFiltrados {
    final termo = _buscaController.text.trim().toLowerCase();
    return widget.produtos.where((produto) {
        final correspondeStatus = _mostrarInativos || produto.ativo;
        final correspondeBusca =
            termo.isEmpty ||
            produto.nome.toLowerCase().contains(termo) ||
            produto.codigo.toLowerCase().contains(termo);
        final correspondeCategoria =
            _categoriaSelecionada == 'Todas' ||
            produto.categoria == _categoriaSelecionada;
        return correspondeStatus && correspondeBusca && correspondeCategoria;
      }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  Future<void> _abrirFormulario({Produto? produto}) async {
    final formKey = GlobalKey<FormState>();
    final codigo = TextEditingController(text: produto?.codigo ?? '');
    final nome = TextEditingController(text: produto?.nome ?? '');
    final categoria = TextEditingController(text: produto?.categoria ?? '');
    final unidade = TextEditingController(text: produto?.unidade ?? 'un');
    final custo = TextEditingController(
      text: produto == null ? '' : produto.custoUnitario.toStringAsFixed(2),
    );
    final minimo = TextEditingController(
      text: produto == null ? '0' : _quantidade(produto.estoqueMinimo),
    );

    try {
      final resultado = await showDialog<Produto>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(produto == null ? 'Novo produto' : 'Editar produto'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _campo(
                      codigo,
                      'Código',
                      icone: Icons.qr_code,
                      maxLength: 60,
                    ),
                    _campo(
                      nome,
                      'Nome do produto',
                      icone: Icons.inventory_2,
                      maxLength: 120,
                    ),
                    _campo(
                      categoria,
                      'Categoria',
                      icone: Icons.category,
                      maxLength: 80,
                    ),
                    _campo(
                      unidade,
                      'Unidade (un, cx, pct...)',
                      icone: Icons.straighten,
                      maxLength: 20,
                    ),
                    _campo(
                      custo,
                      'Custo unitário (R\$)',
                      icone: Icons.payments_outlined,
                      numerico: true,
                    ),
                    _campo(
                      minimo,
                      'Estoque mínimo',
                      icone: Icons.warning_amber,
                      numerico: true,
                    ),
                    if (produto != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Saldo atual: ${_quantidade(produto.estoqueAtual)} ${produto.unidade}. '
                          'Altere o saldo pela tela de movimentações.',
                        ),
                      ),
                    ],
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
                final novoCodigo = codigo.text.trim();
                final codigoDuplicado = widget.produtos.any(
                  (item) =>
                      item.codigo.toLowerCase() == novoCodigo.toLowerCase() &&
                      item.id != produto?.id,
                );
                if (codigoDuplicado) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esse código já está cadastrado.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  Produto(
                    id:
                        produto?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    codigo: novoCodigo,
                    nome: nome.text.trim(),
                    categoria: categoria.text.trim(),
                    unidade: unidade.text.trim(),
                    custoUnitario: _numero(custo.text)!,
                    estoqueAtual: produto?.estoqueAtual ?? 0,
                    estoqueMinimo: _numero(minimo.text)!,
                    ativo: produto?.ativo ?? true,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );

      if (resultado == null) return;
      await widget.onSalvarProduto(resultado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto salvo com sucesso.')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o produto: $error')),
      );
    } finally {
      codigo.dispose();
      nome.dispose();
      categoria.dispose();
      unidade.dispose();
      custo.dispose();
      minimo.dispose();
    }
  }

  Future<void> _alternarAtivo(Produto produto) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(produto.ativo ? 'Desativar produto?' : 'Ativar produto?'),
        content: Text(
          produto.ativo
              ? 'O produto será ocultado das operações, mas seu histórico será mantido.'
              : 'O produto voltará a aparecer nas operações.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(produto.ativo ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (confirmacao != true) return;
    try {
      await widget.onAlternarAtivo(produto);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar o produto: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias =
        widget.produtos.map((produto) => produto.categoria).toSet().toList()
          ..sort();
    final opcoesCategoria = ['Todas', ...categorias];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar produto'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _buscaController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Buscar por nome ou código',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _buscaController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _buscaController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: opcoesCategoria.contains(_categoriaSelecionada)
                  ? _categoriaSelecionada
                  : 'Todas',
              items: opcoesCategoria
                  .map(
                    (categoria) => DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _categoriaSelecionada = value ?? 'Todas'),
            ),
            FilterChip(
              label: const Text('Incluir inativos'),
              selected: _mostrarInativos,
              onSelected: (value) => setState(() => _mostrarInativos = value),
            ),
            Text('${_produtosFiltrados.length} produtos'),
          ],
        ),
        const SizedBox(height: 8),
        if (_produtosFiltrados.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Nenhum produto encontrado. Cadastre um produto para começar.',
                ),
              ),
            ),
          )
        else
          ..._produtosFiltrados.map(
            (produto) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: produto.estoqueBaixo && produto.ativo
                      ? Colors.orange.shade100
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    produto.estoqueBaixo && produto.ativo
                        ? Icons.warning_amber
                        : Icons.inventory_2_outlined,
                  ),
                ),
                title: Text(produto.nome),
                subtitle: Text(
                  '${produto.codigo} · ${produto.categoria}\n'
                  'Saldo: ${_quantidade(produto.estoqueAtual)} ${produto.unidade} · '
                  'Mínimo: ${_quantidade(produto.estoqueMinimo)} ${produto.unidade} · '
                  'Custo: ${_moeda(produto.custoUnitario)}'
                  '${produto.ativo ? '' : '\nProduto inativo'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (acao) {
                    if (acao == 'editar') _abrirFormulario(produto: produto);
                    if (acao == 'status') _alternarAtivo(produto);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(produto.ativo ? 'Desativar' : 'Ativar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _campo(
  TextEditingController controller,
  String rotulo, {
  required IconData icone,
  bool numerico = false,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: numerico
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*([,.]\d*)?$'))]
          : null,
      decoration: InputDecoration(
        labelText: rotulo,
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final texto = value?.trim() ?? '';
        if (texto.isEmpty) return 'Campo obrigatório';
        if (numerico && (_numero(texto) == null || _numero(texto)! < 0)) {
          return 'Informe um número igual ou maior que zero';
        }
        return null;
      },
    ),
  );
}

double? _numero(String valor) =>
    double.tryParse(valor.trim().replaceAll(',', '.'));

String _quantidade(double valor) => valor == valor.roundToDouble()
    ? valor.toStringAsFixed(0)
    : valor.toString();

String _moeda(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
