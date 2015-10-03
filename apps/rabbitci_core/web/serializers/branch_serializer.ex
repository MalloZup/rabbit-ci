defmodule RabbitCICore.BranchSerializer do
  use JaSerializer

  alias RabbitCICore.Repo
  alias RabbitCICore.Branch
  alias RabbitCICore.BuildSerializer
  alias RabbitCICore.ProjectSerializer
  alias RabbitCICore.Router.Helpers, as: RouterHelpers

  attributes [:updated_at, :inserted_at, :name]
  has_one :project, include: ProjectSerializer
  has_many :builds, link: :branches_link

  def type, do: "branches"

  def project(r, _), do: Repo.preload(r, :project).project

  def branches_link(record, conn) do
    record = Repo.preload(record, :project)
    RouterHelpers.build_path(conn, :index, %{branch: record.name,
                                             project: record.project.name})
  end
end
