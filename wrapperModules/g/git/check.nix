{
  pkgs,
  self,
  ...
}:

let
  gitWrapped = self.wrappers.git.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
      credential.helper = [
        "git-credential-libsecret"
        "!gh auth git-credential"
      ];
    };
  };

in
pkgs.runCommand "git-test" { } ''
  "${gitWrapped}/bin/git" config user.name | grep -q "Test User"
  "${gitWrapped}/bin/git" config user.email | grep -q "test@example.com"
  "${gitWrapped}/bin/git" config get --all credential.helper | grep -q "git-credential-libsecret"
  "${gitWrapped}/bin/git" config credential.helper | grep -q "!gh auth git-credential"
  touch $out
''
