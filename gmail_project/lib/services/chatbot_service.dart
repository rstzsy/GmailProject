import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatBotService {
  // Thay thế bằng API key của bạn từ Google AI Studio
  static const String _apiKey = 'AIzaSyC378JozS2zurbB5a8PbWqSP_H8EuNdc0o';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Sử dụng mô hình Gemini Pro
  static const String _model = 'gemini-2.0-flash';
  
  // Lưu trữ lịch sử cuộc trò chuyện để duy trì ngữ cảnh
  final List<Map<String, String>> _conversationHistory = [];
  
  // Khởi tạo system prompt tiếng Việt
  ChatBotService() {
    _conversationHistory.add({
      'role': 'user',
      'parts': 'You are a smart and helpful AI Assistant. Respond in Vietnamese in a natural, friendly and professional manner. You can help with work, emails, information searches and questions.'
    });
    _conversationHistory.add({
      'role': 'model',
      'parts': 'Hi! I am AI Assistant. I am here to help you with your work, compose emails, search for information, and answer any questions. What can I help you with today?'
    });
  }

  /// Gửi tin nhắn tới Gemini API và nhận phản hồi
  Future<String> sendMessage(String message) async {
    try {
      // Thêm tin nhắn người dùng vào lịch sử
      _conversationHistory.add({
        'role': 'user',
        'parts': message,
      });

      // Tạo request body
      final requestBody = {
        'contents': _buildContentsFromHistory(),
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
        ],
      };

      // Gửi request với timeout
      final response = await http.post(
        Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw http.ClientException('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Kiểm tra xem có phản hồi không
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final botResponse = data['candidates'][0]['content']['parts'][0]['text'];
          
          // Thêm phản hồi của bot vào lịch sử
          _conversationHistory.add({
            'role': 'model',
            'parts': botResponse,
          });

          // giữ 20 tin nhắn gần nhất
          if (_conversationHistory.length > 20) {
            // Giữ lại system prompt và xóa các tin nhắn cũ
            final systemPrompts = _conversationHistory.take(2).toList();
            final recentMessages = _conversationHistory.skip(_conversationHistory.length - 18).toList();
            _conversationHistory.clear();
            _conversationHistory.addAll(systemPrompts);
            _conversationHistory.addAll(recentMessages);
          }

          return botResponse;
        } else {
          return _handleApiError('Không nhận được phản hồi từ AI');
        }
      } else {
        final errorData = json.decode(response.body);
        return _handleApiError(errorData['error']['message'] ?? 'Lỗi không xác định');
      }
    } on SocketException {
      return 'Không có kết nối internet. Vui lòng kiểm tra lại kết nối của bạn.';
    } on FormatException {
      return 'Lỗi xử lý dữ liệu. Vui lòng thử lại sau.';
    } on http.ClientException {
      return 'Lỗi kết nối tới server. Vui lòng thử lại sau.';
    } catch (e) {
      print('ChatBot Service Error: $e');
      return 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại sau.';
    }
  }

  /// Xây dựng contents từ lịch sử cuộc trò chuyện cho API
  List<Map<String, dynamic>> _buildContentsFromHistory() {
    final contents = <Map<String, dynamic>>[];
    
    for (int i = 0; i < _conversationHistory.length; i++) {
      final message = _conversationHistory[i];
      contents.add({
        'role': message['role'],
        'parts': [
          {'text': message['parts']}
        ],
      });
    }
    
    return contents;
  }

  /// Xử lý lỗi API và trả về tin nhắn thân thiện
  String _handleApiError(String error) {
    if (error.contains('API key')) {
      return 'Lỗi xác thực API. Vui lòng kiểm tra cấu hình.';
    } else if (error.contains('quota')) {
      return 'Đã vượt quá giới hạn sử dụng API. Vui lòng thử lại sau.';
    } else if (error.contains('rate limit')) {
      return 'Đang gửi quá nhiều yêu cầu. Vui lòng chờ một chút rồi thử lại.';
    } else {
      return 'Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.';
    }
  }

  /// Xóa lịch sử cuộc trò chuyện
  void clearHistory() {
    _conversationHistory.clear();
    // Khởi tạo lại system prompt
    _conversationHistory.add({
      'role': 'user',
      'parts': 'Bạn là một AI Assistant thông minh và hữu ích. Hãy trả lời bằng tiếng Việt một cách tự nhiên, thân thiện và chuyên nghiệp. Bạn có thể giúp về công việc, soạn email, tìm kiếm thông tin và giải đáp thắc mắc.'
    });
    _conversationHistory.add({
      'role': 'model',
      'parts': 'Chào bạn! Tôi là AI Assistant. Tôi sẵn sàng hỗ trợ bạn về công việc, soạn email, tìm kiếm thông tin và giải đáp mọi thắc mắc. Bạn cần tôi giúp gì hôm nay?'
    });
  }

  /// Lấy số lượng tin nhắn trong lịch sử
  int get historyLength => _conversationHistory.length;

  /// Kiểm tra trạng thái API key
  bool get hasValidApiKey => _apiKey != 'AIzaSyC378JozS2zurbB5a8PbWqSP_H8EuNdc0o' && _apiKey.isNotEmpty;
}