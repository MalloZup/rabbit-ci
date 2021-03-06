defmodule BuildMan.Worker do
  alias BuildMan.FileHelpers
  alias BuildMan.Worker
  alias BuildMan.LogStreamer
  alias RabbitCICore.{Repo, Build, Job, Step}
  alias RabbitCICore.RecordPubSubChannel, as: PubSub

  @moduledoc """
  The BuildMan.Worker module provides functions to interact with the
  BuildMan.Worker struct.

  The BuildMan.Worker struct is used to configure a build, _a la_
  Ecto.Changeset. The goal is to better manage build files and Vagrantfile
  generation.
  """

  defstruct [build_id: nil,
             step_id: nil,
             job_id: nil,
             provider: nil,
             # Path to working directory for worker.
             path: nil,
             # Callbacks are called through trigger_event/2
             callbacks: nil,
             log_handler: :not_implemented,
             # Configuration to be passed to the provider.
             provider_config: nil,
             files: []]

  @doc """
  Create a %Worker{}. Args is a map that will be merged with the default worker
  values. The worker's path field may not be overridden.
  """
  def create(args), do: Map.merge create, Map.drop(args, [:path])
  def create do
    %Worker{path: FileHelpers.unique_folder!("worker"),
            callbacks: default_callbacks}
  end

  @doc """
  Deletes the Worker directory.
  """
  def cleanup!(worker) do
    with {:ok, _files} = File.rm_rf(worker.path) do
      :ok
    end
  end

  @events [:running, :finished, :failed, :error]

  # Generates the default callbacks for workers. This is used in create/0.
  defp default_callbacks do
    %{
      running: (fn worker ->
        Worker.get_job(worker)
        |> Job.changeset(%{start_time: Ecto.DateTime.utc, status: "running"})
        |> Repo.update!
        pubsub_update_build(worker)
        {:ok, worker}
      end),
      finished: (fn worker ->
        Worker.get_job(worker)
        |> Job.changeset(%{finish_time: Ecto.DateTime.utc, status: "finished"})
        |> Repo.update!
        pubsub_update_build(worker)
        {:ok, worker}
      end),
      failed: (fn worker ->
        Worker.get_job(worker)
        |> Job.changeset(%{finish_time: Ecto.DateTime.utc, status: "failed"})
        |> Repo.update!
        pubsub_update_build(worker)
        {:ok, worker}
      end),
      error: (fn worker ->
        Worker.get_job(worker)
        |> Job.changeset(%{finish_time: Ecto.DateTime.utc, status: "error"})
        |> Repo.update!
        pubsub_update_build(worker)
        {:ok, worker}
      end)
     }
  end

  defp pubsub_update_build(worker) do
    worker.build_id
    |> Build.build_id_query
    |> Build.build_preloaded_query
    |> Repo.one!
    |> PubSub.update_build
  end

  @doc """
  Trigger an event on the worker. This is a synchronous operation and there is
  no guarantee that the function will not return an error. The valid events are
  those defined in `@events`.
  """
  def trigger_event(worker, event) when event in @events do
    worker.callbacks[event].(worker)
  end

  @doc """
  Default function to handle log output from a worker.

    * `io` is the log output.
    * `type` should be :stdout or :stderr.
    * `order` is used for ordering the log messages.
  """
  def log(worker, io, type, order, colors \\ {nil, nil, nil}) do
    LogStreamer.log_string(io, type, order, worker.job_id, colors)
  end

  @doc """
  Adds a file to the worker struct. `vm_path` is relative to the home
  directory. Tilde (~) expansion does not work. Files are stored in the format:
  `{vm_path, path, permissions}` Opts:

    * `mode`: File permission _inside_ the VM. This does not affect the
      permissions for the file on the host machine.
  """
  def add_file(worker, vm_path, contents, opts \\ []) do
    permissions = Keyword.get(opts, :mode)
    path = Path.join [worker.path, "added-file-#{UUID.uuid4}"]
    File.write!(path, contents)
    put_in(worker.files, [{vm_path, path, permissions} | worker.files])
  end

  def get_files(worker), do: worker.files

  def get_build(%Worker{build_id: build_id}), do: Repo.get!(Build, build_id)

  def get_step(%Worker{step_id: step_id}), do: Repo.get!(Step, step_id)

  def get_job(%Worker{job_id: job_id}), do: Repo.get!(Job, job_id)

  def get_repo(%Worker{build_id: build_id}), do: Build.get_repo_from_id!(build_id)

  def provider(worker = %Worker{provider: nil}), do: get_job(worker).provider
  def provider(%Worker{provider: provider}), do: provider

  def env_vars(worker = %Worker{}) do
    job = get_job(worker) |> Repo.preload([step: [build: [branch: :project]]])
    step = job.step
    build = step.build
    branch = build.branch
    project = branch.project

    %{"RABBIT_CI_BUILD_NUMBER" => build.build_number,
      "RABBIT_CI_STEP" => step.name,
      "RABBIT_CI_BRANCH" => branch.name,
      "RABBIT_CI_PROJECT" => project.name,
      "RABBIT_CI_BOX" => job.box,
      "RABBIT_CI_PROVIDER" => job.provider}
    |> env_vars_git(worker.provider_config.git)
  end

  defp env_vars_git(vars, %{pr: pr}), do: Map.put(vars, "RABBIT_CI_PR", pr)
  defp env_vars_git(vars, %{commit: commit}), do: Map.put(vars, "RABBIT_CI_COMMIT", commit)
end
