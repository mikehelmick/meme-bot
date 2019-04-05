defmodule Chatbot.Datastore do
  alias Chatbot.Environment, as: Environment
  alias Chatbot.Keys, as: Keys

  def connection() do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/datastore")
    GoogleApi.Datastore.V1.Connection.new(token.token)
  end

  def read_options(nil) do
    %GoogleApi.Datastore.V1.Model.ReadOptions{
      readConsistency: "EVENTUAL"
    }
  end
  def read_options(tx) do
    %GoogleApi.Datastore.V1.Model.ReadOptions{
      transaction: tx
    }
  end

  def deleteByQuery(query) do
    connection = connection()
    transaction = start_tx(connection)

    queryRequest = %GoogleApi.Datastore.V1.Model.RunQueryRequest{
      gqlQuery: %GoogleApi.Datastore.V1.Model.GqlQuery{
        allowLiterals: true,
        queryString: query
      },
      readOptions: read_options(nil)
    }

    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_run_query(
        connection, Environment.project(), [body: queryRequest], [decode: false])
    {:ok, queryResponse} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.RunQueryResponse])

    case queryResponse["batch"]["entityResults"] do
      nil -> 0
      batch ->
        keys = Enum.map(batch, fn x -> x["entity"]["key"] end)
            |> Enum.slice(0, 500)

        commit =
          %GoogleApi.Datastore.V1.Model.CommitRequest{
            mutations: Enum.map(keys, fn key ->
              %GoogleApi.Datastore.V1.Model.Mutation{
                delete: key
              } end),
            transaction: transaction
          }
          {:ok, _response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_commit(
              connection, Environment.project(), [body: commit], [decode: false])
        length(keys)
    end
  end

  def executePagedQuery(query, startCursor) do
    connection = connection()
    query = Map.put(query, :startCursor, startCursor)

    queryRequest = %GoogleApi.Datastore.V1.Model.RunQueryRequest{
      query: query,
      readOptions: read_options(nil)
    }

    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_run_query(
        connection, Environment.project(), [body: queryRequest], [decode: false])
    {:ok, queryResponse} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.RunQueryResponse])

    {queryResponse["batch"], queryResponse["query"]}
  end

  defp queryAllPages(results, _, _, "NO_MORE_RESULTS") do
    results
  end
  defp queryAllPages(results, query, endCursor, _) do
    # Some results, a cursor, and assume more reults
    {batch, _query} = executePagedQuery(query, endCursor)
    case batch["entityResults"] do
      nil ->
        queryAllPages(results, query, nil, "NO_MORE_RESULTS")
      firstBatch ->
        queryAllPages(results ++ firstBatch, query, batch["endCursor"], batch["moreResults"])
    end
  end

  def queryByGQL_allPages(firstQuery) do
    {batch, query} = queryByGQL(firstQuery)
    case batch["entityResults"] do
      nil ->
        []
      firstBatch ->
        queryAllPages(firstBatch, query, batch["endCursor"], batch["moreResults"])
    end
  end

  def queryByGQL(query) do
    connection = connection()

    queryRequest = %GoogleApi.Datastore.V1.Model.RunQueryRequest{
      gqlQuery: %GoogleApi.Datastore.V1.Model.GqlQuery{
        allowLiterals: true,
        queryString: query
      },
      readOptions: read_options(nil)
    }

    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_run_query(
        connection, Environment.project(), [body: queryRequest], [decode: false])
    {:ok, queryResponse} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.RunQueryResponse])

    {queryResponse["batch"], queryResponse["query"]}
  end

  def queryByPropertyEqaulity(kind, prop, value) do
    connection = connection()

    query = %GoogleApi.Datastore.V1.Model.Query{
      filter: %GoogleApi.Datastore.V1.Model.Filter{
        propertyFilter: %GoogleApi.Datastore.V1.Model.PropertyFilter{
          op: "EQUAL",
          property: %GoogleApi.Datastore.V1.Model.PropertyReference{ name: prop },
          value: value
        },
      },
      kind: [%GoogleApi.Datastore.V1.Model.KindExpression{name: kind}]
    }

    queryRequest = %GoogleApi.Datastore.V1.Model.RunQueryRequest{
      query: query,
      readOptions: read_options(nil)
    }
    # IO.puts("QUERY: #{inspect queryRequest}")

    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_run_query(
        connection, Environment.project(), [body: queryRequest], [decode: false])
    {:ok, queryResponse} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.RunQueryResponse])

    case queryResponse["batch"]["entityResults"] do
      nil -> []
      entities -> Enum.map(entities, fn x -> x["entity"] end)
    end
  end

  def readEntity(kind, name, parseFn) do
    connection = connection()
    lookup_request = %GoogleApi.Datastore.V1.Model.LookupRequest {
      keys: Keys.build_keys(kind, [name]),
      readOptions: read_options(nil)
    }
    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_lookup(
        connection, Environment.project(), [body: lookup_request], [decode: false])
    {:ok, lookup_response} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.LookupResponse])
    case lookup_response["found"] do
       nil -> nil
       # Match on a single entity in the found list.
       [data] ->
        # IO.puts("FOUND DATA: #{inspect data}")
         parseFn.(data)
    end
  end

  def read_entity(connection, transaction, {kind, name}, parseFn) do
    lookup_request = %GoogleApi.Datastore.V1.Model.LookupRequest {
      keys: Keys.build_keys(kind, [name]),
      readOptions: read_options(transaction)
    }
    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_lookup(
        connection, Environment.project(), [body: lookup_request], [decode: false])
    {:ok, lookup_response} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.LookupResponse])
    case lookup_response["found"] do
       nil -> nil
       # Match on a single entity in the found list.
       [data] ->
        # IO.puts("FOUND DATA: #{inspect data}")
         parseFn.(data)
    end
  end

  def read_modify_write({kind, name}, parseFn, updateFn, encodeFn) do
    connection = connection()
    transaction = start_tx(connection)

    case read_entity(connection, transaction, {kind, name}, parseFn) do
      nil ->
        rollback(connection, transaction)
        {:error, "Requested entity not found, {'#{kind}', '#{name}'}"}
      entity ->
        # IO.puts("READ ENTITY #{inspect entity}")
        # Apply the read-modify-write
        case updateFn.(entity) do
          {:ok, updated} ->
            # IO.puts("UPDATED ENTITY #{inspect updated}")
            commit = %GoogleApi.Datastore.V1.Model.CommitRequest{
              mutations: [
                %GoogleApi.Datastore.V1.Model.Mutation{
                  update: encodeFn.(updated)
                }
              ],
              transaction: transaction
            }
            {:ok, _response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_commit(
                connection, Environment.project(), [body: commit], [decode: false])
            {:ok, updated}
          {:error, message} ->
            rollback(connection, transaction)
            {:error, message}
        end
    end
  end

  def updateEntity(entity, entityFn) do
    entityFn.(entity) |> updateEntity()
  end

  def updateEntity(entity) do
    connection = connection()
    transaction = start_tx(connection)
    commit = %GoogleApi.Datastore.V1.Model.CommitRequest{
      mutations: [
        %GoogleApi.Datastore.V1.Model.Mutation{
          update: entity
        }
      ],
      transaction: transaction
    }
    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_commit(
        connection, Environment.project(), [body: commit], [decode: false])
    {:ok, decoded} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.CommitResponse])
    decoded
  end

  # Entity type + encoding function.
  def insertEntity(entity, entityFun) do
    entityFun.(entity) |> insertEntity()
  end

  # Inserts a single read entity, returns decoded CommitResponse
  def insertEntity(entity) do
    connection = connection()
    transaction = start_tx(connection)
    commit = %GoogleApi.Datastore.V1.Model.CommitRequest{
      mutations: [
        %GoogleApi.Datastore.V1.Model.Mutation{
          insert: entity
        }
      ],
      transaction: transaction
    }
    {:ok, response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_commit(
        connection, Environment.project(), [body: commit], [decode: false])
    {:ok, decoded} = Poison.decode(response.body, [as: GoogleApi.Datastore.V1.Model.CommitResponse])
    decoded
  end

  def rollback(connection, transaction) do
    rollback = %GoogleApi.Datastore.V1.Model.RollbackRequest{
      transaction: transaction
    }
    GoogleApi.Datastore.V1.Api.Projects.datastore_projects_rollback(
      connection, Environment.project(), [body: rollback], [decode: false])
  end

  def start_tx(connection) do
    tx_request = %GoogleApi.Datastore.V1.Model.BeginTransactionRequest{
      transactionOptions: %GoogleApi.Datastore.V1.Model.TransactionOptions{
        readWrite: %GoogleApi.Datastore.V1.Model.ReadWrite{}
      }
    }
    {:ok, tx_response} = GoogleApi.Datastore.V1.Api.Projects.datastore_projects_begin_transaction(
        connection, Environment.project(), [body: tx_request])
    tx_response.transaction
  end
end
