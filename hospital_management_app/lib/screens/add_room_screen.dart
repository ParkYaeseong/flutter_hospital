// lib/screens/add_room_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _roomNumber = '';
  int? _floor;
  String _selectedRoomType = 'MULTI';
  int _capacity = 1;
  String _description = '';

  bool _isSaving = false;

  final List<DropdownMenuItem<String>> _roomTypeItems = [
    const DropdownMenuItem(value: 'SINGLE', child: Text('1인실')),
    const DropdownMenuItem(value: 'DOUBLE', child: Text('2인실')),
    const DropdownMenuItem(value: 'MULTI', child: Text('다인실')),
    const DropdownMenuItem(value: 'ICU', child: Text('중환자실')),
    const DropdownMenuItem(value: 'SPECIAL', child: Text('특실')),
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() { _isSaving = true; });

      try {
        final response = await _apiService.createRoom(
          roomNumber: _roomNumber,
          floor: _floor,
          roomType: _selectedRoomType,
          capacity: _capacity,
          description: _description,
        );

        if (response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('새 병실이 추가되었습니다.'), backgroundColor: Colors.green),
            );
            Navigator.of(context).pop(true); // 성공 시 true 반환
          }
        } else {
          throw DioException(requestOptions: response.requestOptions, response: response, message: 'Failed to create room');
        }
      } catch (e) {
        print("Error creating room: $e");
        String errorMessage = "병실 추가 중 오류가 발생했습니다.";
        if (e is DioException && e.response?.data != null) {
           if (e.response!.data is Map) {
               final errors = e.response!.data as Map<String, dynamic>;
               if (errors.isNotEmpty) {
                  final firstKey = errors.keys.first;
                  final errorValue = errors[firstKey];
                  final message = errorValue is List ? errorValue[0] : errorValue;
                  errorMessage = "${firstKey.replaceAll('_', ' ').capitalize()}: $message";
               } else if (errors.containsKey('detail')) {
                  errorMessage = errors['detail'];
               } else {
                  errorMessage = "서버 응답 오류: ${e.response!.data}";
               }
           } else {
               errorMessage = "서버 응답 오류: ${e.response!.data.toString().substring(0, 100)}...";
           }
        } else {
            errorMessage = e.toString();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 병실 추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '병실 번호 *',
                  hintText: '예: 101호, ICU-01',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '병실 번호를 입력하세요.';
                  }
                  return null;
                },
                onSaved: (value) => _roomNumber = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '층 (숫자)',
                  hintText: '병실이 위치한 층 번호',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.layers_outlined),
                ),
                keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return '유효한 층 번호(숫자)를 입력하세요.';
                  }
                  return null;
                },
                onSaved: (value) => _floor = (value != null && value.isNotEmpty) ? int.tryParse(value) : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '병실 종류 *',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.king_bed_outlined),
                ),
                value: _selectedRoomType,
                items: _roomTypeItems,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedRoomType = newValue; });
                  }
                },
                validator: (value) => value == null ? '병실 종류를 선택하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '수용 인원 (숫자) *',
                  hintText: '병실에 배치 가능한 최대 침상 수',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.people_outline),
                ),
                keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                initialValue: _capacity.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '1 이상의 유효한 숫자를 입력하세요.';
                  }
                  return null;
                },
                onSaved: (value) => _capacity = int.parse(value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  hintText: '병실 관련 추가 정보',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 32),
              // --- !!! ElevatedButton.icon 수정 !!! ---
              ElevatedButton.icon(
                // 로딩 중일 때는 아이콘 대신 인디케이터 표시
                icon: _isSaving
                    ? Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                // 로딩 중일 때는 텍스트 변경
                label: Text(_isSaving ? '저장 중...' : '병실 추가 완료'),
                onPressed: _isSaving ? null : _submitForm, // 저장 중일 때는 버튼 비활성화
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16)
                ),
              ),
              // -----------------------------------
            ],
          ),
        ),
      ),
    );
  }
}

// 문자열 첫 글자 대문자 변환 확장
extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}
