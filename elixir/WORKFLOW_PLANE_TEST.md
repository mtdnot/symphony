---
tracker:
  kind: plane
  workspace: cycletree
  project_id: 95c0b0e2-dfad-4aff-b530-d4b0cb01942f
  api_key: $PLANE_API_KEY
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Cancelled
  identifier_prefix: SUB
---

# Test Workflow for Plane

Issue: {{ issue.identifier }}
Title: {{ issue.title }}

{{ issue.description }}
