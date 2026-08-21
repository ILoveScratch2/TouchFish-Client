# Maintainer: JohnChiao75 <JohnChiao75@users.noreply.github.com>
pkgname=touchfish-client-bin
pkgver=0.0.1
pkgrel=1
pkgdesc="TouchFish LAN chat client (prebuilt Flutter binary)"
arch=('x86_64')
url="https://github.com/ILoveScratch2/TouchFish-Client"
license=('AGPL-3.0-only')
depends=('gtk3' 'alsa-lib' 'libayatana-appindicator' 'mpv')
provides=('touchfish-client')
conflicts=('touchfish-client')
source=("$pkgname-$pkgver.zip::https://github.com/ILoveScratch2/TouchFish-Client/releases/download/$pkgver/touchfish-linux-x64.zip")
sha256sums=('2d4ad6c5addf9c3b2d0c3bda01a2a10dcf62e8e53bd732a1bd68af40718a6385')

package() {
    install -dm755 "${pkgdir}/opt/${pkgname}"
    cp -r "${srcdir}/data" "${srcdir}/lib" "${srcdir}/touchfish_client" "${pkgdir}/opt/${pkgname}/"

    install -dm755 "${pkgdir}/usr/bin"
    ln -s "/opt/${pkgname}/touchfish_client" "${pkgdir}/usr/bin/touchfish-client"

    install -Dm644 "${srcdir}/data/flutter_assets/assets/logo.png" "${pkgdir}/usr/share/pixmaps/touchfish-client.png"

    cat > "${srcdir}/touchfish-client.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TouchFish Client
Comment=FOSS multi-distribution LAN chatting tool
Exec=/usr/bin/touchfish-client
Icon=touchfish-client
Terminal=false
Categories=Network;InstantMessaging;
EOF
    install -Dm644 "${srcdir}/touchfish-client.desktop" "${pkgdir}/usr/share/applications/touchfish-client.desktop"
}
