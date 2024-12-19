import 'package:flutter/material.dart';
import 'package:bmsc/globals.dart' as globals;
import 'package:bmsc/util/logger.dart';
import 'package:gt3_flutter_plugin/gt3_flutter_plugin.dart';

final logger = LoggerUtils.getLogger('LoginScreen');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSmsLogin = true;
  String? _captchaKey;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _login(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final captcha = await globals.api.getLoginCaptcha();
      if (captcha == null) {
        throw Exception('Failed to get login captcha');
      }

      logger.info('Geetest gt: ${captcha['gt']}');
      final geetest = Gt3FlutterPlugin();

      Gt3RegisterData registerData = Gt3RegisterData(
          gt: captcha['gt']!, challenge: captcha['challenge']!, success: true);

      geetest.addEventHandler(onShow: (message) {
        logger.info('Geetest challenge dialog shown: $message');
      }, onResult: (Map<String, dynamic> result) async {
        try {
          logger.info('Geetest verification result: $result');
          result = Map<String, dynamic>.from(result['result']);
          final (loginSuccess, loginError) = await globals.api.login(
            username: _usernameController.text,
            password: _passwordController.text,
            geetestResult: {
              'token': captcha['token']!,
              'challenge': result['geetest_challenge'],
              'validate': result['geetest_validate'],
              'seccode': result['geetest_seccode'],
            },
          );

          if (loginSuccess) {
            await globals.api.getUID();
            await globals.api.getUsername();
            if (context.mounted) {
              Navigator.pop(context, true);
            }
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(loginError ?? '登录失败')));
          }
        } catch (e) {
          logger.severe('Geetest onResult error: $e');
          throw Exception('Geetest onResult error: $e');
        }
      }, onError: (error) {
        logger.severe('Geetest error: $error');
        throw Exception('Geetest error: $error');
      });

      geetest.startCaptcha(registerData);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      logger.warning('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getSmsCode(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final captcha = await globals.api.getLoginCaptcha();
      if (captcha == null) {
        throw Exception('Failed to get login captcha');
      }

      final geetest = Gt3FlutterPlugin();
      Gt3RegisterData registerData = Gt3RegisterData(
          gt: captcha['gt']!, challenge: captcha['challenge']!, success: true);

      geetest.addEventHandler(
        onShow: (message) {
          logger.info('Geetest challenge dialog shown: $message');
        },
        onResult: (Map<String, dynamic> result) async {
          try {
            logger.info('Geetest verification result: $result');
            result = Map<String, dynamic>.from(result['result']);
            final (captchaKey, error) = await globals.api.getSmsCaptcha(
              tel: int.parse(_phoneController.text),
              geetestResult: {
                'token': captcha['token']!,
                'challenge': result['geetest_challenge'],
                'validate': result['geetest_validate'],
                'seccode': result['geetest_seccode'],
              },
            );

            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            } else {
              _captchaKey = captchaKey;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('验证码已发送')),
              );
            }
          } catch (e) {
            logger.severe('Geetest onResult error: $e');
            throw Exception('Geetest onResult error: $e');
          }
        },
        onError: (error) {
          logger.severe('Geetest error: $error');
          throw Exception('Geetest error: $error');
        },
      );

      geetest.startCaptcha(registerData);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      logger.warning('SMS code error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _smsLogin(BuildContext context) async {
    if (_captchaKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先获取验证码')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final (loginSuccess, loginError) = await globals.api.smslogin(
        tel: int.parse(_phoneController.text),
        code: _smsCodeController.text,
        captchaKey: _captchaKey!,
      );

      if (loginSuccess) {
        await globals.api.getUID();
        await globals.api.getUsername();
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loginError ?? '登录失败')));
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      logger.warning('SMS login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isSmsLogin = !_isSmsLogin;
                _errorMessage = null;
              });
            },
            icon:
                Icon(_isSmsLogin ? Icons.lock_outline : Icons.message_outlined),
            label: Text(_isSmsLogin ? '密码登录' : '短信登录'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isSmsLogin ? '手机验证码登录' : '账号密码登录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_isSmsLogin) ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '账号',
                      hintText: '请输入手机号或邮箱',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入账号';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入密码';
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入手机号',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入手机号';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _smsCodeController,
                          decoration: InputDecoration(
                            labelText: '验证码',
                            hintText: '请输入验证码',
                            prefixIcon: const Icon(Icons.security),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return '请输入验证码';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _getSmsCode(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('获取'),
                      ),
                    ],
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _isSmsLogin ? _smsLogin(context) : _login(context);
                          }
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '登录',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }
}
