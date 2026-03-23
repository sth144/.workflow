# Skill: Fetch Currently Assigned Jira Tickets

## When to Use
Use this skill when the user asks about their current Jira tickets, sprint work,
assigned issues, or wants to know what they should be working on. Trigger phrases
include: "my tickets", "what's assigned to me", "current sprint", "my Jira issues",
"what should I work on".

## Prerequisites
- The Atlassian MCP server must be connected (configured in .mcp.json or settings)
- User must be authenticated with their Atlassian account

## Instructions

### Step 1: Get the user's Atlassian identity
Use `Atlassian:atlassianUserInfo` to get the current user's account ID.

### Step 2: Get accessible resources
Use `Atlassian:getAccessibleAtlassianResources` to get the cloudId for the
Jira instance.

### Step 3: Search for assigned tickets
Use `Atlassian:searchJiraIssuesUsingJql` with the following JQL:
```
assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC, updated DESC
```

To narrow to the current sprint, use:
```
assignee = currentUser() AND sprint in openSprints() AND resolution = Unresolved ORDER BY priority DESC, updated DESC
```

### Step 4: Present results
For each ticket, display:
- **Key** (e.g., PROJ-123) — as a clickable link if possible
- **Summary** — the ticket title
- **Status** — current workflow status
- **Priority** — P1/P2/etc.
- **Type** — bug, story, task, etc.

Group by status (In Progress first, then To Do, then others).

### Step 5: Offer next actions
After listing tickets, offer:
- "Want me to pull up details on any of these?"
- "Should I check for any blocked tickets?"
- "Want to see the full sprint board?"

## Example Output Format

### 🔵 In Progress
- **ESP-456** [High] Story: Implement LLM retry logic for ESP extensions
- **ESP-789** [Medium] Task: Update API configuration documentation

### ⬚ To Do
- **ESP-123** [High] Bug: urllib3 version conflict in startup
- **ESP-234** [Low] Task: Add unit tests for dynamic extensions

## Error Handling
- If MCP connection fails: suggest checking Atlassian integration in Claude Code settings
- If no tickets found: confirm the JQL and suggest checking the project key
- If auth fails: guide user to re-authenticate via `claude mcp` settings
