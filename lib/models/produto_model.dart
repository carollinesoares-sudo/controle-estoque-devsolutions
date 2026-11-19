class Produto {
  const Produto({
    required this.id,
    required this.nome,
    this.codigo = '',
    this.categoria = 'Geral',
    this.unidade = 'un',
    double? custoUnitario,
    double? valor,
    this.estoqueAtual = 0,
    this.estoqueMinimo = 0,
    this.ativo = true,
  }) : custoUnitario = custoUnitario ?? valor ?? 0;

  final String id;
  final String codigo;
  final String nome;
  final String categoria;
  final String unidade;
  final double custoUnitario;
  final double estoqueAtual;
  final double estoqueMinimo;
  final bool ativo;

  double get valor => custoUnitario;

  bool get estoqueBaixo => estoqueAtual <= estoqueMinimo;

  Produto copyWith({
    String? codigo,
    String? nome,
    String? categoria,
    String? unidade,
    double? custoUnitario,
    double? estoqueAtual,
    double? estoqueMinimo,
    bool? ativo,
  }) {
    return Produto(
      id: id,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      unidade: unidade ?? this.unidade,
      custoUnitario: custoUnitario ?? this.custoUnitario,
      estoqueAtual: estoqueAtual ?? this.estoqueAtual,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      ativo: ativo ?? this.ativo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'categoria': categoria,
    'unidade': unidade,
    'custoUnitario': custoUnitario,
    'estoqueAtual': estoqueAtual,
    'estoqueMinimo': estoqueMinimo,
    'ativo': ativo,
  };

  factory Produto.fromJson(Map<String, dynamic> json) {
    final oldValue = json['valor'];
    return Produto(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      codigo: json['codigo']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'Geral',
      unidade: json['unidade']?.toString() ?? 'un',
      custoUnitario:
          ((json['custoUnitario'] ?? oldValue) as num?)?.toDouble() ?? 0,
      estoqueAtual: (json['estoqueAtual'] as num?)?.toDouble() ?? 0,
      estoqueMinimo: (json['estoqueMinimo'] as num?)?.toDouble() ?? 0,
      ativo: json['ativo'] as bool? ?? true,
    );
  }
}

enum TipoMovimentacao { entrada, saida }

class Movimentacao {
  const Movimentacao({
    required this.id,
    required this.produtoId,
    required this.tipo,
    required this.quantidade,
    required this.data,
    this.observacao = '',
    this.criadoPor = '',
    this.emailCriador = '',
  });

  final String id;
  final String produtoId;
  final TipoMovimentacao tipo;
  final double quantidade;
  final DateTime data;
  final String observacao;
  final String criadoPor;
  final String emailCriador;

  Map<String, dynamic> toJson() => {
    'id': id,
    'produtoId': produtoId,
    'tipo': tipo.name,
    'quantidade': quantidade,
    'data': data.toUtc().toIso8601String(),
    'observacao': observacao,
    'criadoPor': criadoPor,
    'emailCriador': emailCriador,
  };

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      id: json['id']?.toString() ?? '',
      produtoId: json['produtoId']?.toString() ?? '',
      tipo: json['tipo'] == TipoMovimentacao.saida.name
          ? TipoMovimentacao.saida
          : TipoMovimentacao.entrada,
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
      data:
          DateTime.tryParse(json['data']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      observacao: json['observacao']?.toString() ?? '',
      criadoPor: json['criadoPor']?.toString() ?? '',
      emailCriador: json['emailCriador']?.toString() ?? '',
    );
  }
}

class DadosEstoque {
  const DadosEstoque({required this.produtos, required this.movimentacoes});

  final List<Produto> produtos;
  final List<Movimentacao> movimentacoes;

  factory DadosEstoque.fromJson(Map<String, dynamic> json) => DadosEstoque(
    produtos: (json['produtos'] as List<dynamic>? ?? [])
        .map((item) => Produto.fromJson(item as Map<String, dynamic>))
        .toList(),
    movimentacoes: (json['movimentacoes'] as List<dynamic>? ?? [])
        .map((item) => Movimentacao.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'produtos': produtos.map((produto) => produto.toJson()).toList(),
    'movimentacoes': movimentacoes
        .map((movimentacao) => movimentacao.toJson())
        .toList(),
  };
}

DadosEstoque registrarMovimentacao({
  required DadosEstoque dados,
  required String produtoId,
  required TipoMovimentacao tipo,
  required double quantidade,
  String observacao = '',
  DateTime? data,
  String? movimentacaoId,
  String criadoPor = '',
  String emailCriador = '',
}) {
  if (!quantidade.isFinite || quantidade <= 0) {
    throw ArgumentError.value(
      quantidade,
      'quantidade',
      'Deve ser maior que zero.',
    );
  }

  final produtoIndex = dados.produtos.indexWhere(
    (produto) => produto.id == produtoId,
  );
  if (produtoIndex == -1) {
    throw StateError('O produto selecionado não foi encontrado.');
  }

  final produto = dados.produtos[produtoIndex];
  if (!produto.ativo) {
    throw StateError('Não é possível movimentar um produto inativo.');
  }
  if (tipo == TipoMovimentacao.saida && quantidade > produto.estoqueAtual) {
    throw StateError(
      'Saldo insuficiente. Disponível: ${produto.estoqueAtual} ${produto.unidade}.',
    );
  }

  final novoSaldo = tipo == TipoMovimentacao.entrada
      ? produto.estoqueAtual + quantidade
      : produto.estoqueAtual - quantidade;
  final produtosAtualizados = [...dados.produtos];
  produtosAtualizados[produtoIndex] = produto.copyWith(estoqueAtual: novoSaldo);
  final movimentacao = Movimentacao(
    id: movimentacaoId ?? DateTime.now().microsecondsSinceEpoch.toString(),
    produtoId: produto.id,
    tipo: tipo,
    quantidade: quantidade,
    data: data ?? DateTime.now(),
    observacao: observacao,
    criadoPor: criadoPor,
    emailCriador: emailCriador,
  );
  return DadosEstoque(
    produtos: produtosAtualizados,
    movimentacoes: [movimentacao, ...dados.movimentacoes],
  );
}
