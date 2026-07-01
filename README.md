# AI Chess Arena

A Flutter Android app that lets you pick two OpenRouter AI models and watch
them play chess against each other.

## How it works

- On the home screen you pick a model for White and a model for Black
  (loaded from the OpenRouter `/models` endpoint).
- The game screen drives a loop: for each move it sends the current FEN
  plus the list of legal moves to the model whose turn it is and asks
  for a single move (UCI or SAN).
- The response is parsed and validated against the legal move list. If
  the model returns nonsense twice, we play a fallback move so the game
  doesn't stall (marked in the log with a warning icon).
- The board, move log, and status bar update after each ply.

## Setup

You need your own OpenRouter API key.

1. Create a key at https://openrouter.ai/keys
2. Install the APK on your Android device.
3. Open the app, tap the ⚙ icon, paste your key, save. The key is stored
   in EncryptedSharedPreferences — it never leaves the device except
   when calling OpenRouter.

## Build

APKs are produced automatically by the GitHub Actions workflow at
`.github/workflows/build-apk.yml` on every push. Grab them from the
workflow run's Artifacts section:

- `ai-chess-arena-apk-universal` — one APK that runs on any Android
  ABI. Simplest, biggest.
- `ai-chess-arena-apk-split` — smaller per-ABI APKs
  (`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`,
  `app-x86_64-release.apk`). Install the one that matches your device.

To trigger a build manually, use the "Run workflow" button on the
Actions tab (workflow_dispatch is enabled).

### Building locally

If you have Flutter installed:

```bash
flutter pub get
flutter create --platforms=android .   # first time only
flutter build apk --release
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`.

## Notes

- Model quality varies a lot at chess. Smaller / cheaper models will
  frequently emit illegal moves and get a fallback move played for them.
- Move requests use `max_tokens=16` and `temperature<=0.2` to keep
  responses short and deterministic. Costs stay small per game.
- The `chess` package is used for move generation and rules; the app
  never trusts a model's move without validating it against legal
  moves.
