   // lib/screens/room_detail_screen.dart
   import 'package:flutter/material.dart';
   import 'package:provider/provider.dart';
   import 'package:dio/dio.dart';
   import '../services/api_service.dart';
   import '../models/room_models.dart';
   import '../providers/auth_provider.dart';
   // import 'assign_patient_dialog.dart'; // TODO: 환자 선택 다이얼로그 구현 필요

   class RoomDetailScreen extends StatefulWidget {
     final String roomId;

     const RoomDetailScreen({super.key, required this.roomId});

     @override
     State<RoomDetailScreen> createState() => _RoomDetailScreenState();
   }

   class _RoomDetailScreenState extends State<RoomDetailScreen> {
     final ApiService _apiService = ApiService();
     Room? _roomDetails;
     bool _isLoading = true;
     String? _errorMessage;
     bool _isProcessingBedAction = false; // 침상 관련 작업 로딩 상태

     @override
     void initState() {
       super.initState();
       _fetchRoomDetails();
     }

     Future<void> _fetchRoomDetails({bool showLoading = true}) async {
       final authProvider = Provider.of<AuthProvider>(context, listen: false);
       if (!authProvider.isAuthenticated) {
         setState(() { _isLoading = false; _errorMessage = "로그인이 필요합니다."; });
         return;
       }
       if (showLoading) setState(() { _isLoading = true; _errorMessage = null; });

       try {
         final response = await _apiService.getRoomDetails(widget.roomId);
         if (response.statusCode == 200) {
           setState(() {
             _roomDetails = Room.fromJson(response.data as Map<String, dynamic>);
             _isLoading = false;
           });
         } else {
           throw DioException(requestOptions: response.requestOptions, response: response, message: 'Failed to load room details');
         }
       } catch (e) {
         print("Fetch room details error: $e");
         String detailMessage = "알 수 없는 오류";
         if (e is DioException) {
            if (e.response?.data != null) {
               if (e.response!.data is Map && e.response!.data['detail'] != null) {
                  detailMessage = e.response!.data['detail'];
               } else { detailMessage = e.response!.data.toString(); }
            } else { detailMessage = e.message ?? "Dio 오류"; }
          } else { detailMessage = e.toString(); }
         if (mounted) setState(() { _errorMessage = "병실 상세 정보 로딩 실패: $detailMessage"; _isLoading = false; });
       }
     }

     // --- 새 침상 추가 다이얼로그 표시 및 처리 ---
     Future<void> _showAddBedDialog() async {
       final bedNumberController = TextEditingController();
       final notesController = TextEditingController();
       final formKey = GlobalKey<FormState>();

       final bool? added = await showDialog<bool>(
         context: context,
         builder: (BuildContext context) {
           return AlertDialog(
             title: const Text('새 침상 추가'),
             content: Form(
               key: formKey,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   TextFormField(
                     controller: bedNumberController,
                     decoration: const InputDecoration(labelText: '침상 번호 *', hintText: '예: A, 1, 창가'),
                     validator: (value) {
                       if (value == null || value.trim().isEmpty) {
                         return '침상 번호를 입력하세요.';
                       }
                       return null;
                     },
                   ),
                   const SizedBox(height: 10),
                   TextFormField(
                     controller: notesController,
                     decoration: const InputDecoration(labelText: '메모 (선택)', hintText: '침상 관련 특이사항'),
                     maxLines: 2,
                   ),
                 ],
               )
             ),
             actions: <Widget>[
               TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
               ElevatedButton(
                 onPressed: () async {
                   if (formKey.currentState!.validate()) {
                     Navigator.of(context).pop(true); // 추가 진행 위해 true 반환
                   }
                 },
                 child: const Text('추가'),
               ),
             ],
           );
         },
       );

       if (added == true && bedNumberController.text.trim().isNotEmpty) {
         await _addBed(bedNumberController.text.trim(), notesController.text.trim());
       }
     }

     // --- 새 침상 추가 API 호출 ---
     Future<void> _addBed(String bedNumber, String? notes) async {
        setState(() { _isProcessingBedAction = true; });
        try {
           // ApiService의 createBedInRoom 함수 호출 (roomId는 widget.roomId 사용)
           final response = await _apiService.createBedInRoom(
             roomId: widget.roomId,
             bedNumber: bedNumber,
             notes: notes,
           );
           if (response.statusCode == 201) {
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('침상 ($bedNumber)이 추가되었습니다.'), backgroundColor: Colors.green),
                 );
                 await _fetchRoomDetails(showLoading: false); // 목록 새로고침
              }
           } else {
              throw DioException(requestOptions: response.requestOptions, response: response, message: 'Failed to add bed');
           }
        } catch (e) {
           print("Error adding bed: $e");
           String errorMsg = "침상 추가 실패";
           if (e is DioException && e.response?.data != null) {
              if (e.response!.data is Map) {
                  final errors = e.response!.data as Map<String, dynamic>;
                  if (errors.isNotEmpty) {
                     final firstKey = errors.keys.first;
                     final errorValue = errors[firstKey];
                     final message = errorValue is List ? errorValue[0] : errorValue;
                     errorMsg = "${firstKey.replaceAll('_', ' ').capitalize()}: $message";
                  } else if (errors.containsKey('detail')) {
                     errorMsg = errors['detail'];
                  } else { errorMsg = "서버 응답 오류: ${e.response!.data}"; }
              } else { errorMsg = "서버 응답 오류: ${e.response!.data.toString().substring(0, 100)}..."; }
           } else { errorMsg = e.toString(); }
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        } finally {
           if(mounted) setState(() { _isProcessingBedAction = false; });
        }
     }

     // --- 환자 배정 로직 (임시 - 실제 환자 선택 UI 필요) ---
     Future<void> _assignPatient(Bed bed) async {
       // TODO: 실제 환자 검색/선택 UI 구현
       String? selectedPatientId = await _showPatientSelectionDialog();
       if (selectedPatientId == null || selectedPatientId.trim().isEmpty) return;

       setState(() { _isProcessingBedAction = true; });
       try {
         await _apiService.assignPatientToBed(widget.roomId, bed.id, selectedPatientId.trim());
         await _fetchRoomDetails(showLoading: false);
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('환자가 배정되었습니다.'), backgroundColor: Colors.green));
       } catch (e) {
          print("Error assigning patient: $e");
          String errorMsg = "환자 배정 실패";
          if (e is DioException && e.response?.data != null) {
             if (e.response!.data is Map) {
                 final errors = e.response!.data as Map<String, dynamic>;
                 if (errors.isNotEmpty && errors.containsKey('patient_id')) {
                    errorMsg = "환자 ID: ${errors['patient_id'][0]}";
                 } else if (errors.containsKey('detail')) {
                    errorMsg = errors['detail'];
                 } else { errorMsg = "서버 응답 오류"; }
             } else { errorMsg = "서버 응답 오류"; }
          }
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
       } finally {
         if(mounted) setState(() { _isProcessingBedAction = false; });
       }
     }

     // --- 환자 퇴실 로직 ---
     Future<void> _dischargePatient(Bed bed) async {
        bool? confirm = await showDialog<bool>(
          context: context, // <<<--- context 전달 확인
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('환자 퇴실 확인'),
              content: Text('${bed.patient?.fullName ?? '해당 환자'}님을 이 침상에서 퇴실 처리하시겠습니까?'),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('퇴실 확인'),
                ),
              ],
            );
          },
        );

        if (confirm != true) return;

        setState(() { _isProcessingBedAction = true; });
        try {
          await _apiService.dischargePatientFromBed(widget.roomId, bed.id);
          await _fetchRoomDetails(showLoading: false);
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('환자가 퇴실 처리되었습니다.'), backgroundColor: Colors.orange));
        } catch (e) {
           print("Error discharging patient: $e");
           String errorMsg = "환자 퇴실 처리 실패";
           if (e is DioException && e.response?.data != null) { /* ... 오류 메시지 처리 ... */ }
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        } finally {
          if(mounted) setState(() { _isProcessingBedAction = false; });
        }
     }

     // --- 환자 선택 다이얼로그 (임시 구현) ---
     Future<String?> _showPatientSelectionDialog() async {
       // TODO: 실제 환자 목록 API 호출 및 선택 UI 구현
       TextEditingController patientIdController = TextEditingController();
       return await showDialog<String>(
         context: context, // <<<--- context 전달 확인
         builder: (context) => AlertDialog(
           title: const Text('배정할 환자 ID 입력'),
           content: TextField(
             controller: patientIdController,
             decoration: const InputDecoration(hintText: 'PatientProfile ID'),
             keyboardType: TextInputType.text,
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
             ElevatedButton(onPressed: () => Navigator.pop(context, patientIdController.text.trim()), child: const Text('확인')),
           ],
         ),
       );
     }

     @override
     Widget build(BuildContext context) {
       // 로딩, 오류, 데이터 없음 UI 처리
       if (_isLoading) {
         return Scaffold(appBar: AppBar(title: Text('병실 정보 로딩 중...')), body: const Center(child: CircularProgressIndicator()));
       }
       if (_errorMessage != null) {
         return Scaffold(appBar: AppBar(title: Text('오류')), body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: Colors.red[700], size: 50), const SizedBox(height: 15), Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)), const SizedBox(height: 20), ElevatedButton(onPressed: _fetchRoomDetails, child: const Text("다시 시도")) ]))));
       }
       if (_roomDetails == null) {
         return Scaffold(appBar: AppBar(title: Text('정보 없음')), body: const Center(child: Text('해당 병실 정보를 찾을 수 없습니다.')));
       }

       // 병실 상세 정보 및 침상 목록 표시 UI
       return Scaffold(
         appBar: AppBar(
           title: Text('${_roomDetails!.roomNumber} 상세 정보'),
           actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading || _isProcessingBedAction ? null : _fetchRoomDetails,
                tooltip: '새로고침',
              ),
           ],
         ),
         body: RefreshIndicator(
           onRefresh: _fetchRoomDetails,
           child: ListView(
             padding: const EdgeInsets.all(16.0),
             children: <Widget>[
               // --- 병실 기본 정보 카드 ---
               Card(
                 elevation: 2,
                 margin: const EdgeInsets.only(bottom: 16),
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('병실 번호: ${_roomDetails!.roomNumber}', style: Theme.of(context).textTheme.headlineSmall),
                       const SizedBox(height: 8),
                       Row(children: [ const Icon(Icons.layers, size: 16, color: Colors.grey), const SizedBox(width: 8), Text('층: ${_roomDetails!.floor ?? 'N/A'}'), const SizedBox(width: 16), const Icon(Icons.meeting_room, size: 16, color: Colors.grey), const SizedBox(width: 8), Text('타입: ${_roomDetails!.roomType}'), ]),
                       const SizedBox(height: 8),
                       Row(children: [ const Icon(Icons.people_alt, size: 16, color: Colors.grey), const SizedBox(width: 8), Text('수용 인원: ${_roomDetails!.currentOccupancy} / ${_roomDetails!.capacity}'), ]),
                       if (_roomDetails!.description != null && _roomDetails!.description!.isNotEmpty) ...[ const SizedBox(height: 8), Row(children: [ const Icon(Icons.notes, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('설명: ${_roomDetails!.description}')), ]), ]
                     ],
                   ),
                 ),
               ),
               const SizedBox(height: 20),

               // --- 침상 목록 ---
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('침상 목록 (${_roomDetails!.beds.length}개)', style: Theme.of(context).textTheme.titleLarge),
                   // --- !!! 새 침상 추가 버튼 !!! ---
                   IconButton(
                     icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
                     tooltip: '새 침상 추가',
                     onPressed: _isProcessingBedAction ? null : _showAddBedDialog, // 버튼 클릭 시 다이얼로그 표시
                   ),
                   // -----------------------------
                 ],
               ),
               const Divider(thickness: 1),
               const SizedBox(height: 10),
               _buildBedList(), // 침상 목록 UI 빌드
             ],
           ),
         ),
       );
     }

     // --- 침상 목록 빌드 메소드 ---
     Widget _buildBedList() {
       if (_roomDetails!.beds.isEmpty) {
         return const Center(
           child: Padding(
             padding: EdgeInsets.symmetric(vertical: 40.0),
             child: Text('등록된 침상이 없습니다. (+) 버튼을 눌러 추가하세요.', style: TextStyle(color: Colors.grey)),
           )
         );
       }
       // 침상 목록을 Column으로 표시
       return Column(
         children: _roomDetails!.beds.map((bed) => Card(
           margin: const EdgeInsets.symmetric(vertical: 6),
           elevation: 2,
           child: ListTile(
             leading: Icon(
               bed.isOccupied ? Icons.bed : Icons.bed_outlined,
               color: bed.isOccupied ? Colors.indigo : Colors.green,
               size: 30,
             ),
             title: Text('침상 번호: ${bed.bedNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text(
               bed.isOccupied && bed.patient != null
                   ? '사용 중: ${bed.patient!.fullName} (ID: ${bed.patient!.username})' // 환자 이름과 username 표시
                   : '비어있음',
               style: TextStyle(color: bed.isOccupied ? Colors.indigo : Colors.black54),
             ),
             trailing: _isProcessingBedAction // 작업 중이면 로딩 표시
                 ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                 : PopupMenuButton<String>( // 더보기 메뉴 버튼
                     tooltip: '작업 선택',
                     onSelected: (String result) {
                       if (result == 'assign') {
                         _assignPatient(bed); // 환자 배정 함수 호출
                       } else if (result == 'discharge') {
                         _dischargePatient(bed); // 환자 퇴실 함수 호출
                       }
                     },
                     itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                       if (!bed.isOccupied) // 비어있을 때만 배정 옵션 표시
                         const PopupMenuItem<String>(
                           value: 'assign',
                           child: ListTile(leading: Icon(Icons.person_add_alt_1), title: Text('환자 배정')),
                         ),
                       if (bed.isOccupied) // 사용 중일 때만 퇴실 옵션 표시
                         const PopupMenuItem<String>(
                           value: 'discharge',
                           child: ListTile(leading: Icon(Icons.logout), title: Text('환자 퇴실')),
                         ),
                     ],
                     icon: const Icon(Icons.more_vert),
                   ),
           ),
         )).toList(),
       );
     }
     // --------------------------
   }

   // 문자열 첫 글자 대문자 변환 확장
   extension StringExtension on String {
       String capitalize() {
         if (isEmpty) return "";
         return "${this[0].toUpperCase()}${substring(1)}";
       }
   }
   