### GitHub Personal Access Token (GH_PAT)
Used to access GitHub organization repositories.

Required Permissions for GH_PAT:
- `repo` → Full access to repositories (read access is enough, but write is needed if cloning private repositories)
    - `repo:read` (Read access to repositories)
    - `repo:write` (Only if you need to push branches)
- admin:org (Optional, if listing all repos in the org)
    - `read:org` (To list all repositories in the organization)

GitHub Organization Scope
- If cloning only public repositories → `read:org` + `repo:read`
- If cloning private repositories → `repo` (full)

### GitLab Personal Access Token (GL_TOKEN)
Used to push repositories to GitLab.

Required Permissions for GL_TOKEN:
- `api` → Full access to GitLab API (needed for project creation & repo management)
- `read_api` → (Alternative if only pushing to already created projects)
- `write_repository` → To push repositories