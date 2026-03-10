defmodule SymphonyElixir.Plane.ConfigTest do
  use SymphonyElixir.TestSupport

  describe "plane configuration" do
    test "plane_endpoint returns default when not configured" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_endpoint() == "https://api.plane.so/api/v1"
    end

    test "plane_endpoint returns custom endpoint when configured" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_endpoint: "https://custom.plane.so/api/v1",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_endpoint() == "https://custom.plane.so/api/v1"
    end

    test "plane_api_key returns configured value" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "my-plane-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_api_key() == "my-plane-api-key"
    end

    test "plane_api_key resolves from PLANE_API_KEY env var" do
      previous_env = System.get_env("PLANE_API_KEY")
      on_exit(fn -> restore_env("PLANE_API_KEY", previous_env) end)

      System.put_env("PLANE_API_KEY", "env-plane-api-key")

      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: nil,
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_api_key() == "env-plane-api-key"
    end

    test "plane_workspace returns configured value" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "my-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_workspace() == "my-workspace"
    end

    test "plane_project_id returns configured value" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "my-project-id"
      )

      assert Config.plane_project_id() == "my-project-id"
    end

    test "plane_assignee returns configured value" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        tracker_assignee: "user-uuid"
      )

      assert Config.plane_assignee() == "user-uuid"
    end

    test "plane_assignee resolves from PLANE_ASSIGNEE env var" do
      previous_env = System.get_env("PLANE_ASSIGNEE")
      on_exit(fn -> restore_env("PLANE_ASSIGNEE", previous_env) end)

      System.put_env("PLANE_ASSIGNEE", "env-user-uuid")

      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        tracker_assignee: nil
      )

      assert Config.plane_assignee() == "env-user-uuid"
    end

    test "plane_active_states returns default states" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_active_states() == ["Todo", "In Progress"]
    end

    test "plane_active_states returns configured states" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        tracker_active_states: ["Backlog", "Started", "In Review"]
      )

      assert Config.plane_active_states() == ["Backlog", "Started", "In Review"]
    end

    test "plane_terminal_states returns default states" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_terminal_states() == ["Closed", "Cancelled", "Canceled", "Duplicate", "Done"]
    end

    test "plane_identifier_prefix returns default when not configured" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.plane_identifier_prefix() == "PLANE"
    end

    test "plane_identifier_prefix returns configured value" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        tracker_identifier_prefix: "MT"
      )

      assert Config.plane_identifier_prefix() == "MT"
    end
  end

  describe "validate!/0 for plane tracker" do
    test "returns ok when all plane config is present" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        codex_command: "codex app-server"
      )

      assert :ok = Config.validate!()
    end

    test "returns error when plane api key is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: nil,
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id",
        codex_command: "codex app-server"
      )

      assert {:error, :missing_plane_api_key} = Config.validate!()
    end

    test "returns error when plane workspace is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: nil,
        tracker_project_id: "test-project-id",
        codex_command: "codex app-server"
      )

      assert {:error, :missing_plane_workspace} = Config.validate!()
    end

    test "returns error when plane project_id is missing" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: nil,
        codex_command: "codex app-server"
      )

      assert {:error, :missing_plane_project_id} = Config.validate!()
    end
  end

  describe "tracker_kind/0" do
    test "returns plane when configured" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Config.tracker_kind() == "plane"
    end
  end

  describe "Tracker.adapter/0" do
    test "returns Plane.Adapter when tracker_kind is plane" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "plane",
        tracker_api_token: "test-api-key",
        tracker_workspace: "test-workspace",
        tracker_project_id: "test-project-id"
      )

      assert Tracker.adapter() == SymphonyElixir.Plane.Adapter
    end
  end
end
