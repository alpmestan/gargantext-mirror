{ pkgs ? import ./pinned-22.05.nix {} }:

let hspkgs = pkgs.haskell.packages.ghc922.extend (self: super: rec {
      cabalsrc = super.fetchFromGitHub {
        owner = "haskell";
        repo = "cabal";
        rev = "3c2da3516dc5cac224da6ceba834bb611552a246";
        sha256 = "0rs9bxxrw4wscf4a8yl776a8g880m5gcm75q06yx2cn3lw2b7v22";
      };
      Cabal = super.Cabal.override {
        src = cabalsrc + "/Cabal";
      };
      cabal-install = super.cabal-install.override {
        src = cabalsrc + "/cabal-install";
      };
    });
in
rec {
  inherit pkgs;
  ghc = pkgs.haskell.compiler.ghc922;
  hsBuildInputs = [
    ghc
    pkgs.cabal-install
  ];
  nonhsBuildInputs = with pkgs; [
    bzip2
    czmq
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
    graphviz
    llvm_12
    pkgconfig
    libffi
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
