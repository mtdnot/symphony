defmodule SymphonyElixir.Plane.ClientTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Plane.{Client, Issue}

  describe "fetch_candidate_issues/0" do
    test "returns error when api key is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: nil,
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert {:error, :missing_plane_api_key} = Client.fetch_candidate_issues()
    end

    test "returns error when workspace is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: nil,
        tracker_project_id: "test-project-id"
      )

      assert {:error, :missing_plane_workspace} = Client.fetch_candidate_issues()
    end

    test "returns error when project_id is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: nil
      )

      assert {:error, :missing_plane_project_id} = Client.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "returns empty list for empty state set" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert {:ok, []} = Client.fetch_issues_by_states([])
    end

    test "returns error when api key is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: nil,
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert {:error, :missing_plane_api_key} = Client.fetch_issues_by_states(["Todo"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "returns empty list for empty id set" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert {:ok, []} = Client.fetch_issue_states_by_ids([])
    end

    test "returns error when api key is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: nil,
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert {:error, :missing_plane_api_key} = Client.fetch_issue_states_by_ids(["issue-1"])
    end
  end

  describe "Issue struct" do
    test "has expected fields with defaults" do
      issue = %Issue{
        id: "issue-123",
        identifier: "PLANE-1",
        title: "Test Issue",
        description: "Test description",
        priority: 2,
        state: "Todo",
        url: "https://app.plane.so/ws/projects/proj/issues/issue-123",
        assignee_id: "user-1"
      }

      assert issue.id == "issue-123"
      assert issue.identifier == "PLANE-1"
      assert issue.title == "Test Issue"
      assert issue.description == "Test description"
      assert issue.priority == 2
      assert issue.state == "Todo"
      assert issue.url == "https://app.plane.so/ws/projects/proj/issues/issue-123"
      assert issue.assignee_id == "user-1"
      assert issue.blocked_by == []
      assert issue.labels == []
      assert issue.assigned_to_worker == true
      assert issue.created_at == nil
      assert issue.updated_at == nil
      assert issue.branch_name == nil
    end

    test "label_names/1 returns labels" do
      issue = %Issue{
        id: "issue-123",
        labels: ["bug", "frontend"]
      }

      assert Issue.label_names(issue) == ["bug", "frontend"]
    end
  end
end
