let
  pins = import ./npins {};
  pkgs = import pins.nixpkgs {
    overlays = [ (import pins.press) ];
  };
  zpkgs = pkgs.callPackage (pins.zpkgs + "/pkgs") {};

  vscode-ext-hook = pkgs.callPackage pins.vscode-ext-hook.outPath {};

  # until #71 lands, use our version instead
  typst-languagetool = (zpkgs.typst-languagetool.override {backends = ["server"];}).overrideAttrs {
    src = pkgs.fetchFromGitHub {
      owner = "blokyk";
      repo = "typst-languagetool";
      rev = "289aa6b1a79034874d80b41bd88ffd53849b2f4f";
      hash = "sha256-7dHDGMU5qO7WEvj2bNPkZrBVJfwpsOrsMEClZU4QQio=";
    };
  };

  document = pkgs.buildTypstDocument {
    pname = "report";
    version = "0";
    src = ./.;
    fonts = [
      pkgs.libertinus
    ];
    typstEnv = universe: with universe; [
      lilaq
    ];
  };
in
with pkgs;
mkShell {
  inputsFrom = [ document ];
  packages = [
    typst-languagetool

    vscode-ext-hook
  ];

  vscodeExtensions =
    let
      nixExts = with vscode-extensions; [
        myriad-dreamin.tinymist
      ];

      mktplcExts = vscode-utils.extensionsFromVscodeMarketplace [
        { publisher = "mjmorales"; name = "generic-lsp-proxy"; version = "2.1.2"; hash = "sha256-KvnGuf5Mjo/uCcXa7j2kt8Wx8vR72pziQridCVxEAKU="; }
      ];
    in
     nixExts ++ mktplcExts;

  env = {
    RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
  };
}
