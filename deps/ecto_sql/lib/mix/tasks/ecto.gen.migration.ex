defmodule Mix.Tasks.Ecto.Gen.Migration do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator
  import Mix.Ecto
  import Mix.EctoSQL

  @shortdoc "Generates a new migration for the repo"

  @moduledoc """
  Generates a migration.

  The repository must be set under `:ecto_repos` in the
  current app configuration or given via the `-r` option.

  ## Examples

      mix ecto.gen.migration add_posts_table
      mix ecto.gen.migration add_posts_table -r Custom.Repo

  The generated migration filename will be prefixed with the current
  timestamp in UTC which is used for versioning and ordering.

  By default, the migration will be generated to the
  "priv/YOUR_REPO/migrations" directory of the current application
  but it can be configured to be any subdirectory of `priv` by
  specifying the `:priv` key under the repository configuration.

  This generator will automatically open the generated file if
  you have `ECTO_EDITOR` set in your environment variable.

  ## Command line options

    * `-r`, `--repo` - the repo to generate migration for

  """

  @switches [change: :string]

  @impl true
  def run(args) do
    no_umbrella!("ecto.gen.migration")
    repos = parse_repo(args)

    Enum.map repos, fn repo ->
      case OptionParser.parse(args, switches: @switches) do
        {opts, [name], _} ->
          ensure_repo(repo, args)
          path = Path.join(source_repo_priv(repo), "migrations")
          base_name = "#{underscore(name)}.exs"
          file = Path.join(path, "#{timestamp()}_#{base_name}")
          unless File.dir?(path), do: create_directory path

          fuzzy_path = Path.join(path, "*_#{base_name}")
          if Path.wildcard(fuzzy_path) != [] do
            Mix.raise "migration can't be created, there is already a migration file with name #{name}."
          end

          assigns = [mod: Module.concat([repo, Migrations, camelize(name)]), change: opts[:change]]
          create_file file, migration_template(assigns)

          if open?(file) and Mix.shell.yes?("Do you want to run this migration?") do
            Mix.Task.run "ecto.migrate", ["-r", inspect(repo)]
          end

          file

        {_, _, _} ->
          Mix.raise "expected ecto.gen.migration to receive the migration file name, " <>
                    "got: #{inspect Enum.join(args, " ")}"
      end
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  embed_template :migration, """
  defmodule <%= inspect @mod %> do
    use Ecto.Migration

    def change do
  <%= @change %>
    end
  end
  """
end
