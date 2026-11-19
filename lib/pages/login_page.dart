import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _cadastro = false;
  bool _carregando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text;
      if (_cadastro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem('Não foi possível concluir a operação: $error');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _mostrarMensagem(
        'Informe seu e-mail para receber o link de recuperação.',
      );
      return;
    }
    setState(() => _carregando = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _mostrarMensagem(
        'Se a conta existir, enviaremos um link para redefinir a senha.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error));
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem('Não foi possível enviar o e-mail: $error');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _mensagemErro(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'O e-mail informado é inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já possui uma conta.';
      case 'weak-password':
        return 'Escolha uma senha mais forte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique a rede e tente novamente.';
      case 'operation-not-allowed':
        return 'O acesso por e-mail ainda não está ativado no Firebase.';
      default:
        return error.message ?? 'Falha de autenticação (${error.code}).';
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 64,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _cadastro ? 'Criar conta' : 'Almoxarifado Central',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estoque sincronizado com segurança na nuvem.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty || !email.contains('@')) {
                                return 'Informe um e-mail válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _senhaController,
                            obscureText: !_mostrarSenha,
                            autofillHints: _cadastro
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _mostrarSenha
                                    ? 'Ocultar senha'
                                    : 'Mostrar senha',
                                onPressed: () => setState(
                                  () => _mostrarSenha = !_mostrarSenha,
                                ),
                                icon: Icon(
                                  _mostrarSenha
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final senha = value ?? '';
                              if (senha.isEmpty) return 'Informe sua senha.';
                              if (_cadastro && senha.length < 8) {
                                return 'Use pelo menos 8 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (!_cadastro)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _carregando ? null : _recuperarSenha,
                                child: const Text('Esqueci minha senha'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _carregando ? null : _autenticar,
                              child: _carregando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_cadastro ? 'CRIAR CONTA' : 'ENTRAR'),
                            ),
                          ),
                          TextButton(
                            onPressed: _carregando
                                ? null
                                : () => setState(() {
                                    _cadastro = !_cadastro;
                                    _formKey.currentState?.reset();
                                  }),
                            child: Text(
                              _cadastro
                                  ? 'Já tem uma conta? Entrar'
                                  : 'Não tem conta? Cadastre-se',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
