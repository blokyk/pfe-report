let
  pins = import ./npins {};
  pkgs = import pins.nixpkgs {
    overlays = [ (import pins.press) ];
  };
  vscode-ext-hook = pkgs.callPackage pins.vscode-ext-hook.outPath {};

  document = pkgs.buildTypstDocument {
    pname = "report";
    version = "0";
    src = ./.;
    fonts = [
      pkgs.libertinus
    ];
    typstEnv = universe: with universe; [
    ];
  };
in
with pkgs;
mkShell {
  inputsFrom = [ document ];
  packages = [
    vscode-ext-hook
  ];

  vscodeExtensions =
    let
      nixExts = with vscode-extensions; [
        myriad-dreamin.tinymist
      ];

      mktplcExts = vscode-utils.extensionsFromVscodeMarketplace [
      ];
    in
     nixExts ++ mktplcExts;

  env = {
    RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
  };
}
