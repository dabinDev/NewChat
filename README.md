# NewChatBox

NewChatBox is a native Flutter Android chat client for user-configured
OpenAI-compatible and Claude-compatible gateways. It is designed for self-hosted
API relay services such as New API, sub2api, one-api style gateways, and private
OpenAI/Claude proxy endpoints.

中文：NewChatBox 是一个原生 Flutter Android 聊天客户端，面向自建中转平台和私有
API 网关，支持 OpenAI 兼容协议和 Claude 兼容协议，适合连接 New API、sub2api 等服务。

## Keywords

`flutter` `android` `chatgpt` `openai` `claude` `newapi` `sub2api`
`openai-compatible` `claude-compatible` `ai-chat` `image-chat`
`self-hosted-gateway` `api-proxy`

## Features

- OpenAI Chat Completions compatible protocol
- Claude Messages compatible protocol
- Streaming text responses
- Text chat, image chat, image generation display, and image viewer
- Local multi-session history with pin, unread, delete, and rename actions
- Per-session model switching and system prompt
- Reply/quote message context, including quoted image thumbnails
- Automatic compact context summary for longer conversations
- Provider editor with saved base URL, saved API key state, model fetching, and connection test
- Chinese and English UI

## Android Package

- Package name: `cn.cylonai.newchat`
- App version: `1.0.0+1`
- Release tag: `v1.0.0`

## Quick Start

1. Download or build the APK.
2. Open NewChatBox on Android.
3. Add a provider:
   - Protocol: OpenAI or Claude
   - Base URL: your gateway URL, for example `https://your-gateway.example.com`
   - API key: your own gateway key
4. Fetch or add models, then start a new chat.

Do not commit real API keys to this repository. Configure keys only inside the
app or your private deployment environment.

## Build From Source

```powershell
flutter pub get
flutter test
flutter build apk --debug
```

After a successful debug build, the APK is available at:

`build/app/outputs/flutter-apk/app-debug.apk`

## Development

```powershell
flutter analyze
flutter test
flutter run
```

## Version 1.0.0 Scope

This first release focuses on Android and two gateway protocols: OpenAI
compatible chat/image workflows and Claude compatible chat/image workflows.
Desktop, iOS, voice input, cloud sync, and marketplace distribution are outside
the 1.0.0 scope.
