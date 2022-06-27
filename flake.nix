{
description = "simple node modules flake";

inputs = {};

outputs =
	{ self, nixpkgs }:
		{ lib =
			{
			mkNodeProject =
				{ system, src }:
					let
					pkgs = nixpkgs .legacyPackages .${system};
					inherit (pkgs) stdenv;
					inherit (stdenv) mkDerivation;

					inherit (pkgs) nodePackages jq;
					inherit (nodePackages) node2nix;

					node2nix-exprs = 
						mkDerivation
							{
							name = "package node2nix expressions";
							src = src;
							buildInputs = [ node2nix jq ];
							buildPhase = 
								''
								mkdir -p $out/lib

								cd "$out/lib"

								cat "$src/package.json" \
									| jq -M '{ name: "simple-node-modules", dependencies: (.dependencies // {}), devDependencies: (.devDependencies // {}), optionalDependencies: (.optionalDependencies // {}) }' \
									> ./package.json
								cp "$src/package-lock.json" ./

								node2nix --development -l package-lock.json
								'';
							dontInstall = true;
							};

					
					inherit (pkgs) callPackage;
					inherit (callPackage (import "${node2nix-exprs}/lib/default.nix") {}) nodeDependencies;


					inherit (pkgs) makeWrapper nodejs;

					simple-node-modules =
						mkDerivation
							{
							name = "simple-node-modules";
							dontUnpack = true;
							buildInputs = [ makeWrapper ];
							dontBuild = true;
							installPhase = 
								''
								mkdir -p $out
								ln -s ${nodeDependencies}/lib/node_modules $out/node_modules

								mkdir -p $out/bin

								if [ -e "${nodeDependencies}/lib/node_modules/.bin" ]; then
									find "${nodeDependencies}/lib/node_modules/.bin" -printf '%P\n' -mindepth 1 ! -type d \
									| while read bin; do
										makeWrapper "${nodeDependencies}/lib/node_modules/.bin/$bin" \
											"$out/bin/$bin" \
											--set NODE_PATH $out/node_modules 
										done ;fi

								makeWrapper ${nodejs}/bin/node $out/bin/node --set NODE_PATH $out/node_modules
								'';
							};
					in


					mkDerivation
						{
						name = "simple-node-modules";
						dontUnpack = true;
						buildInputs = [ simple-node-modules ];
						dontBuild = true;
						dontInstall = true;
						}
				;
			}; };
}
