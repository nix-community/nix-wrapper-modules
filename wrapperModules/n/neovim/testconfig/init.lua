vim.g.main_init_test_ran = 1
print("HELLO FROM INIT_MAIN")

if require(vim.g.nix_info_plugin_name)(false, "info", "enabledSpecs", "propagatedLuaDepsTest") then
    print("testing propagated lua env dependencies from nixpkgs")
    assert_call(require, 'jsregexp')
    print("propagated lua env test successful")
end
