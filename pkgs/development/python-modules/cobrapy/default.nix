{ stdenv, fetchgit, python, buildPythonPackage, cython, glpk}:
# { stdenv, python34, buildPythonPackage,
#   numpy, hdf5, cython, pkgconfig}:
  
# assert mpiSupport == hdf5.mpiSupport;
# assert mpiSupport -> mpi != null
#   && mpi4py != null
#   && mpi == mpi4py.mpi
#   && mpi == hdf5.mpi
#   ;

with stdenv.lib;

buildPythonPackage rec {
  name = "cobrapy-${version}";
  version = "0.4.0";

  src = fetchgit {
    url = "https://github.com/opencobra/cobrapy";
    sha256 = "03mrgbq11fbfbfgin1b4k4qnjl78y1sbjg3gracn2b82mrklrw0d";
    rev = "604bfb4b54a03f5613ea7a425607b77bf770794a";
  };

  configure_flags = ""; # "--hdf5=${hdf5}" + optionalString mpiSupport " --mpi";

  preConfigure = "export HOME=$TMPDIR";

  postConfigure = ''
    ${python.executable} setup.py develop --user 
  '';

  #preBuild = if mpiSupport then "export CC=${mpi}/bin/mpicc" else "";

  # buildInputs = [ hdf5 cython pkgconfig ]
  #   ++ optional mpiSupport mpi
  #   ;
  buildInputs = [cython glpk];

  # propagatedBuildInputs = [ numpy six]
  #   ++ optional mpiSupport mpi4py
  #   ;

  meta = {
    description =
      "COBRApy is a constraint-based modeling package that is designed
      to accomodate the biological complexity of the next generation
      of COBRA models and provides access to commonly used COBRA
      methods, such as flux balance analysis, flux variability
      analysis, and gene deletion analyses.";
    homepage = "http://opencobra.github.io/cobrapy/";
    license = with licenses; [ lgpl21 gpl2 ];
  };
}
