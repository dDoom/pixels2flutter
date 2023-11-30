import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:result_dart/result_dart.dart';

import 'use_case.dart';

@injectable
class GenerateCodeFromImageUseCase implements StreamUseCase<GenerateCodeFromImageUseCaseParams, String, Exception> {
  const GenerateCodeFromImageUseCase(this._chatOpenAI);

  final ChatOpenAI _chatOpenAI;

  @override
  Stream<Result<String, Exception>> call({
    required final GenerateCodeFromImageUseCaseParams params,
  }) async* {
    try {
      final chatModel = _chatOpenAI.bind(
        const ChatOpenAIOptions(
          model: 'gpt-4-vision-preview',
          maxTokens: 4096,
          temperature: 0,
        ),
      );
      final chain = chatModel.pipe(const StringOutputParser());

      final imageBase64 = _convertImageToBase64(params.image);
      final additionalInstructions = params.additionalInstructions;
      final prompt = PromptValue.chat([
        ChatMessage.system(_systemPrompt),
        ChatMessage.human(
          ChatMessageContent.multiModal([
            ChatMessageContent.image(
              url: imageBase64,
              imageDetail: ChatMessageContentImageDetail.high,
            ),
            if (additionalInstructions != null) ChatMessageContent.text(additionalInstructions),
            ChatMessageContent.text(_userPrompt),
          ]),
        ),
      ]);

      final stream = chain.stream(prompt);

      yield* stream.map(Result.success);
    } on Exception catch (e) {
      yield Result.failure(e);
    }
  }

  String _convertImageToBase64(final Uint8List image) {
    return 'data:image/jpeg;base64,${base64Encode(image)}';
  }
}

class GenerateCodeFromImageUseCaseParams {
  const GenerateCodeFromImageUseCaseParams({
    required this.image,
    this.additionalInstructions,
  });

  final Uint8List image;
  final String? additionalInstructions;
}

const _systemPrompt = '''
You are an expert developer specialized in implementing Flutter apps using Dart. 

I will provide you with an image of a reference design and some instructions and it will be your job to implement the corresponding app using Flutter and Dart.

Pay close attention to background color, text color, font size, font family, padding, margin, border, etc. in the design. If it contains text, use the exact text in the design.

For images, use placeholder images from https://placehold.co and include a detailed description of the image in a `description` query parameter so that an image generation AI can generate the image later (e.g. https://placehold.co/40x40?description=An%20image%20of%20a%20cat).

Try your best to figure out what the designer and product owner want and make it happen. If there are any questions or underspecified features, use what you know about applications, user experience, and app design patterns to "fill in the blanks". If you're unsure of how the designs should work, take a guess—it's better for you to get it wrong than to leave things incomplete.

Technical details:
- Use Dart with null safety
- Variables that are initialized later should be declared as `late` (e.g. `late AnimationController controller;`)
- Mind that context can be accessed during `initState`, if you need it wrap the code with `Future.microtask(() => ...)` to be able to access it.
- If you need to assign an `int` to a `double` variable use `toDouble()` 
- Use Material 3
- Set debugShowCheckedModeBanner to false in MaterialApp
- Use only official Flutter packages unless otherwise specified

RETURN ONLY THE CODE FOR THE `main.dart` FILE. Don't include any explanations or commets.

Remember: you love your designers and POs and want them to be happy. The more complete and impressive your app, the happier they will be. Let's think step by step. Good luck, you've got this!`''';

const _userPrompt = '''
Here are the latest designs. 

Implement a new Flutter app based on these designs and instructions.''';
