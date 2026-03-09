defmodule SymphonyElixir.Plane.AdapterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Plane.{Adapter, Issue}

  defmodule MockPlaneClient do
    def fetch_candidate_issues do
      {:ok,
       [
         %Issue{
           id: "issue-1",
           identifier: "PLANE-1",
           title: "Test Issue",
           state: "Todo"
         }
       ]}
    end

    def fetch_issues_by_states(["In Progress"]) do
      {:ok,
       [
         %Issue{
           id: "issue-2",
           identifier: "PLANE-2",
           title: "In Progress Issue",
           state: "In Progress"
         }
       ]}
    end

    def fetch_issue_states_by_ids(["issue-3"]) do
      {:ok,
       [
         %Issue{
           id: "issue-3",
           identifier: "PLANE-3",
           title: "Fetched Issue",
           state: "Done"
         }
       ]}
    end

    def create_comment("issue-4", "Test comment") do
      :ok
    end

    def update_issue_state("issue-5", "Done") do
      :ok
    end
  end

  describe "fetch_candidate_issues/0" do
    test "delegates to client module" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      Application.put_env(:symphony_elixir, :plane_client_module, MockPlaneClient)

      on_exit(fn ->
        Application.delete_env(:symphony_elixir, :plane_client_module)
      end)

      assert {:ok, [%Issue{id: "issue-1"}]} = Adapter.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "delegates to client module" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      Application.put_env(:symphony_elixir, :plane_client_module, MockPlaneClient)

      on_exit(fn ->
        Application.delete_env(:symphony_elixir, :plane_client_module)
      end)

      assert {:ok, [%Issue{id: "issue-2", state: "In Progress"}]} =
               Adapter.fetch_issues_by_states(["In Progress"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "delegates to client module" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      Application.put_env(:symphony_elixir, :plane_client_module, MockPlaneClient)

      on_exit(fn ->
        Application.delete_env(:symphony_elixir, :plane_client_module)
      end)

      assert {:ok, [%Issue{id: "issue-3", state: "Done"}]} =
               Adapter.fetch_issue_states_by_ids(["issue-3"])
    end
  end

  describe "create_comment/2" do
    test "delegates to client module" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      Application.put_env(:symphony_elixir, :plane_client_module, MockPlaneClient)

      on_exit(fn ->
        Application.delete_env(:symphony_elixir, :plane_client_module)
      end)

      assert :ok = Adapter.create_comment("issue-4", "Test comment")
    end
  end

  describe "update_issue_state/2" do
    test "delegates to client module" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      Application.put_env(:symphony_elixir, :plane_client_module, MockPlaneClient)

      on_exit(fn ->
        Application.delete_env(:symphony_elixir, :plane_client_module)
      end)

      assert :ok = Adapter.update_issue_state("issue-5", "Done")
    end
  end
end
