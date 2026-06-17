{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchurl,
  fetchpatch,
  autoPatchelfHook,
  makeWrapper,
  nix-update-script,
  glibcLocales,
  python3Packages,
  dotnetCorePackages,
  gtk-sharp-3_0,
  gtk3-x11,
  dconf,
  darwin ? {},
  pango,
  cairo,
  harfbuzz,
  glib,
  freetype,
  libjpeg,
  libtiff,
  giflib,
  libpng,
  libexif,
  fontconfig,
  gettext,
}:

let
  pythonLibs =
    with python3Packages;
    makePythonPath [
      construct
      psutil
      pyyaml
      requests
      tkinter

      # from tools/csv2resd/requirements.txt
      construct

      # from tools/execution_tracer/requirements.txt
      pyelftools

      (robotframework.overrideDerivation (oldAttrs: {
        src = fetchFromGitHub {
          owner = "robotframework";
          repo = "robotframework";
          rev = "v6.1";
          hash = "sha256-l1VupBKi52UWqJMisT2CVnXph3fGxB63mBVvYdM1NWE=";
        };
        patches = (oldAttrs.patches or [ ]) ++ [
          (fetchpatch {
            # utest: Improve filtering of output sugar for Python 3.13+
            name = "python3.13-support.patch";
            url = "https://github.com/robotframework/robotframework/commit/921e352556dc8538b72de1e693e2a244d420a26d.patch";
            hash = "sha256-aSaror26x4kVkLVetPEbrJG4H1zstHsNWqmwqOys3zo=";
          })
        ];
      }))
    ];

  darwinSrc = fetchurl {
    url = "https://builds.renode.io/renode-latest.osx-arm64-portable.dmg";
    hash = "sha256-qHadrwf/jX37p415TVx4NEiusfGP4KT6cgty7F4tu5U=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "renode";
  version = "1.16.1";

  src =
    if stdenv.hostPlatform.isDarwin then
      darwinSrc
    else
      fetchurl {
        url = "https://github.com/renode/renode/releases/download/v${finalAttrs.version}/renode-${finalAttrs.version}.linux-dotnet.tar.gz";
        hash = "sha256-YmKcqjMe1L1Ot6vhPuLkg0+8qnDeSS2zll+vpO3FaU8=";
      };

  nativeBuildInputs =
    if stdenv.hostPlatform.isDarwin then
      [ makeWrapper ]
    else
      [
        autoPatchelfHook
        makeWrapper
      ];

  # DMG is APFS-formatted; undmg only handles HFS. Use hdiutil (macOS system tool).
  unpackPhase = lib.optionalString stdenv.hostPlatform.isDarwin ''
    mnt=$(mktemp -d)
    /usr/bin/hdiutil attach "$src" -mountpoint "$mnt" -nobrowse -quiet
    # Use ditto to preserve macOS extended attributes and code signatures
    /usr/bin/ditto "$mnt/Renode.app" Renode.app
    /usr/bin/hdiutil detach "$mnt" -quiet
    chmod -R u+w Renode.app
  '';

  propagatedBuildInputs = lib.optionals (!stdenv.hostPlatform.isDarwin) [
    gtk-sharp-3_0
  ];

  strictDeps = true;

  # strip corrupts .NET single-file bundles (removes embedded assembly sections)
  dontStrip = true;

  # undmg unpacks into CWD; the app is at Renode.app/Contents/MacOS/
  installPhase =
    if stdenv.hostPlatform.isDarwin then
      ''
        runHook preInstall

        mkdir -p $out/{bin,Applications}
        cp -r Renode.app $out/Applications/

        # CLI wrapper: run the binary directly (headless/console mode)
        makeWrapper "$out/Applications/Renode.app/Contents/MacOS/renode" "$out/bin/renode" \
          --prefix PYTHONPATH : "${pythonLibs}"

        makeWrapper "$out/Applications/Renode.app/Contents/MacOS/renode-test" "$out/bin/renode-test" \
          --prefix PYTHONPATH : "${pythonLibs}"

        # GUI wrapper: use the native GUI binary
        makeWrapper "$out/Applications/Renode.app/Contents/MacOS/renode-ui" "$out/bin/renode-gui" \
          --prefix PYTHONPATH : "${pythonLibs}"

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/{bin,libexec/renode}

        mv * $out/libexec/renode
        mv .renode-root $out/libexec/renode

        makeWrapper "$out/libexec/renode/renode" "$out/bin/renode" \
          --prefix PATH : "$out/libexec/renode:${lib.makeBinPath [ dotnetCorePackages.runtime_8_0 ]}" \
          --prefix GIO_EXTRA_MODULES : "${lib.getLib dconf}/lib/gio/modules" \
          --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ gtk3-x11 ]}" \
          --prefix PYTHONPATH : "${pythonLibs}" \
          --set LOCALE_ARCHIVE "${glibcLocales}/lib/locale/locale-archive"
        makeWrapper "$out/libexec/renode/renode-test" "$out/bin/renode-test" \
          --prefix PATH : "$out/libexec/renode:${lib.makeBinPath [ dotnetCorePackages.runtime_8_0 ]}" \
          --prefix GIO_EXTRA_MODULES : "${lib.getLib dconf}/lib/gio/modules" \
          --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ gtk3-x11 ]}" \
          --prefix PYTHONPATH : "${pythonLibs}" \
          --set LOCALE_ARCHIVE "${glibcLocales}/lib/locale/locale-archive"

        substituteInPlace "$out/libexec/renode/renode-test" \
          --replace '$PYTHON_RUNNER' '${python3Packages.python}/bin/python3'

        runHook postInstall
      '';

  passthru.updateScript = nix-update-script { };

  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    local gdiplus="$out/Applications/Renode.app/Contents/MacOS/libgdiplus.dylib"
    if [ -f "$gdiplus" ]; then
      # Fix the library's own install name
      install_name_tool -id "$gdiplus" "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/pango/lib/libpangocairo-1.0.0.dylib ${pango.out}/lib/libpangocairo-1.0.0.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/pango/lib/libpango-1.0.0.dylib ${pango.out}/lib/libpango-1.0.0.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/cairo/lib/libcairo.2.dylib ${cairo.out}/lib/libcairo.2.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/harfbuzz/lib/libharfbuzz.0.dylib ${harfbuzz.out}/lib/libharfbuzz.0.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/glib/lib/libgobject-2.0.0.dylib ${glib.out}/lib/libgobject-2.0.0.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/glib/lib/libglib-2.0.0.dylib ${glib.out}/lib/libglib-2.0.0.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/gettext/lib/libintl.8.dylib ${gettext.out}/lib/libintl.8.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/freetype/lib/libfreetype.6.dylib ${freetype.out}/lib/libfreetype.6.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib ${libjpeg.out}/lib/libjpeg.8.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/libtiff/lib/libtiff.6.dylib ${libtiff.out}/lib/libtiff.6.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/giflib/lib/libgif.dylib ${giflib.out}/lib/libgif.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/libpng/lib/libpng16.16.dylib ${libpng.out}/lib/libpng16.16.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/libexif/lib/libexif.12.dylib ${libexif}/lib/libexif.12.dylib "$gdiplus"
      install_name_tool -change /opt/homebrew/opt/fontconfig/lib/libfontconfig.1.dylib ${fontconfig.lib}/lib/libfontconfig.1.dylib "$gdiplus"
    fi

    # Ad-hoc codesign: renode-ui links WebKit and macOS SIGKILL's unsigned WebKit consumers
    /usr/bin/codesign --force --sign - --deep "$out/Applications/Renode.app"
  '';

  meta = {
    description = "Virtual development framework for complex embedded systems";
    homepage = "https://renode.io";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [
      otavio
      znaniye
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
