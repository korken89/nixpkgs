{
  stdenv,
  fetchFromGitHub,
  lib,
  cmake,
  pkg-config,
  openjdk,
  libuuid,
  python3,
  glfw,
  yosys,
  nextpnr,
  verilator,
  dfu-util,
  icestorm,
  trellis,
  unstableGitUpdater,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "silice";
  version = "0-unstable-2025-03-05";

  src = fetchFromGitHub {
    owner = "sylefeb";
    repo = "silice";
    rev = "2d3ce939443e42b383ba1cd0392bec61e2381c99";
    hash = "sha256-o6NbJlJzhU3CmJPk1ibz2Fos2RWrxNuqv0jEHZj4tVg=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    openjdk
    glfw
  ];
  buildInputs = [
    libuuid
  ];
  propagatedBuildInputs = [
    (python3.withPackages (p: [
      p.edalize
      p.termcolor
    ]))
  ];

  postPatch = ''
    patchShebangs antlr/antlr.sh
    # use nixpkgs version
    rm -r python/pybind11
  '';

  installPhase = ''
    runHook preInstall

    make install
    mkdir -p $out
    cp -ar ../{bin,frameworks,lib} $out/

    runHook postInstall
  '';

  passthru.tests =
    let
      silice = finalAttrs.finalPackage;
      testProject =
        project:
        stdenv.mkDerivation {
          name = "${silice.name}-test-${project}";
          nativeBuildInputs = [
            silice
            yosys
            nextpnr
            verilator
            dfu-util
            icestorm
            trellis
          ];
          src = "${silice.src}/projects";
          sourceRoot = "projects/${project}";
          buildPhase = ''
            targets=()
            for target in $(cat configs | tr -d '\r') ; do
              [[ $target != Makefile* ]] || continue
              make $target ARGS="--no_program"
              targets+=($target)
            done
            if test "''${#targets[@]}" -eq 0; then
              >&2 echo "ERROR: no target found!"
              false
            fi
          '';
          installPhase = ''
            mkdir $out
            for target in "''${targets[@]}" ; do
              [[ $target != Makefile* ]] || continue
            done
          '';
        };
    in
    {
      # a selection of test projects that build with the FPGA tools in
      # nixpkgs
      audio_sdcard_streamer = testProject "audio_sdcard_streamer";
      bram_interface = testProject "bram_interface";
      blinky = testProject "blinky";
      pipeline_sort = testProject "pipeline_sort";
    };

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    description = "Open source language that simplifies prototyping and writing algorithms on FPGA architectures";
    homepage = "https://github.com/sylefeb/Silice";
    license = lib.licenses.bsd2;
    mainProgram = "silice";
    maintainers = with lib.maintainers; [
      astro
      pbsds
    ];
    platforms = lib.platforms.all;
  };
})
