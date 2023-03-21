{ stdenv
, fetchFromGitHub
, lib
, rustPlatform
, IOKit
, Security
, AppKit
, pkg-config
, udev
, zlib
, protobuf
, perl
, validatorOnly ? false
# Taken from https://github.com/solana-labs/solana/blob/master/scripts/cargo-install-all.sh#L84
, solanaPkgs ? [
    "solana"
    "solana-bench-tps"
    "solana-faucet"
    "solana-gossip"
    "solana-install"
    "solana-keygen"
    "solana-ledger-tool"
    "solana-log-analyzer"
    "solana-net-shaper"
    "solana-sys-tuner"
    "solana-validator"
    "rbpf-cli"
] ++ (lib.optionals (!validatorOnly) [
    "cargo-build-bpf"
    "cargo-test-bpf"
    "solana-dos"
    "solana-install-init"
    "solana-stake-accounts"
    "solana-test-validator"
    "solana-tokens"
    "solana-watchtower"

    # Not yet available on mainnet
    # "cargo-test-sbf"
    # "cargo-build-sbf"
]) ++ [
    # XXX: Ensure `solana-genesis` is built LAST!
    # See https://github.com/solana-labs/solana/issues/5826
    "solana-genesis"
  ]
}:
let
  pinData = lib.importJSON ./pin.json;
  version = pinData.version;
  sha256 = pinData.sha256;
  cargoSha256 = pinData.cargoSha256;
in
rustPlatform.buildRustPackage rec {
  pname = "solana-cli";
  inherit version cargoSha256;

  src = fetchFromGitHub {
    owner = "solana-labs";
    repo = "solana";
    rev = "v${version}";
    inherit sha256;
  };

  verifyCargoDeps = true;
  cargoBuildFlags = builtins.map (n: "--bin=${n}") solanaPkgs;


  nativeBuildInputs = [ pkg-config protobuf perl ];
  buildInputs = lib.optionals stdenv.isLinux [ udev zlib ]
                ++ lib.optionals stdenv.isDarwin [ IOKit Security AppKit ];

  # check phase fails
  # on darwin with missing framework System. This framework is not available in nixpkgs
  # on linux with some librocksdb-sys compilation error
  doCheck = false;

  # all the following are needed for the checkphase
  # nativeCheckInputs = lib.optionals stdenv.isDarwin [ pkg-config rustfmt ];
  # Needed to get openssl-sys to use pkg-config.
  # OPENSSL_NO_VENDOR = 1;
  # OPENSSL_LIB_DIR = "${lib.getLib openssl}/lib";
  # OPENSSL_DIR="${lib.getDev openssl}";
  # LLVM_CONFIG_PATH="${llvm}/bin/llvm-config";
  # LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib";
  # Used by build.rs in the rocksdb-sys crate. If we don't set these, it would
  # try to build RocksDB from source.
  # ROCKSDB_INCLUDE_DIR="${rocksdb}/include";
  # ROCKSDB_LIB_DIR="${rocksdb}/lib";

  meta = with lib; {
    description = "Web-Scale Blockchain for fast, secure, scalable, decentralized apps and marketplaces.";
    homepage = "https://solana.com";
    license = licenses.asl20;
    maintainers = with maintainers; [ happysalada ];
    platforms = platforms.unix;
  };
  passthru.updateScript = ./update.sh;
}
