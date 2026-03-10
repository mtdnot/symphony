defmodule SymphonyElixir.Plane.Client do
  @moduledoc """
  Thin Plane REST API client for polling candidate issues.
  """

  require Logger
  alias SymphonyElixir.{Config, Plane.Issue}

  @issue_page_size 50
  @max_error_body_log_bytes 1_000

  @spec fetch_candidate_issues() :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_candidate_issues do
    with {:ok, workspace, project_id} <- validate_config() do
      with {:ok, states_map} <- fetch_states_map(workspace, project_id),
           {:ok, assignee_filter} <- routing_assignee_filter() do
        do_fetch_by_states(workspace, project_id, Config.plane_active_states(), states_map, assignee_filter)
      end
    end
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issues_by_states(state_names) when is_list(state_names) do
    normalized_states = state_names |> Enum.map(&to_string/1) |> Enum.uniq()

    if normalized_states == [] do
      {:ok, []}
    else
      with {:ok, workspace, project_id} <- validate_config(),
           {:ok, states_map} <- fetch_states_map(workspace, project_id) do
        do_fetch_by_states(workspace, project_id, normalized_states, states_map, nil)
      end
    end
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issue_states_by_ids(issue_ids) when is_list(issue_ids) do
    ids = Enum.uniq(issue_ids)

    if ids == [] do
      {:ok, []}
    else
      with {:ok, workspace, project_id} <- validate_config(),
           {:ok, states_map} <- fetch_states_map(workspace, project_id),
           {:ok, assignee_filter} <- routing_assignee_filter() do
        do_fetch_issues_by_ids(workspace, project_id, ids, states_map, assignee_filter)
      end
    end
  end

  defp validate_config do
    workspace = Config.plane_workspace()
    project_id = Config.plane_project_id()

    cond do
      is_nil(Config.plane_api_key()) -> {:error, :missing_plane_api_key}
      is_nil(workspace) -> {:error, :missing_plane_workspace}
      is_nil(project_id) -> {:error, :missing_plane_project_id}
      true -> {:ok, workspace, project_id}
    end
  end

  @spec create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  def create_comment(issue_id, body) when is_binary(issue_id) and is_binary(body) do
    workspace = Config.plane_workspace()
    project_id = Config.plane_project_id()

    path = "/workspaces/#{workspace}/projects/#{project_id}/issues/#{issue_id}/comments/"
    payload = %{"comment_html" => "<p>#{escape_html(body)}</p>"}

    case post(path, payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, response} ->
        Logger.error("Plane create comment failed status=#{response.status}#{plane_error_context(payload, response)}")
        {:error, {:plane_api_status, response.status}}

      {:error, reason} ->
        Logger.error("Plane create comment request failed: #{inspect(reason)}")
        {:error, {:plane_api_request, reason}}
    end
  end

  @spec update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}
  def update_issue_state(issue_id, state_name) when is_binary(issue_id) and is_binary(state_name) do
    workspace = Config.plane_workspace()
    project_id = Config.plane_project_id()

    with {:ok, states_map} <- fetch_states_map(workspace, project_id),
         {:ok, state_id} <- resolve_state_id(state_name, states_map) do
      path = "/workspaces/#{workspace}/projects/#{project_id}/issues/#{issue_id}/"
      payload = %{"state" => state_id}

      case patch(path, payload) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, response} ->
          Logger.error(
            "Plane update issue state failed status=#{response.status}#{plane_error_context(payload, response)}"
          )

          {:error, {:plane_api_status, response.status}}

        {:error, reason} ->
          Logger.error("Plane update issue state request failed: #{inspect(reason)}")
          {:error, {:plane_api_request, reason}}
      end
    end
  end

  @spec fetch_states_map(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  defp fetch_states_map(workspace, project_id) do
    path = "/workspaces/#{workspace}/projects/#{project_id}/states/"

    case get(path) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        results = Map.get(body, "results", [])
        {:ok, parse_states_response(results)}

      {:ok, response} ->
        Logger.error("Plane fetch states failed status=#{response.status}")
        {:error, {:plane_api_status, response.status}}

      {:error, reason} ->
        Logger.error("Plane fetch states request failed: #{inspect(reason)}")
        {:error, {:plane_api_request, reason}}
    end
  end

  defp parse_states_response(body) do
    Enum.reduce(body, %{}, fn state, acc ->
      name = state["name"]
      id = state["id"]

      if is_binary(name) and is_binary(id) do
        Map.put(acc, String.downcase(name), %{id: id, name: name})
      else
        acc
      end
    end)
  end

  defp do_fetch_by_states(workspace, project_id, state_names, states_map, assignee_filter) do
    state_ids =
      state_names
      |> Enum.flat_map(fn name ->
        case Map.get(states_map, String.downcase(name)) do
          %{id: id} -> [id]
          nil -> []
        end
      end)

    if state_ids == [] do
      {:ok, []}
    else
      do_fetch_issues_page(workspace, project_id, state_ids, states_map, assignee_filter, nil, [])
    end
  end

  defp do_fetch_issues_page(workspace, project_id, state_ids, states_map, assignee_filter, cursor, acc_issues) do
    path = build_issues_path(workspace, project_id, state_ids, cursor)

    case get(path) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        results = Map.get(body, "results", [])
        issues = Enum.map(results, &normalize_issue(&1, states_map, assignee_filter)) |> Enum.reject(&is_nil/1)
        updated_acc = prepend_page_issues(issues, acc_issues)

        case next_page_cursor(body) do
          {:ok, next_cursor} ->
            do_fetch_issues_page(workspace, project_id, state_ids, states_map, assignee_filter, next_cursor, updated_acc)

          :done ->
            {:ok, finalize_paginated_issues(updated_acc)}
        end

      {:ok, %{status: 200, body: body}} when is_list(body) ->
        issues = Enum.map(body, &normalize_issue(&1, states_map, assignee_filter)) |> Enum.reject(&is_nil/1)
        {:ok, issues}

      {:ok, response} ->
        Logger.error("Plane fetch issues failed status=#{response.status}")
        {:error, {:plane_api_status, response.status}}

      {:error, reason} ->
        Logger.error("Plane fetch issues request failed: #{inspect(reason)}")
        {:error, {:plane_api_request, reason}}
    end
  end

  defp do_fetch_issues_by_ids(workspace, project_id, ids, states_map, assignee_filter) do
    ids
    |> Enum.reduce_while({:ok, []}, fn issue_id, {:ok, acc} ->
      fetch_single_issue(workspace, project_id, issue_id, states_map, assignee_filter, acc)
    end)
    |> case do
      {:ok, issues} -> {:ok, Enum.reverse(issues)}
      error -> error
    end
  end

  defp fetch_single_issue(workspace, project_id, issue_id, states_map, assignee_filter, acc) do
    path = "/workspaces/#{workspace}/projects/#{project_id}/issues/#{issue_id}/"

    case get(path) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        issue = normalize_issue(body, states_map, assignee_filter)
        {:cont, {:ok, maybe_add_issue(acc, issue)}}

      {:ok, %{status: 404}} ->
        {:cont, {:ok, acc}}

      {:ok, response} ->
        Logger.error("Plane fetch issue by id failed status=#{response.status}")
        {:halt, {:error, {:plane_api_status, response.status}}}

      {:error, reason} ->
        Logger.error("Plane fetch issue by id request failed: #{inspect(reason)}")
        {:halt, {:error, {:plane_api_request, reason}}}
    end
  end

  defp maybe_add_issue(acc, nil), do: acc
  defp maybe_add_issue(acc, issue), do: [issue | acc]

  defp build_issues_path(workspace, project_id, state_ids, cursor) do
    base_path = "/workspaces/#{workspace}/projects/#{project_id}/issues/"

    query_params =
      [
        {"per_page", @issue_page_size},
        {"state__in", Enum.join(state_ids, ",")}
      ]
      |> then(fn params ->
        if cursor, do: [{"cursor", cursor} | params], else: params
      end)
      |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)

    "#{base_path}?#{query_params}"
  end

  defp prepend_page_issues(issues, acc_issues) when is_list(issues) and is_list(acc_issues) do
    Enum.reverse(issues, acc_issues)
  end

  defp finalize_paginated_issues(acc_issues) when is_list(acc_issues), do: Enum.reverse(acc_issues)

  defp next_page_cursor(%{"next_cursor" => cursor}) when is_binary(cursor) and cursor != "", do: {:ok, cursor}
  defp next_page_cursor(%{"next_page_results" => true, "next_cursor" => cursor}) when is_binary(cursor), do: {:ok, cursor}
  defp next_page_cursor(_), do: :done

  defp normalize_issue(issue, states_map, assignee_filter) when is_map(issue) do
    state_id = issue["state"]
    state_name = resolve_state_name(state_id, states_map)
    assignees = issue["assignees"] || []
    assignee_id = List.first(assignees)

    workspace = Config.plane_workspace()
    project_id = Config.plane_project_id()
    issue_id = issue["id"]

    url =
      if is_binary(workspace) and is_binary(project_id) and is_binary(issue_id) do
        "https://app.plane.so/#{workspace}/projects/#{project_id}/issues/#{issue_id}"
      else
        nil
      end

    %Issue{
      id: issue_id,
      identifier: issue["sequence_id"] && "#{Config.plane_identifier_prefix()}-#{issue["sequence_id"]}",
      title: issue["name"],
      description: issue["description_stripped"] || issue["description_html"] || issue["description"],
      priority: parse_priority(issue["priority"]),
      state: state_name,
      branch_name: nil,
      url: url,
      assignee_id: assignee_id,
      blocked_by: extract_blockers(issue),
      labels: extract_labels(issue),
      assigned_to_worker: assigned_to_worker?(assignees, assignee_filter),
      created_at: parse_datetime(issue["created_at"]),
      updated_at: parse_datetime(issue["updated_at"])
    }
  end

  defp normalize_issue(_issue, _states_map, _assignee_filter), do: nil

  defp resolve_state_name(state_id, states_map) when is_binary(state_id) do
    states_map
    |> Enum.find_value(fn {_key, %{id: id, name: name}} ->
      if id == state_id, do: name
    end)
  end

  defp resolve_state_name(_state_id, _states_map), do: nil

  defp resolve_state_id(state_name, states_map) when is_binary(state_name) do
    case Map.get(states_map, String.downcase(state_name)) do
      %{id: id} -> {:ok, id}
      nil -> {:error, :state_not_found}
    end
  end

  defp assigned_to_worker?(_assignees, nil), do: true

  defp assigned_to_worker?(assignees, %{match_values: match_values})
       when is_list(assignees) and is_struct(match_values, MapSet) do
    Enum.any?(assignees, fn assignee_id ->
      MapSet.member?(match_values, assignee_id)
    end)
  end

  defp assigned_to_worker?(_assignees, _assignee_filter), do: false

  defp routing_assignee_filter do
    case Config.plane_assignee() do
      nil ->
        {:ok, nil}

      assignee ->
        build_assignee_filter(assignee)
    end
  end

  defp build_assignee_filter(assignee) when is_binary(assignee) do
    case normalize_assignee_match_value(assignee) do
      nil ->
        {:ok, nil}

      normalized ->
        {:ok, %{configured_assignee: assignee, match_values: MapSet.new([normalized])}}
    end
  end

  defp normalize_assignee_match_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_assignee_match_value(_value), do: nil

  defp extract_labels(%{"label_ids" => label_ids, "labels" => labels})
       when is_list(label_ids) and is_list(labels) do
    labels
    |> Enum.filter(fn label -> is_map(label) and label["id"] in label_ids end)
    |> Enum.map(fn label -> label["name"] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
  end

  defp extract_labels(%{"labels" => labels}) when is_list(labels) do
    labels
    |> Enum.flat_map(fn
      label when is_map(label) -> [label["name"]]
      label when is_binary(label) -> [label]
      _ -> []
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
  end

  defp extract_labels(_), do: []

  defp extract_blockers(%{"related_issues" => related_issues}) when is_list(related_issues) do
    related_issues
    |> Enum.flat_map(fn
      %{"relation_type" => "blocked_by", "issue_detail" => blocker_issue} when is_map(blocker_issue) ->
        [
          %{
            id: blocker_issue["id"],
            identifier: blocker_issue["sequence_id"] && "#{Config.plane_identifier_prefix()}-#{blocker_issue["sequence_id"]}",
            state: nil
          }
        ]

      _ ->
        []
    end)
  end

  defp extract_blockers(_), do: []

  defp parse_datetime(nil), do: nil

  defp parse_datetime(raw) when is_binary(raw) do
    case DateTime.from_iso8601(raw) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_raw), do: nil

  defp parse_priority(priority) when is_integer(priority), do: priority

  defp parse_priority(priority) when is_binary(priority) do
    case Integer.parse(priority) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_priority(_priority), do: nil

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp get(path) do
    with {:ok, headers} <- api_headers() do
      url = Config.plane_endpoint() <> path

      Req.new(
        url: url,
        headers: headers,
        connect_options: [timeout: 30_000],
        retry: false
      )
      |> Req.get()
    end
  end

  defp post(path, payload) do
    with {:ok, headers} <- api_headers() do
      request_fun = request_module()
      url = Config.plane_endpoint() <> path

      request_fun.post(url,
        headers: headers,
        json: payload,
        connect_options: [timeout: 30_000],
        retry: false
      )
    end
  end

  defp patch(path, payload) do
    with {:ok, headers} <- api_headers() do
      request_fun = request_module()
      url = Config.plane_endpoint() <> path

      request_fun.patch(url,
        headers: headers,
        json: payload,
        connect_options: [timeout: 30_000],
        retry: false
      )
    end
  end

  defp api_headers do
    case Config.plane_api_key() do
      nil ->
        {:error, :missing_plane_api_key}

      api_key ->
        {:ok,
         [
           {"x-api-key", api_key},
           {"content-type", "application/json"},
           {"user-agent", "Symphony-Elixir/0.1"},
           {"accept", "*/*"}
         ]}
    end
  end

  defp request_module do
    Application.get_env(:symphony_elixir, :plane_request_module, Req)
  end

  defp plane_error_context(payload, response) when is_map(payload) do
    body =
      response
      |> Map.get(:body)
      |> summarize_error_body()

    " body=" <> body
  end

  defp summarize_error_body(body) when is_binary(body) do
    body
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> truncate_error_body()
    |> inspect()
  end

  defp summarize_error_body(body) do
    body
    |> inspect(limit: 20, printable_limit: @max_error_body_log_bytes)
    |> truncate_error_body()
  end

  defp truncate_error_body(body) when is_binary(body) do
    if byte_size(body) > @max_error_body_log_bytes do
      binary_part(body, 0, @max_error_body_log_bytes) <> "...<truncated>"
    else
      body
    end
  end
end
