import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BasicScreen extends StatefulWidget {
  @override
  _BasicState createState() => _BasicState();
}

class _BasicState extends State<BasicScreen> {
  bool isListening = false;
  bool isTranslate = false;
  String _currentLanguage = "English";
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    dotenv.load(fileName: ".env").then((_) {
      print("API Key: ${dotenv.env['API_KEY']}");
      _initSpeech();
      flutterTts.setLanguage("en-US");
      flutterTts.setSpeechRate(1.0);
      flutterTts.setVolume(1.0);
    });
  }

  ChatUser user1 = ChatUser(
    id: '1',
    firstName: 'me',
    lastName: 'me',
  );
  ChatUser user2 = ChatUser(
    id: '2',
    firstName: 'chatGPT',
    lastName: 'openAI',
    profileImage: "assets/img/gpt_icon.png",
  );

  late List<ChatMessage> messages = <ChatMessage>[
    ChatMessage(
      text: '반갑습니다. 어서오세요. 무엇을 도와드릴까요?',
      user: user2,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic example'),
      ),
      body: DashChat(
        currentUser: user1,
        onSend: (ChatMessage m) {
          setState(() {
            messages.insert(
              0,
              ChatMessage(
                text: m.text,
                user: isTranslate ? user2 : user1,
                createdAt: DateTime.now(),
              ),
            );
          });
          Future<String> data = sendMessageToServer(m.text);
          data.then((value) {
            setState(() {
              messages.insert(
                0,
                ChatMessage(
                  text: value,
                  user: isTranslate ? user2 : user1,
                  createdAt: DateTime.now(),
                ),
              );
            });
          });
        },
        messages: messages,
        inputOptions: InputOptions(
          leading: [
            IconButton(
              icon: Icon(
                Icons.mic,
                color: isListening ? Colors.red : Colors.black,
              ),
              onPressed: () {
                setState(() {
                  isListening = !isListening;
                  if (isListening == true) {
                    print('음성인식시작');
                    _startListening();
                  } else {
                    print('음성인식끝');
                    _stopListening();
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(
                Icons.g_translate,
                color: isTranslate ? Colors.red : Colors.black,
              ),
              onPressed: () {
                setState(() {
                  isTranslate = !isTranslate;
                  if (isTranslate == true) {
                    print('영어를 입력하거나 말하세요.');
                    flutterTts.setLanguage("ko-KR");
                  } else {
                    print('한국어를 입력하거나 말하세요.');
                    flutterTts.setLanguage("en-US");
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> sendMessageToServer(String message) async {
    await dotenv.load(fileName: ".env");
    String? apiKey = dotenv.env['API_KEY'];

    if (apiKey == null) {
      print("ERROR: API key is missing");
      return "ERROR: API key is missing";
    }

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    var request = http.Request(
      'POST',
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );
    _currentLanguage = isTranslate ? "Korean" : "English";
    request.body = json.encode({
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content":
              "you're translator, so you do not answer, only response translated message in $_currentLanguage",
        },
        {
          "role": "user",
          "content": message,
        }
      ],
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(responseString);
      String result = jsonResponse['choices'] != null
          ? jsonResponse['choices'][0]['message']['content']
          : "No result found";
      print(responseString);
      return result;
    } else {
      String errorResponse = await response.stream.bytesToString();
      print("Error response: $errorResponse");
      return "ERROR: ${response.reasonPhrase}";
    }
  }

  void _initSpeech() async {
    print("음성인식 기능을 시작합니다");
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    print("음성인식을 시작합니다.");
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: isTranslate ? "en_US" : "ko_KR",
    );
    setState(() {});
  }

  void _stopListening() async {
    print("음성인식을 종료합니다.");
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      setState(() {
        _lastWords = result.recognizedWords;
        print("최종 인식된 문장 : $_lastWords");
        messages.insert(
          0,
          ChatMessage(
            text: _lastWords,
            user: isTranslate ? user2 : user1,
            createdAt: DateTime.now(),
          ),
        );
      });
      Future<String> data = sendMessageToServer(_lastWords);
      data.then((value) {
        setState(() {
          messages.insert(
            0,
            ChatMessage(
              text: value,
              user: isTranslate ? user2 : user1,
              createdAt: DateTime.now(),
            ),
          );
        });
        flutterTts.speak(value);
      });
    }
  }
}
