defmodule RabbitCICore.Log do
  use RabbitCICore.Web, :model

  alias RabbitCICore.Step

  schema "logs" do
    field :stdio, :string
    field :order, :integer
    field :type, :string

    belongs_to :step, Step

    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If `params` are nil, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    cast(model, params, ~w(stdio step_id type), ~w())
    |> validate_inclusion(:type, ["stdout", "stderr"])
  end
end
