#!/usr/bin/env bash
#
# 生成本地 release 签名配置
#

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KEY_DIR=${KEY_DIR:-/d/AndroidKey}
SRC_KEYSTORE=${KEYSTORE_FILE:-$KEY_DIR/ils-release-key.keystore}

: "${KEYSTORE_PASSWORD:?need environment variable KEYSTORE_PASSWORD for wxh（keystore 密码）}"
KEY_ALIAS=${KEY_ALIAS:-key}
KEY_PASSWORD=${KEY_PASSWORD:-$KEYSTORE_PASSWORD}

if [ ! -f "$SRC_KEYSTORE" ]; then
    echo "wxh cannot find keystore: $SRC_KEYSTORE" >&2
    exit 1
fi

DEST_KEYSTORE="$REPO_ROOT/android/app/release.jks"
DEST_PROPERTIES="$REPO_ROOT/android/key.properties"

if command -v keytool > /dev/null 2>&1; then
    if ! keytool -certreq -alias "$KEY_ALIAS" -keystore "$SRC_KEYSTORE" \
        -storepass "$KEYSTORE_PASSWORD" -keypass "$KEY_PASSWORD" -file /dev/null > /dev/null 2>&1; then
        echo "wxh keystore validation failed: password or alias ($KEY_ALIAS) is incorrect" >&2
        exit 1
    fi
else
    echo "wxh cannot find keytool, skipping keystore validation" >&2
fi

umask 077
cp "$SRC_KEYSTORE" "$DEST_KEYSTORE"
cat > "$DEST_PROPERTIES" <<EOF
storeFile=release.jks
storePassword=$KEYSTORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
EOF

echo "wxh generated signing files, what a good girl! :"
echo "  $DEST_KEYSTORE"
echo "  $DEST_PROPERTIES"
echo "next: ask wyf to run flutter build apk --release , it will use the official signing."
