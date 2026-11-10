{
  default = {
    path = ./flake;
    description = "An example flake wrapping a package with a module";
  };
  neovim = {
    path = ./neovim;
    description = "An example flake showing basic usage of the neovim module";
  };
  flake-parts = {
    path = ./flake-parts;
    description = "A flake using flake-parts with the provided flake-parts module";
  };
  flake-parts-example = {
    path = ./flake-parts-example;
    description = "An example flake using flake-parts with the provided flake-parts module";
  };
}
