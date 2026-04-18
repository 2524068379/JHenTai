version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)
opt_level=${1:-${FLUTTER_OPT_LEVEL:-3}}

if [ "$opt_level" != "2" ] && [ "$opt_level" != "3" ]; then
  echo "Usage: $0 [2|3]"
  echo "Or set FLUTTER_OPT_LEVEL=2|3"
  exit 1
fi

flutter build apk -t lib/src/main.dart --split-per-abi \
  --extra-gen-snapshot-options=--optimization_level=${opt_level} \
&& cp build/app/outputs/apk/release/app-arm64-v8a-release.apk ~/Desktop/JHenTai-${version}-arm64-v8a.apk \
&& cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk ~/Desktop/JHenTai-${version}-armeabi-v7a.apk \
&& cp build/app/outputs/apk/release/app-x86_64-release.apk ~/Desktop/JHenTai-${version}-x86_64.apk \
