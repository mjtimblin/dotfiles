---
name: reddit-research
description: Use when fetching Reddit content — threads, comments, post bodies, reactions, sentiment — without browser or OAuth. Covers the Arctic Shift API (only working unauthenticated method as of mid-2026), correct fetch tools, and the workflow for Reddit research tasks.
---

# Reddit Research

Fetch Reddit posts and comments programmatically using the Arctic Shift API. All
other unauthenticated approaches (reddit.com JSON, old.reddit.com, libreddit,
redlib, teddit, photon.reddit.com) return 403 or omit comment bodies.

## Arctic Shift API

**Base URL: `https://arctic-shift.photon-reddit.com`**

`arctic-shift.photon.wtf` does not exist — that wrong hostname is the #1 failure cause.

| Endpoint | Purpose | Example |
|---|---|---|
| `/api/posts/ids?ids=ID1,ID2` | Fetch posts by Reddit ID (no `t3_` prefix) | `?ids=1ur69uv,1ury1bx` |
| `/api/comments/tree?link_id=t3_ID&limit=N` | Full comment tree for a post | `?link_id=t3_1ur69uv&limit=100` |
| `/api/posts/search?subreddit=X&title=Y&limit=N` | Search posts in a subreddit | `?subreddit=Python&limit=25` |
| `/api/comments/search?subreddit=X&body=Y` | Search comments by text | `?subreddit=Python&body=asyncio` |

All GET, no auth. Returns full JSON with `selftext` (post body) and `body` (comment text).

## Fetch Method

**Use `curl -s`** (via the Bash tool) to retrieve Arctic Shift responses — it
has no size cap, returns raw JSON, and works reliably without quota concerns.

```bash
curl -s "https://arctic-shift.photon-reddit.com/api/posts/ids?ids=ID"
curl -s "https://arctic-shift.photon-reddit.com/api/comments/tree?link_id=t3_ID&limit=100"
```

## Caveats

- Removed posts show `"selftext": "[removed]"` but their comment trees are intact.
- Comment/post search requires `subreddit`, `author`, or `link_id` scope — no global full-text search.
- Data lags live Reddit by minutes to hours (scheduled pulls).
- Status: `https://status.arctic-shift.photon-reddit.com`

## Workflow

1. **Find threads** — `mcp__kagi__search` with `site:reddit.com r/SubName "keyword"` to get thread titles and post IDs.
2. **Fetch content** — Arctic Shift via `curl -s` (Bash tool):
   - Posts: `curl -s "https://arctic-shift.photon-reddit.com/api/posts/ids?ids=ID"`
   - Comments: `curl -s "https://arctic-shift.photon-reddit.com/api/comments/tree?link_id=t3_ID&limit=100"`
3. **Broaden** — For discovery without IDs, search news outlets (they quote Reddit threads verbatim) via Kagi.

## What Does NOT Work

| Approach | Result |
|---|---|
| `www.reddit.com/.json` | 403 |
| `old.reddit.com` | 401 |
| `redlib.catsarch.com` | 403 |
| `libreddit.kavin.rocks` | 403 |
| `teddit.net` | Connection refused |
| `photon.reddit.com` | Connection error |

## Partial: Kagi Snippets

`mcp__kagi__search` returns short snippets (1-3 sentences) of comment text in
search results — useful for identifying active threads and gauging sentiment
direction, but not for full content.
