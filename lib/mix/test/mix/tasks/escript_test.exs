Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Tasks.EscriptTest do
  use MixTest.Case

  defmodule Escript do
    def project do
      [ app: :escripttest,
        version: "0.0.1",
        escript: [
          main_module: Escripttest,
          name: "escriptest",
          embed_elixir: true
        ]
      ]
    end
  end

  defmodule EscriptWithPath do
    def project do
      [ app: :escripttestwithpath,
        version: "0.0.1",
        escript: [
          app: nil,
          embed_elixir: true,
          main_module: Escripttest,
          path: Path.join("ebin", "escripttestwithpath")
        ]
      ]
    end
  end

  defmodule EscriptWithDeps do
    def project do
      [ app: :escripttestwithdeps,
        version: "0.0.1",
        escript: [main_module: Escripttest],
        deps: [{:ok, path: fixture_path("deps_status/deps/ok")}] ]
    end
  end

  defmodule EscriptErlangWithDeps do
    def project do
      [ app: :escripttesterlangwithdeps,
        version: "0.0.1",
        language: :erlang,
        escript: [main_module: :escripttest],
        deps: [{:ok, path: fixture_path("deps_status/deps/ok")}] ]
    end
  end

  defmodule EscriptConsolidated do
    def project do
      [ app: :escripttestconsolidated,
        build_embedded: true,
        version: "0.0.1",
        escript: [main_module: Escripttest] ]
    end
  end

  test "generate escript" do
    Mix.Project.push Escript

    in_fixture "escripttest", fn ->
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escriptest with MIX_ENV=dev"]}
      assert System.cmd("escript", ["escriptest"]) == {"TEST\n", 0}

      Mix.Tasks.Escript.Build.run []
      refute_received {:mix_shell, :info, ["Generated escript escriptest with MIX_ENV=dev"]}
    end
  end

  test "generate escript with config" do
    Mix.Project.push Escript

    in_fixture "escripttest", fn ->
      File.mkdir_p! "config"
      File.write! "config/config.exs", """
      [foobar: [value: "FROM CONFIG", other: %{}]]
      """
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escriptest with MIX_ENV=dev"]}
      assert System.cmd("escript", ["escriptest"]) == {"FROM CONFIG\n", 0}
    end
  end

  test "generate escript with path" do
    Mix.Project.push EscriptWithPath

    in_fixture "escripttest", fn ->
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript ebin/escripttestwithpath with MIX_ENV=dev"]}
      assert System.cmd("escript", ["ebin/escripttestwithpath"]) == {"TEST\n", 0}
    end
  end

  test "generate escript with deps" do
    Mix.Project.push EscriptWithDeps

    in_fixture "escripttest", fn ->
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escripttestwithdeps with MIX_ENV=dev"]}
      assert System.cmd("escript", ["escripttestwithdeps"]) == {"TEST\n", 0}
    end
  after
    purge [Ok.Mixfile]
  end

  test "generate escript with erlang and deps" do
    Mix.Project.push EscriptErlangWithDeps

    in_fixture "escripttest", fn ->
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escripttesterlangwithdeps with MIX_ENV=dev"]}
      assert System.cmd("escript", ["escripttesterlangwithdeps"]) == {"Erlang value", 0}
    end
  after
    purge [Ok.Mixfile]
  end

  test "generate escript with consolidated protocols" do
    Mix.Project.push EscriptConsolidated

    in_fixture "escripttest", fn ->
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escripttestconsolidated with MIX_ENV=dev"]}
      assert System.cmd("escript", ["escripttestconsolidated", "Enumerable"]) == {"true\n", 0}
    end
  end

  test "escript install and uninstall" do
    File.rm_rf! tmp_path(".mix/escripts")
    Mix.Project.push Escript

    in_fixture "escripttest", fn ->
      # build the escript
      Mix.Tasks.Escript.Build.run []
      assert_received {:mix_shell, :info, ["Generated escript escriptest with MIX_ENV=dev"]}

      # check that no escripts are installed
      Mix.Tasks.Escript.run []
      assert_received {:mix_shell, :info, ["No escripts currently installed."]}

      # install our escript
      send self, {:mix_shell_input, :yes?, true}
      Mix.Tasks.Escript.Install.run []

      # check that it shows in the list
      Mix.Tasks.Escript.run []
      assert_received {:mix_shell, :info, ["* escriptest"]}

      # check uninstall confirmation
      send self, {:mix_shell_input, :yes?, false}
      Mix.Tasks.Escript.Uninstall.run ["escriptest"]
      assert File.regular? tmp_path(".mix/escripts/escriptest")

      # uninstall the escript
      send self, {:mix_shell_input, :yes?, true}
      Mix.Tasks.Escript.Uninstall.run ["escriptest"]
      refute File.regular? tmp_path(".mix/escripts/escriptest")

      # check that no escripts remain
      Mix.Tasks.Escript.run []
      assert_received {:mix_shell, :info, ["No escripts currently installed."]}
    end
  end
end
