{
description = "simple node modules flake";

inputs =
	{
	nix-npm-buildpackage = { url = "github:serokell/nix-npm-buildpackage"; };
	# npm 7 is broken currently?
	# https://github.com/serokell/nix-npm-buildpackage/issues/33
	npm-6-flake = { url = "github:irisjae/npm-6-flake"; };
	};

outputs =
	{ self, nix-npm-buildpackage, npm-6-flake, nixpkgs }:
		let
		mk_bare-node-modules =
			{ system, src, pkgs }:
				let
				inherit (pkgs) callPackage nodejs jq;
				bp = callPackage nix-npm-buildpackage {};
				npm-6 = npm-6-flake .defaultPackage .${system};
				in
				bp .mkNodeModules
				{
				src = src;
				# hack to override npm version
				extraEnvVars =
					{ buildInputs =
						[ npm-6 nodejs jq ]; };
				pname = "node-modules";
				version = "bare";
				packageOverrides = {};
				};
		mkNodeBins =
			{ system, src }:
				let
				pkgs = nixpkgs .legacyPackages .${system};
				inherit (pkgs) makeWrapper nodejs stdenv;
				bare-node-modules = mk_bare-node-modules { inherit system src pkgs; };
				mkDerivation_args = 
					{
					name = "node-modules";
					unpackPhase = "true";
					buildPhase = "";
					buildInputs = [ makeWrapper ];
					installPhase =
						''
						mkdir -p $out/bin
						ln -s ${bare-node-modules}/node_modules $out/node_modules
						find "${bare-node-modules}/node_modules/.bin" -printf '%P\n' -mindepth 1 ! -type d \
						| while read bin; do
							#if [ ! -e "$(dirname "$out/bin/$bin")" ] ;then
							#	mkdir -p "$(dirname "$out/bin/$bin")" ;fi
							makeWrapper "${bare-node-modules}/node_modules/.bin/$bin" "$out/bin/$bin" --set NODE_PATH $out/node_modules ;done
						makeWrapper ${nodejs}/bin/node $out/bin/node --set NODE_PATH $out/node_modules
						'';
					};
				in
				stdenv .mkDerivation (mkDerivation_args);
		mkNodeProject =
			args@{ system, src }:
				let
				pkgs = nixpkgs .legacyPackages .${system};
				inherit (pkgs) makeWrapper coreutils stdenv;
				bare-node-modules = mk_bare-node-modules { inherit system src pkgs; };
				node-project-bins = (mkNodeBins args);
				mkDerivation_args = 
					{
					name = "node-modules";
					unpackPhase = "true";
					buildPhase = "";
					buildInputs = [ makeWrapper coreutils node-project-bins ];
					installPhase = "true";
					};
				in
				stdenv .mkDerivation (mkDerivation_args);
		in
		{ lib =
			{
			mkNodeBins = mkNodeBins;
			mkNodeProject = mkNodeProject;
			}; };
}
