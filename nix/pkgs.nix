{ pkgs ? import ./pinned-21.05.nix {} }:

rec {
  inherit pkgs;
  ghc = pkgs.haskell.compiler.ghc8104;
  hsBuildInputs = [
    ghc
    pkgs.cabal-install
  ];
  nonhsBuildInputs = with pkgs; [
    bzip2
    docker-compose
    git
    gmp
    gsl
    #haskell-language-server
    hlint
    igraph
    liblapack
    lzma
    pcre
    pkgconfig
    postgresql
    xz
    zlib
    blas
    gfortran7
    #    gfortran7.cc.lib
    expat
    icu
  ];
  libPaths = pkgs.lib.makeLibraryPath nonhsBuildInputs;
  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.gfortran7.cc.lib}:${libPaths}:$LD_LIBRARY_PATH"
    export LIBRARY_PATH="${pkgs.gfortran7.cc.lib}:${libPaths}"
  '';
  shell = pkgs.mkShell {
    name = "gargantext-shell";
    buildInputs = hsBuildInputs ++ nonhsBuildInputs;
    inherit shellHook;
  };
}
