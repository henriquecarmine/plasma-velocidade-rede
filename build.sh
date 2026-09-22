#!/usr/bin/env bash
# Builds everything from source: catalogues, the .plasmoid for the KDE Store,
# and the source tarball the RPM spec expects.
#
# The compiled catalogues (.mo) are NOT in git — they are generated from the
# .po files here.
set -euo pipefail

ID=com.henrique.velocidaderede
DOMAIN=plasma_applet_$ID
NAME=plasma-applet-velocidade-rede
VERSION=$(python3 -c "import json;print(json.load(open('package/metadata.json'))['KPlugin']['Version'])")
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

echo "== Network Speed $VERSION =="

# 0. Recusar QML com PROPRIEDADE REPETIDA. O Qt só reclama ao CARREGAR, e aí
#    a tela vem em branco. `readonly`/`required` são prefixos válidos; o
#    `|| true` evita que um arquivo sem `property` derrube o build.
for qml in package/contents/ui/*.qml package/contents/ui/config/*.qml package/contents/config/*.qml; do
	dup=$( { grep -oP '^\s*(readonly\s+|required\s+)?property\s+\S+\s+\K\w+' "$qml" || true; } \
	      | sort | uniq -d)
	if [ -n "$dup" ]; then
		echo "ERRO: propriedade repetida em $qml:" >&2
		printf '  %s\n' $dup >&2
		exit 1
	fi
done

# 1. Refresh the template from the source — every .qml that shows text.
xgettext --from-code=UTF-8 --language=JavaScript \
	--keyword=i18nd:2 --keyword=i18ndp:2,3 \
	--package-name="Network Speed" --package-version="$VERSION" \
	-o po/plasma_applet.pot \
	package/contents/ui/*.qml package/contents/ui/config/*.qml package/contents/config/*.qml

# 2. Compile each catalogue INTO the package, and refuse to ship a broken one.
rm -rf package/contents/locale
for po in po/*.po; do
	lang=$(basename "$po" .po)
	dir="package/contents/locale/$lang/LC_MESSAGES"
	mkdir -p "$dir"
	msgfmt --check --statistics -o "$dir/$DOMAIN.mo" "$po"
done

# 3. The .plasmoid for the KDE Store — a plain zip of the package.
mkdir -p dist
rm -f dist/velocidade-rede.plasmoid
( cd package && cp ../LICENSE ../README.md . 2>/dev/null || true
  zip -qr ../dist/velocidade-rede.plasmoid . -x '.*' )
rm -f package/LICENSE package/README.md

# 4. The source tarball for rpmbuild: <name>-<version>/<plasmoid_id>/...
rm -rf "dist/$NAME-$VERSION"
mkdir -p "dist/$NAME-$VERSION/$ID"
cp -a package/. "dist/$NAME-$VERSION/$ID/"
cp LICENSE README.md "dist/$NAME-$VERSION/$ID/"
( cd dist && tar -czf "$NAME-$VERSION.tar.gz" "$NAME-$VERSION" )
rm -rf "dist/$NAME-$VERSION"

echo
echo "dist/velocidade-rede.plasmoid                 -> KDE Store"
echo "dist/$NAME-$VERSION.tar.gz  -> ~/rpmbuild/SOURCES/ e rpmbuild -ba $NAME.spec"
