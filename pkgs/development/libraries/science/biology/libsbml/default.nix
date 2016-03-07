{
  stdenv,
  fetchurl,
  cmake,
  libxml2,
  python ? false
#  shared ? false
}:
let
#  atlasMaybeShared = if atlas != null then atlas.override { inherit shared; }
#                     else null;
#  usedLibExtension = if shared then ".so" else ".a";
#  inherit (stdenv.lib) optional optionals concatStringsSep;
#  inherit (builtins) hasAttr attrNames;
  inherit (stdenv.lib) optional optionals;
  version = "5.12.0";
in

stdenv.mkDerivation rec {
  name = "libSBML-${version}";
  src = fetchurl {
    #url = "https://sourceforge.net/projects/sbml/files/libsbml/5.12.0/stable/libSBML-5.12.0-core-plus-packages-src.tar.gz";
    url = "mirror://sourceforge/sbml/${name}-core-plus-packages-src.tar.gz";
    sha256 = "c637494b19269947fc90ebe479b624d36f80d1cb5569e45cd76ddde81dd28ae4";
  };

  propagatedBuildInputs = [ libxml2 ];
  buildInputs = [ cmake ];
  nativeBuildInputs = [ ]
  ++ (optionals (python == true) [ python ]);

  cmakeFlags = [ "-DLIBXML_INCLUDE_DIR=${libxml2}/include/libxml2" ]
  ++ (optionals (python == true) [
    "-DWITH_PYTHON=true"
  ])
  # If we're on darwin, CMake will automatically detect impure paths. This switch
  # prevents that.
  ++ (optional stdenv.isDarwin "-DCMAKE_OSX_SYSROOT:PATH=''")
  ;

  # doCheck = ! shared;

  # checkPhase = "
  #   sed -i 's,^#!.*,#!${python}/bin/python,' lapack_testing.py
  #   ctest
  # ";

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    inherit version;
    description =
      "A library to help you read, write, manipulate, translate, and
      validate SBML files and data streams";
    homepage = "http://sbml.org/Software/libSBML";
    license = licenses.lgpl21;

    platforms = platforms.all;
  };
}
