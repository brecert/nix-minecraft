# This file is part of nix-minecraft.

# nix-minecraft is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# nix-minecraft is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with nix-minecraft.  If not, see <https://www.gnu.org/licenses/>.

{ pkgs, lib ? pkgs.lib }@inputs:
let
  inherit (import ./minecraft.nix inputs) getMc minecraftFromPkg;
  inherit (import ./common.nix inputs) mergePkgs fixOldPkg;
in
{ version, mcSha1, hash, mods ? [ ], extraGamedirFiles ? null }:
let
  installer = pkgs.fetchurl {
    url = "https://maven.minecraftforge.net/net/minecraftforge/forge/${version}/forge-${version}-installer.jar";
    inherit hash;
  };

  forgeJar = pkgs.runCommand "forge.jar" { } ''
    ${pkgs.jre}/bin/java -jar ${installer} --extract
    cp *.jar $out
  '';
  pkg =
    let
      versionJsonFile = pkgs.runCommand "forge-version.json" { } ''
        files="$(${pkgs.unzip}/bin/unzip -Z -1 ${installer})"
        if [[ "$files" =~ "version.json" ]]
        then
          ${pkgs.unzip}/bin/unzip -p ${installer} version.json > $out
        else
          f=$(echo "$files" | grep -o '^forge-.\+-universal\.jar$')
          if [[ -n "$f" ]]
          then
            ${pkgs.unzip}/bin/unzip ${installer} "$f"
            ${pkgs.unzip}/bin/unzip -p "$f" version.json > $out
          else
            echo "error: version.json cannot be found" >&2
            false
          fi
        fi
      '';
      forge = fixOldPkg (builtins.fromJSON (builtins.readFile versionJsonFile));
      mc = getMc { version = forge.inheritsFrom; sha1 = mcSha1; };
    in
    mergePkgs [ forge mc ];
in
minecraftFromPkg {
  inherit pkg;
  extraJars = [ forgeJar ];
  extraGamedirFiles = pkgs.symlinkJoin {
    name = "extra-gamedir";
    paths =
      lib.optional (extraGamedirFiles != null) extraGamedirFiles
      ++ [
        (
          pkgs.linkFarm
            "mods"
            (map (m: { name = "mods/${m.name}"; path = m; }) mods)
        )
      ];
  };
}
