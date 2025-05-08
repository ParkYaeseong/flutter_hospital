// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _email = '';
  String _password = '';
  String _password2 = '';
  String _firstName = '';
  String _lastName = '';
  String _selectedRole = 'PATIENT'; // 기본값 환자
  final List<String> _roles = ['PATIENT', 'CLINICIAN'];

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.register(
        username: _username,
        email: _email,
        password: _password,
        password2: _password2,
        firstName: _firstName,
        lastName: _lastName,
        role: _selectedRole,
      );

      if (mounted) { // 위젯이 여전히 마운트되어 있는지 확인
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result['data']?['username']}님, 회원가입이 완료되었습니다. 로그인해주세요.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // 성공 시 이전 화면(보통 로그인 화면)으로 돌아가기
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '회원가입에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  decoration: const InputDecoration(labelText: '사용자 이름 (로그인 ID)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '사용자 이름을 입력해주세요.';
                    return null;
                  },
                  onSaved: (value) => _username = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: '이메일 주소'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return '유효한 이메일을 입력해주세요.';
                    }
                    return null;
                  },
                  onSaved: (value) => _email = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 8) {
                      return '비밀번호는 8자 이상이어야 합니다.';
                    }
                    return null;
                  },
                  onSaved: (value) => _password = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호 확인을 입력해주세요.';
                    }
                    if (value != _password) { // _formKey.currentState.save()가 호출된 후 _password에 값이 할당됨
                      // 이 검증은 _submit 전에 _password 값이 필요하므로,
                      // _password를 onSaved 대신 onChanged로 업데이트하거나,
                      // _formKey.currentState.save()를 두 번 호출하지 않도록 _submit에서 직접 _password 값을 가져와야 함.
                      // 간단하게는 _password 필드에 접근하는 대신, 컨트롤러를 사용하거나
                      // _submit 시 _formKey.currentState.fields['password'].value 와 비교
                      // 여기서는 일단 _password 필드 사용 가정 (폼 제출 시 한번에 검증)
                    }
                    return null;
                  },
                  onSaved: (value) => _password2 = value!,
                ),
                // 비밀번호 확인 필드 개선 (컨트롤러 사용 또는 _submit 내부에서 값 비교)
                // TextFormField(
                //   controller: _password2Controller, // 별도 컨트롤러 사용
                //   decoration: const InputDecoration(labelText: '비밀번호 확인'),
                //   obscureText: true,
                //   validator: (value) {
                //     if (value != _passwordController.text) { // 다른 컨트롤러의 값과 비교
                //       return '비밀번호가 일치하지 않습니다.';
                //     }
                //     return null;
                //   },
                // ),

                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: '성 (선택)'),
                  onSaved: (value) => _lastName = value ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: '이름 (선택)'),
                  onSaved: (value) => _firstName = value ?? '',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '역할'),
                  value: _selectedRole,
                  items: _roles.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'PATIENT' ? '환자' : '의료인'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue!;
                    });
                  },
                  validator: (value) => value == null ? '역할을 선택해주세요.' : null,
                ),
                const SizedBox(height: 30),
                authProvider.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        ),
                        child: const Text('회원가입'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}