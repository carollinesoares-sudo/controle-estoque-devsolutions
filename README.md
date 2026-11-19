# Controle de Estoque — Almoxarifado Central

[Abrir repositório no GitHub](https://github.com/carollinesoares-sudo/controle-estoque-devsolutions)

[![Flutter CI](https://github.com/carollinesoares-sudo/controle-estoque-devsolutions/actions/workflows/flutter.yml/badge.svg)](https://github.com/carollinesoares-sudo/controle-estoque-devsolutions/actions/workflows/flutter.yml)

Aplicativo Flutter para gerenciar produtos, saldos e movimentações de entrada e saída, com login e sincronização em tempo real pelo Firebase.

## Funcionalidades

- Cadastro, edição, busca e filtro de produtos por categoria.
- Código de produto único por conta, unidade, custo e estoque mínimo.
- Entradas e saídas registradas em transação do Firestore; saídas acima do saldo são recusadas.
- Histórico de movimentações com data, observação e e-mail do responsável.
- Dashboard com alertas de reposição, valor estimado e produtos mais movimentados.
- Login, cadastro, logout e recuperação de senha por e-mail.
- Dados sincronizados entre dispositivos que usam a mesma conta Firebase.
- Importação confirmada dos produtos e movimentações JSON já salvos neste aparelho.
- Regras do Firestore restringem os dados à conta autenticada e bloqueiam edição e exclusão do histórico.

## Firebase configurado

- Projeto dedicado: `almoxarifado-central-20261119`.
- Firebase Authentication com provedor e-mail/senha habilitado.
- Firestore Standard na região de São Paulo (`southamerica-east1`), database ID `default`.
- Regras de segurança em `firestore.rules`, já publicadas no projeto.
- O aplicativo Android está registrado como `com.devsolutions.estoque`.

Para publicar futuras alterações nas regras ou no provedor de autenticação:

```powershell
firebase deploy --only auth,firestore --project almoxarifado-central-20261119
```

O Firebase CLI precisa estar autenticado com uma conta autorizada no projeto. Consulte o plano e os limites de uso do Firebase antes de distribuir o app; serviços em nuvem podem gerar cobrança conforme o volume de uso.

## Executar e validar

Pré-requisitos: Flutter stable e um dispositivo ou emulador Android conectado.

```powershell
flutter pub get
flutter run
```

Para gerar um APK de depuração:

```powershell
flutter build apk --debug
```

O pacote FlutterFire foi configurado para Android. Outros alvos exigem registrar a plataforma no Firebase e gerar as opções correspondentes.

## Regras de negócio

- Cada conta autenticada mantém um estoque privado; contas diferentes não compartilham dados.
- O código de produto é único por conta, sem diferença entre maiúsculas e minúsculas.
- O saldo só muda por uma movimentação: alterações simultâneas usam transação Firestore, e saídas não deixam saldo negativo.
- As regras publicadas permitem edição dos dados do produto, mas exigem movimentação vinculada para alterar o saldo. O histórico é somente leitura após criado.
- A importação do JSON existente no aparelho requer confirmação e não substitui dados já existentes na nuvem.

## Dados e acesso

Cada conta tem seu próprio estoque em `users/{uid}/products`, `users/{uid}/movements` e coleções de apoio. Assim, contas diferentes não compartilham produtos. O MVP não implementa convite de funcionários, papéis administrativos nem um estoque único compartilhado entre várias contas.

Na primeira abertura após entrar, use **Mais opções → Importar dados locais** para enviar o JSON antigo deste aparelho para a conta atual. A importação não sobrescreve um estoque que já exista na nuvem.

O valor no dashboard é uma estimativa de saldo × custo unitário atual, não uma avaliação contábil nem um cálculo de custo médio histórico.
