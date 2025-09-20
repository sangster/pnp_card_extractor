{
  description = "Print and Play card extractor";

  inputs = {
    nixpkgs-ruby = {
      url = github:bobvanderlinden/nixpkgs-ruby;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, flake-utils, ... }:
    let
      pname = "pnp_card_extractor";
      version = "0.1.1";
      supported-systems = [ "x86_64-linux" "aarch64-linux" ];
      ruby-version = builtins.readFile ./.ruby-version;

      for-each-system = fn:
        nixpkgs.lib.genAttrs supported-systems (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            };
          in fn system pkgs
        );
    in {
      overlays.default = final: prev:
        let
          ruby-bundle = prev.bundlerEnv {
            ruby = nixpkgs-ruby.packages.${prev.system}."ruby-${ruby-version}";
            name = pname;
            gemdir = ./.;
            gemConfig = final.defaultGemConfig // {
              poppler = attrs: {
                nativeBuildInputs = [ final.pkg-config ];
                buildInputs = [ final.poppler ];
              };
            };
          };
        in rec {
          ${pname} = prev.stdenv.mkDerivation rec {
            inherit pname version;

            src = ./.;
            passthru = {
              ruby-bundle = ruby-bundle;
              search-path = prev.lib.makeSearchPath "lib/girepository-1.0" [
                final.glib.out
                final.poppler_gi.out
              ];
            };

            installPhase = ''
              mkdir -p $out/{bin,share/${pname}}
              cp -r bin lib $out/share/${pname}
              bin=$out/bin/${pname}

              cat > $bin <<EOF
              #!/bin/sh -e
              export GI_TYPELIB_PATH="${passthru.search-path}";
              exec ${ruby-bundle.wrappedRuby}/bin/ruby \\
                       -I $out/share/${pname}/lib \\
                       $out/share/${pname}/bin/${pname} "\$@"
              EOF
              chmod +x $bin
            '';
          };
        };
      packages = for-each-system (system: pkgs: {
        default = pkgs.${pname};
        ${pname} = pkgs.${pname};
      });
      apps = for-each-system (system: pkgs: {
        console = {
          type = "app";
          program = let
            console = pkgs.writeShellScriptBin "console" ''
              export GI_TYPELIB_PATH="${pkgs.${pname}.passthru.search-path}";
              export DEBUG=1
              exec ${pkgs.${pname}.passthru.ruby-bundle}/bin/rake console
            '';
          in "${console}/bin/console";
        };
        bundler-lock = {
          type = "app";
          program = let
            script = pkgs.writeShellScriptBin "bundler-lock" ''
              ${pkgs.bundler}/bin/bundler lock && ${pkgs.bundix}/bin/bundix
            '';
          in "${script}/bin/bundler-lock";
        };
      });
      devShells = for-each-system (system: pkgs:
        let
          inherit (pkgs.${pname}.passthru) ruby-bundle search-path;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              ghostscript
              poppler
              ruby-bundle.wrappedRuby
              ruby-bundle
            ];
            env = {
              GI_TYPELIB_PATH = search-path;
            };
          };
        });
    };
}
