# CMS Wireframes

*Stolen shamelessly from Outline, Kan, and our own Accountability Tracker.*

These wireframes define the visual structure of every screen. Each one includes:
- An ASCII layout showing where things go
- **Steal notes** explaining which app inspired the pattern and why
- Interaction notes for non-obvious behavior

Design principles applied throughout:
1. **From Outline**: Content is king. The UI should disappear. Generous whitespace, muted chrome, let the data breathe. Workspace → Collection → Document hierarchy gives structure without clutter.
2. **From Kan**: Cards are scannable in under 1 second. Title, one badge, one avatar, done. No card should need scrolling.
3. **From Accountability Tracker**: Progressive disclosure. Default to collapsed. Show actions only when they're relevant.

---

## Color System

Derived from the schema.config entity colors, extended with status and priority colors:

```
Entity colors (from schema):
  project   #3b82f6  blue
  sprint    #8b5cf6  purple
  task      #10b981  green
  document  #f59e0b  amber
  person    #ec4899  pink

Status colors (for task badges):
  backlog      #94a3b8  slate
  todo         #60a5fa  blue
  in_progress  #f59e0b  amber
  review       #a78bfa  purple
  done         #34d399  green
  archived     #d1d5db  gray

Priority colors (for task badges):
  low          #94a3b8  slate
  medium       #60a5fa  blue
  high         #f59e0b  amber
  urgent       #ef4444  red

Chrome:
  background   #f8fafc  (near-white)
  surface      #ffffff  (cards, panels)
  border       #e2e8f0  (subtle dividers)
  text         #1e293b  (primary text)
  muted        #64748b  (secondary text)
  accent       #3b82f6  (links, active nav)
```

---

## App Shell & Navigation

### Desktop (>900px) — Three-column layout

**Steal from Outline**: Outline uses three columns: a thin icon rail, a wider sidebar showing the workspace/collection tree, and the main content area. The sidebar is collapsible — toggle it to give content full width. This is how you navigate a hierarchy without losing context.

```
┌──┬──────────────────┬──────────────────────────────────────────┐
│  │                  │                                          │
│  │  IMAGINEERING    │                                          │
│🏠│                  │                                          │
│  │  ▾ Projects      │              Content Area                │
│✓ │  ▾ ● Dashboard   │              (changes per screen)        │
│  │      Sprint 2 ●  │                                          │
│⏱ │      Sprint 3 ○  │                                          │
│  │    ▸ ● Gateway   │                                          │
│📄│    ▸ ● Acct Track│                                          │
│  │      ○ Book Find │                                          │
│◉ │      ✓ Embeddings│                                          │
│  │                  │                                          │
│  │  People          │                                          │
│  │    Robin         │                                          │
│  │    Nick          │                                          │
│  │    Sarah         │                                          │
│  │    Karim         │                                          │
│──│                  │                                          │
│👤│  [Collapse ◂]    │                                          │
└──┴──────────────────┴──────────────────────────────────────────┘
72px    200px                    remaining width

Nav rail items (left column, top to bottom):
  🏠  My Page       → /person/:myId
  ✓   Tasks         → /tasks
  ⏱   Sprints       → /sprints
  📄  Documents     → /documents
  ◉   Graph         → /graph
  ─── (spacer)
  👤  User menu     → settings, logout

Sidebar items:
  Workspace name at top (from schema.config app.name)
  Projects tree — shows all projects with status indicator, expandable
    ● active (blue)  ○ paused (gray)  ✓ completed (green)
    Expand a project → shows its sprints nested underneath
    Click a project → scopes Tasks/Documents/Sprints to that project
    Sprints show inside their parent project:
      ● active (green)  ○ planning (gray)  ✓ completed (blue)
  People list — quick access to person pages
  [Collapse ◂] — hides sidebar, only nav rail remains
```

**Steal from Outline**: The nav rail is 72px wide, matte dark (`#1e293b`) or light (`#f1f5f9`) depending on theme. Icons are 20px, centered. Active icon has a pill-shaped highlight behind it (`accent` color at 10% opacity). Hover shows a tooltip to the right with the screen name.

**Steal from Outline**: The sidebar is 200px wide, same background as the nav rail. Tree items are 32px tall, 14px text, with indent for nesting. Active project has a subtle background highlight. The sidebar scrolls independently of the content area.

**Project scoping**: When a project is selected in the sidebar, the Tasks kanban, Documents list, and Sprint list filter to that project's content. A breadcrumb or "Viewing: Dashboard" label appears above the content. Click the workspace name or "All" to clear the filter.

### Desktop — Sidebar collapsed

```
┌──┬─────────────────────────────────────────────────────────────┐
│  │                                                             │
│  │                                                             │
│🏠│                                                             │
│  │                    Content Area                             │
│✓ │                    (full width)                             │
│  │                                                             │
│⏱ │                                                             │
│  │                                                             │
│📄│                                                             │
│  │                                                             │
│◉ │                                                             │
│  │                                                             │
│  │                                                             │
│──│                                                             │
│▸ │  ← click to expand sidebar                                  │
│👤│                                                             │
└──┴─────────────────────────────────────────────────────────────┘
 72px                        remaining width
```

### Mobile (<900px)

**Steal from Kan**: Bottom navigation bar. 5 icons, evenly spaced. Active icon has a small dot below it rather than a background change (cleaner on small screens). The sidebar becomes a slide-out drawer triggered by a hamburger icon.

```
┌─────────────────────────────────────────────┐
│  ☰  Imagineering         [project ▾]       │  ← hamburger opens drawer, project selector
│                                             │
│               Content Area                  │
│               (full width)                  │
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│  🏠      ✓       ⏱       📄      ◉        │
│  My     Tasks  Sprints  Docs    Graph      │
│  Page                                      │
└─────────────────────────────────────────────┘
```

---

## Screen 1: My Page (`/person/:id`)

The personal home screen. Shows YOUR tasks, sprints, and documents at a glance.

**Steal from Accountability Tracker**: Collapsible sections. Each section (Tasks, Sprints, Documents) works like the accountability tracker's expandable user cards — default open, click header to collapse. Section headers show a count badge and a toggle chevron.

**Steal from Outline**: Clean header area with the person's name as a large title, role as subtitle. No card wrapper around the header — let it breathe.

### Desktop Layout

```
┌──┬────────┬───────────────────────────────────────────────────────┐
│  │  ...   │                                                       │
│  │sidebar │  Ada Lovelace                                 [Edit]  │
│🏠│  ...   │  Engineering Lead                                     │
│• │        │  ada@example.com                                      │
│  │        │                                                       │
│  │        │  ───────────────────────────────────────────────────── │
│  │        │                                                       │
│  │        │  ▾ My Tasks (12)                          [+ New Task] │
│  │        │  ┌──────────┬──────────┬──────────┬──────────┬──────┐ │
│  │        │  │ Backlog  │ Todo (3) │Active(2) │Review(1) │Done 4│ │
│  │        │  │          │          │          │          │      │ │
│  │        │  │ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │ ┌──────┐ │ ┌──┐ │ │
│  │        │  │ │Card  │ │ │ Card │ │ │ Card │ │ │ Card │ │ │  │ │ │
│  │        │  │ └──────┘ │ └──────┘ │ └──────┘ │ └──────┘ │ └──┘ │ │
│  │        │  └──────────┴──────────┴──────────┴──────────┴──────┘ │
│  │        │                                                       │
│  │        │  ▾ My Sprints (2)                      [+ New Sprint] │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ ● Sprint 2: Frontend       Mar 24 → Apr 06    │   │
│  │        │  │   Goal: Ship Flutter web frontend              │   │
│  │        │  │   ████████░░░░░░░░  3/12 tasks                 │   │
│  │        │  ├────────────────────────────────────────────────┤   │
│  │        │  │ ○ Sprint 3: Polish         Apr 07 → Apr 20    │   │
│  │        │  │   Goal: Production deployment                  │   │
│  │        │  │   ░░░░░░░░░░░░░░░  0/5 tasks                  │   │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
│  │        │  ▾ My Documents (3)                  [+ New Document] │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ Architecture Overview   spec  · Dashboard · Mar 5│  │
│  │        │  │ Schema-Driven UI        note  · Dashboard · Mar 12│ │
│  │        │  │ Sprint Retro Template   ref   ·    —      · Feb 28│ │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
└──┴────────┴───────────────────────────────────────────────────────┘
```

### Kanban Card Design (Detail)

**Steal from Kan**: Minimal cards. Kan shows: title, colored label chips, tiny assignee avatar, due date. Nothing else. No description preview, no checklist count, no comment count. The card is a handle you grab to get to the detail — not the detail itself.

```
┌─────────────────────┐
│  Fix API bug         │   ← title: 14px, semibold, max 2 lines
│                      │
│  ● high   Mar 28     │   ← priority dot + label, deadline right-aligned
│  CMS Project         │   ← project name, muted text, 12px
└─────────────────────┘
     ~180px wide

Priority dot colors:
  ○ low      slate
  ● medium   blue
  ● high     amber
  ◉ urgent   red (filled + ring)
```

**Why this is enough:** On a kanban board, you need to scan 20+ cards quickly. The card answers three questions: *what is it?* (title), *how important?* (priority), *when's it due?* (deadline). Everything else is in the detail panel.

### Sprint Card Design (Detail)

**Steal from Accountability Tracker**: The sprint card is like a compressed weekly entry. Header with title and date range, expandable to show goal and task breakdown.

```
┌────────────────────────────────────────────────────────┐
│  ● Sprint 12: Graph Visualization    Mar 17 → Mar 30  │  ← ● = current (green)
│    Goal: Ship interactive knowledge graph              │  ← muted, 13px
│    ████████████░░░░░░░░  5/8 tasks done                │  ← progress bar, green fill
└────────────────────────────────────────────────────────┘

Status indicators:
  ● current   (green dot)
  ○ upcoming  (gray dot)
  ✓ completed (green checkmark)
```

---

## Screen 2: Tasks (`/tasks`)

Global kanban board — all tasks, or scoped to the project selected in the sidebar.

**Steal from Kan**: The board IS the content. No panels by default. The columns stretch full width. Filter bar sits above the board as a single horizontal strip. Clicking a card opens a detail panel on the right (pushing the board narrower, not overlaying it).

**Steal from Outline**: When the detail panel is open, the layout is a split-pane — like Outline's sidebar + document. The detail panel is generous (400px) and scrollable, with the same clean typography as a document view.

**Project scoping**: When a project is selected in the sidebar, the board shows only that project's tasks. A breadcrumb shows the scope: `All Tasks` or `Dashboard > Tasks`. The filter bar still works within the scoped view.

### Desktop — Board View (no card selected)

```
┌──┬────────┬───────────────────────────────────────────────────────┐
│  │  ...   │                                                       │
│  │sidebar │  Dashboard > Tasks                        [+ New Task] │
│  │  ...   │                                                       │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ Status:[All▾] Assignee:[All▾] Priority:[All▾] 🔍│  │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
│  │        │  ┌────────┬────────┬────────┬────────┬────────┬────┐ │
│  │        │  │Back. 2 │Todo  4 │In Pr 3 │Rev.  2 │Done  8 │Ar. │ │
│  │        │  ├────────┼────────┼────────┼────────┼────────┼────┤ │
│  │        │  │┌──────┐│┌──────┐│┌──────┐│┌──────┐│┌──────┐│    │ │
│  │        │  ││ Card │││ Card │││ Card │││ Card │││ Card ││    │ │
│  │        │  │└──────┘│└──────┘│└──────┘│└──────┘│└──────┘│    │ │
│  │        │  │┌──────┐│┌──────┐│┌──────┐│┌──────┐│┌──────┐│    │ │
│  │        │  ││ Card │││ Card │││ Card │││ Card │││ Card ││    │ │
│  │        │  │└──────┘│└──────┘│└──────┘│└──────┘│└──────┘│    │ │
│  │        │  │        │┌──────┐│┌──────┐│        │┌──────┐│    │ │
│  │        │  │        ││ Card │││ Card ││        ││ Card ││    │ │
│  │        │  │        │└──────┘│└──────┘│        │└──────┘│    │ │
│  │        │  └────────┴────────┴────────┴────────┴────────┴────┘ │
│  │        │                                                       │
└──┴────────┴───────────────────────────────────────────────────────┘
```

### Desktop — Board View (card selected → detail panel open)

**Steal from Outline**: The detail panel slides in from the right, exactly like Outline's document view when you click a document in the sidebar. The board columns compress to fit. The panel has a close button (×) in the top-right.

```
┌──┬────────┬──────────────────────────┬─────────────────────────┐
│  │  ...   │                          │                         │
│  │sidebar │  Dashboard > Tasks       │  Fix auth bug       [×] │
│  │  ...   │                          │                         │
│  │        │  ┌──────────────────┐    │  Workflow               │
│  │        │  │ [filters]   🔍   │    │    Status   ● In Prog   │
│  │        │  └──────────────────┘    │    Priority ◉ Urgent    │
│  │        │                          │                         │
│  │        │  ┌──────┬──────┬──────┐  │  Planning               │
│  │        │  │Back 2│Todo 4│In P 3│  │    Due Date  Mar 24     │
│  │        │  ├──────┼──────┼──────┤  │    Estimate  3 pts      │
│  │        │  │┌────┐│┌────┐│┌────┐│  │                         │
│  │        │  ││Card│││Card│││▶Fix◀││  │  Tags                  │
│  │        │  │└────┘│└────┘│└────┘│  │    api, backend         │
│  │        │  │┌────┐│┌────┐│┌────┐│  │                         │
│  │        │  ││Card│││Card│││Card ││  │  ─────────────────────  │
│  │        │  │└────┘│└────┘│└────┘│  │                         │
│  │        │  └──────┴──────┴──────┘  │  Project                │
│  │        │                          │    Dashboard →           │
│  │        │  Done + Archived hidden  │  Assigned to             │
│  │        │  when panel is open      │    👤 Karim →            │
│  │        │                          │  Sprint                  │
│  │        │                          │    Sprint 2 →            │
│  │        │                          │  References              │
│  │        │                          │    Gateway Pitch Deck →  │
│  │        │                          │                         │
│  │        │                          │  [Edit]  [Delete]       │
│  │        │                          │                         │
└──┴────────┴──────────────────────────┴─────────────────────────┘
```

**Key interaction notes:**
- Columns compress when panel opens. Done + Archived columns hide to make room.
- The selected card gets a highlight border (`▶Fix◀` above).
- Relationships are clickable links (→) that navigate to the related entity.
- Detail panel metadata is grouped by sections from ui_schema (`Workflow`, `Planning`, `Tags`).
- Edit mode turns the metadata fields into form inputs inline (no modal).

### Mobile — Tasks

**Steal from Accountability Tracker**: On mobile, the kanban columns stack vertically as collapsible sections, like the accountability tracker's user cards. Default: only Todo and Active are expanded.

```
┌─────────────────────────────────────────────┐
│  ☰  Dashboard > Tasks              [+ Task] │
│                                             │
│  [Status ▾] [Priority ▾] [🔍]             │
│                                             │
│  ▸ Backlog (2)                              │
│                                             │
│  ▾ Todo (4)                                 │
│  ┌─────────────────────────────────────────┐│
│  │ Write tests              ● high  Mar 25 ││
│  │ Dashboard                               ││
│  ├─────────────────────────────────────────┤│
│  │ Update deps              ○ low   Apr 1  ││
│  │ Dashboard                               ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ▾ In Progress (3)                          │
│  ┌─────────────────────────────────────────┐│
│  │ Drag-and-drop           ● high  Apr 02  ││
│  │ Dashboard                               ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ▸ Review (2)                               │
│  ▸ Done (8)                                 │
│                                             │
├─────────────────────────────────────────────┤
│  🏠      ✓       ⏱       📄      ◉        │
└─────────────────────────────────────────────┘
```

Tapping a card navigates to `/tasks/:id` (full-screen detail page on mobile).

---

## Screen 3: Sprints (`/sprints`)

**Steal from Outline**: This is Outline's "collection list" pattern. A clean vertical list grouped by section (Current / Upcoming / Completed), with each sprint as a row you click to expand or navigate.

**Steal from Accountability Tracker**: The sprint list uses the accountability tracker's collapsible section pattern — colored section headers with chevron toggles. Sprint cards are like weekly entries: header with title and date range, goal text, progress bar. Click to expand the detail panel.

### Desktop Layout

```
┌──┬────────┬───────────────────────────────────────────────────────┐
│  │  ...   │                                                       │
│  │sidebar │  Sprints                                [+ New Sprint] │
│  │  ...   │                                                       │
│  │        │  ● CURRENT  1                                    [▾]  │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ ● Sprint 2: Frontend         Mar 24 → Apr 06  │   │
│  │        │  │   Active                                       │   │
│  │        │  │   Goal: Ship Flutter web frontend              │   │
│  │        │  │   ████████░░░░░░░░  3/12 tasks                 │   │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
│  │        │  ○ PLANNING  1                                   [▾]  │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ ○ Sprint 3: Polish & Deploy  Apr 07 → Apr 20  │   │
│  │        │  │   Planning                                     │   │
│  │        │  │   Goal: Production deployment                  │   │
│  │        │  │   ░░░░░░░░░░░░░░░  0/5 tasks                  │   │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
│  │        │  ✓ COMPLETED  1                                  [▾]  │
│  │        │  ┌────────────────────────────────────────────────┐   │
│  │        │  │ ✓ Sprint 1: Foundation       Mar 10 → Mar 23  │   │
│  │        │  │   Completed                                    │   │
│  │        │  │   ████████████████████  8/8 tasks              │   │
│  │        │  └────────────────────────────────────────────────┘   │
│  │        │                                                       │
└──┴────────┴───────────────────────────────────────────────────────┘
```

### Sprint Detail Panel (click a sprint → panel opens right)

**Steal from Accountability Tracker**: The sprint detail is like the accountability tracker's expanded week entry — it reveals participants, tasks, and retro inline.

**Steal from Kan**: The sprint detail panel shows a **mini-kanban** — a 2×2 grid of status groups rather than full drag-and-drop columns. Compact enough to fit the panel, but gives the spatial status-overview that a flat list can't.

```
┌──┬────────┬─────────────────────┬──────────────────────────────┐
│  │  ...   │                     │                              │
│  │sidebar │  Sprints [+ New]    │  Sprint 2: Frontend      [×] │
│  │  ...   │                     │  Mar 24 → Apr 06             │
│  │        │  ● CURRENT          │  Owner: 👤 Robin →           │
│  │        │  ┌─────────────┐    │  Goal: Ship Flutter web      │
│  │        │  │▶ Sprint 2 ◀ │    │  frontend with kanban        │
│  │        │  └─────────────┘    │                              │
│  │        │                     │  ─────────────────────────── │
│  │        │  ○ PLANNING         │                              │
│  │        │  ┌─────────────┐    │  Participants                │
│  │        │  │ Sprint 3    │    │  ┌──────────────────────┐    │
│  │        │  └─────────────┘    │  │ 👤 Robin             │    │
│  │        │                     │  │   Goal: Ship kanban   │    │
│  │        │  ✓ COMPLETED        │  ├──────────────────────┤    │
│  │        │  ┌─────────────┐    │  │ 👤 Sarah             │    │
│  │        │  │ Sprint 1    │    │  │   Goal: Nav + cards   │    │
│  │        │  └─────────────┘    │  └──────────────────────┘    │
│  │        │                     │                              │
│  │        │                     │  Goals (Tasks)  3/12 done    │
│  │        │                     │  ████████░░░░░░░░░░░         │
│  │        │                     │                              │
│  │        │                     │  ┌──────────┬──────────┐     │
│  │        │                     │  │ In Prog  │ Review   │     │
│  │        │                     │  ├──────────┼──────────┤     │
│  │        │                     │  │Filter bar│Sprint lst│     │
│  │        │                     │  │Drag-drop │Detail pnl│     │
│  │        │                     │  │Doc viewer│          │     │
│  │        │                     │  └──────────┴──────────┘     │
│  │        │                     │  ┌──────────┬──────────┐     │
│  │        │                     │  │ Todo     │ Done     │     │
│  │        │                     │  ├──────────┼──────────┤     │
│  │        │                     │  │Graph viz │Kanban    │     │
│  │        │                     │  │Mobile    │MetaForm  │     │
│  │        │                     │  │E2E tests │Nav rail  │     │
│  │        │                     │  └──────────┴──────────┘     │
│  │        │                     │                              │
│  │        │                     │  [+ Add Task] [Edit] [Delete]│
│  │        │                     │                              │
│  │        │                     │  ─────────────────────────── │
│  │        │                     │  Sprint Retro                │
│  │        │                     │  🔒 Unlocks after Apr 06     │
│  │        │                     │                              │
└──┴────────┴─────────────────────┴──────────────────────────────┘
```

**Task list interaction**: Each task in the mini-kanban or task list is tappable — navigates to the Tasks screen with that task selected. Tasks show a chevron (→) to indicate they're clickable.

---

## Screen 4: Documents (`/documents`)

**Steal from Outline**: Clean searchable list with generous spacing. But unlike Outline (where docs belong to collections), our documents belong to tasks. A document is a task-level artifact — a spec, a note, a report produced as part of completing a task. One document can be attached to multiple tasks.

**Hierarchy**: Documents live underneath tasks, not projects. A document's project context is inherited from its parent tasks. The Documents screen shows a flat searchable list with the parent task shown as metadata. When a project is selected in the sidebar, only documents attached to that project's tasks are shown.

### Desktop Layout

```
┌──┬────────┬───────────────────────────────────────────────────────┐
│  │  ...   │                                                       │
│  │sidebar │  Documents                            [+ New Document] │
│  │  ...   │                                                       │
│  │        │  ┌──────────────────────────────────────────────────┐ │
│  │        │  │ 🔍 Search documents...   Type:[All▾]            │ │
│  │        │  └──────────────────────────────────────────────────┘ │
│  │        │                                                       │
│  │        │  ┌──────────────────────────────────────────────────┐ │
│  │        │  │                                                  │ │
│  │        │  │  Schema-Driven UI Research                       │ │
│  │        │  │  note  ·  Robin  ·  Schema-driven MetadataForm  │ │
│  │        │  │                                                  │ │
│  │        │  │──────────────────────────────────────────────────│ │
│  │        │  │                                                  │ │
│  │        │  │  RJSF Two-Schema Pattern                        │ │
│  │        │  │  reference  ·  Nick  ·  Schema-driven MetadataForm│ │
│  │        │  │                                                  │ │
│  │        │  │──────────────────────────────────────────────────│ │
│  │        │  │                                                  │ │
│  │        │  │  Gateway Pitch Deck                              │ │
│  │        │  │  spec  ·  Sarah  ·  Investigate watermarking libs│ │
│  │        │  │                                                  │ │
│  │        │  │──────────────────────────────────────────────────│ │
│  │        │  │                                                  │ │
│  │        │  │  Embedding Model Results                        │ │
│  │        │  │  report  ·  Karim  ·  Fine-tune contrastive model│ │
│  │        │  │                                                  │ │
│  │        │  │──────────────────────────────────────────────────│ │
│  │        │  │                                                  │ │
│  │        │  │  Flutter Web Performance                        │ │
│  │        │  │  note  ·  Sarah  ·  Nav rail (Outline-style)    │ │
│  │        │  │                                                  │ │
│  │        │  └──────────────────────────────────────────────────┘ │
│  │        │                                                       │
│  │        │  Showing 1–5 of 7                     [< 1  2 >]     │
│  │        │                                                       │
└──┴────────┴───────────────────────────────────────────────────────┘
```

**Steal from Outline**: Each document row is generous — 60px+ height, plenty of padding. The title is 16px semibold, the metadata line is 13px muted. No borders between rows — just whitespace and a hairline divider. The doc_type is a small colored badge.

**Key difference from Outline**: The metadata line shows `type · author · parent task` instead of `type · author · collection`. Since a document can belong to multiple tasks, we show the first/primary task. The full list of parent tasks appears in the detail panel.

**Auto-archive rule**: When a task's status changes to "done", the backend checks all documents attached to it. If ALL parent tasks of a document are now "done", the document's status is automatically set to "archived". This means:
- Active documents have at least one in-progress parent task
- Archived documents have all parent tasks complete
- The Documents screen filters to "active" by default, hiding archived docs
- Users can still find archived docs by changing the status filter

### Document list row design (Detail)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Architecture Overview                                      │   ← 16px semibold
│  spec  ·  Robin  ·  Mar 5                                   │   ← 13px muted
│                                                             │
└─────────────────────────────────────────────────────────────┘

Doc type badge colors (from ui_schema):
  spec       #3b82f6  blue     (filled pill)
  note       #10b981  green    (filled pill)
  report     #f59e0b  amber    (filled pill)
  reference  #94a3b8  slate    (filled pill)
```

### Document Detail Panel

```
┌──┬────────┬────────────────────┬─────────────────────────────────┐
│  │  ...   │                    │                                  │
│  │sidebar │  Documents [+ New] │  Architecture Overview       [×] │
│  │  ...   │                    │                                  │
│  │        │  DASHBOARD         │  spec                            │
│  │        │  ┌──────────────┐  │                                  │
│  │        │  │▶ Schema UI ◀ │  │  ──────────────────────────────  │
│  │        │  │──────────────│  │                                  │
│  │        │  │ RJSF Pattern │  │  # Architecture Overview        │
│  │        │  │──────────────│  │                                  │
│  │        │  │ Flutter Perf │  │  This document describes the     │
│  │        │  └──────────────┘  │  overall architecture of the     │
│  │        │                    │  CMS backend...                  │
│  │        │  GATEWAY           │                                  │
│  │        │  ┌──────────────┐  │  ## Schema Engine                │
│  │        │  │ Pitch Deck   │  │  The schema.config file drives   │
│  │        │  └──────────────┘  │  all entity types...             │
│  │        │                    │                                  │
│  │        │                    │  ──────────────────────────────  │
│  │        │                    │                                  │
│  │        │                    │  Classification                  │
│  │        │                    │    Type     spec                  │
│  │        │                    │                                  │
│  │        │                    │  Attached to                     │
│  │        │                    │    Design schema.config →        │
│  │        │                    │    Implement SchemaLoader →      │
│  │        │                    │  Author                          │
│  │        │                    │    👤 Robin →                    │
│  │        │                    │                                  │
│  │        │                    │  [Edit]  [Delete]                │
│  │        │                    │                                  │
└──┴────────┴────────────────────┴─────────────────────────────────┘
```

---

## Screen 5: Graph (`/graph`)

This screen is unique — no direct precedent from Outline, Kan, or Accountability. But we steal the *framing*:

**Steal from Outline**: The filter controls sit in a collapsible panel on the left (like Outline's sidebar), not as a top bar. This gives the graph maximum vertical space, which matters for spatial visualization.

```
┌──┬────────┬───────────────────────────────────────────────────────┐
│  │  ...   │                                                       │
│  │sidebar │  ┌──────────────┐                                     │
│  │  ...   │  │ Filter       │                                     │
│  │        │  │              │      ○ Sprint 2                     │
│  │        │  │ Entities     │     ╱                               │
│  │        │  │ ☑ project    │ ○ Robin ── ○ Dashboard              │
│  │        │  │ ☑ sprint     │     ╲        │                      │
│  │        │  │ ☑ task       │      ○ Fix ──┘                      │
│  │        │  │ ☑ document   │       auth    ╲                     │
│  │        │  │ ☑ person     │       bug      ○ Arch               │
│  │        │  │              │                 Overview            │
│  │        │  │ Relations    │                                     │
│  │        │  │ ☑ contains   │ ○ Nick ──── ○ Gateway              │
│  │        │  │ ☑ assigned   │     ╲                               │
│  │        │  │ ☑ authored   │      ○ Watermark ── ○ Pitch        │
│  │        │  │ ☑ depends    │        libs          Deck           │
│  │        │  │ ☑ sprint     │                                     │
│  │        │  │ ☑ reference  │                                     │
│  │        │  │              │                                     │
│  │        │  │ Focus        │                                     │
│  │        │  │ [Search... ] │                                     │
│  │        │  │              │                                     │
│  │        │  │ [Collapse ▴] │                                     │
│  │        │  └──────────────┘                                     │
│  │        │                                                       │
└──┴────────┴───────────────────────────────────────────────────────┘
```

### Node info card (appears on tap/hover)

**Steal from Kan**: Kan shows a quick preview when you hover a card before opening the full detail. We do the same: tap a graph node and a small card appears nearby with key info + an "Open" link to navigate.

```
           ○ Robin
           │
    ┌──────┴──────────────┐
    │  Robin               │
    │  person              │
    │                     │
    │  5 tasks assigned   │
    │  2 sprints active   │
    │  3 docs authored    │
    │                     │
    │  [Open My Page →]   │
    └─────────────────────┘
```

---

## Shared Components

### Entity Creation / Edit Modal

**Steal from Accountability Tracker**: The modal is minimal. Semi-transparent backdrop, centered white card, max 500px wide. Form fields are generated from the entity's `metadata_schema` in schema.config, ordered by `ui_schema.ui:order`, labeled by `ui_schema.ui:label`.

```
┌─────────────────────────────────────────────┐
│                                             │
│   ┌───────────────────────────────────┐     │
│   │  New Task                     [×] │     │
│   │                                   │     │
│   │  Name                             │     │
│   │  ┌───────────────────────────┐    │     │
│   │  │                           │    │     │
│   │  └───────────────────────────┘    │     │
│   │                                   │     │
│   │  Status                           │     │
│   │  [Backlog           ▾]           │     │
│   │                                   │     │
│   │  Priority                         │     │
│   │  [Medium            ▾]           │     │
│   │                                   │     │
│   │  Due Date                         │     │
│   │  ┌───────────────────────────┐    │     │
│   │  │ yyyy-mm-dd            📅 │    │     │
│   │  └───────────────────────────┘    │     │
│   │                                   │     │
│   │  Estimate                         │     │
│   │  ┌───────────────────────────┐    │     │
│   │  │                           │    │     │
│   │  └───────────────────────────┘    │     │
│   │                                   │     │
│   │  Labels                           │     │
│   │  ┌───────────────────────────┐    │     │
│   │  │ api, backend  [+]        │    │     │
│   │  └───────────────────────────┘    │     │
│   │                                   │     │
│   │           [Cancel]  [Save]        │     │
│   │                                   │     │
│   └───────────────────────────────────┘     │
│                                             │
└─────────────────────────────────────────────┘
```

Field order and labels are driven by `ui_schema`:
- `ui:order` controls field sequence
- `ui:label` overrides the displayed label (e.g., "Due Date" instead of "deadline")
- `ui:widget` hints at the widget type (date picker, textarea, tags input)

### Relationship Picker

When clicking [+ Add Relationship], a two-step picker:

```
Step 1: Choose relationship type    Step 2: Choose target entity
┌─────────────────────────────┐    ┌─────────────────────────────┐
│  Add Relationship       [×] │    │  Assign to person       [×] │
│                             │    │                             │
│  ▸ Assign to person         │    │  🔍 Search people...        │
│  ▸ Schedule in sprint       │    │                             │
│  ▸ Link to project          │    │  ○ Robin                    │
│  ▸ Depends on task          │    │  ○ Nick                     │
│  ▸ References document      │    │  ○ Sarah                    │
│                             │    │  ○ Karim                    │
│  (only valid rel types for  │    │                             │
│   this entity type shown)   │    │           [Cancel]  [Add]   │
│                             │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
```

### Empty States

**Steal from Outline**: When a list or board has no items, show a centered illustration-free message with a call to action. No sad-face icons, no clipart. Just text.

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                                                 │
│            No tasks yet.                        │
│            Create your first task to get        │
│            started with your project.           │
│                                                 │
│                 [+ New Task]                     │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Loading States

Skeleton screens, not spinners. Show the layout with pulsing gray rectangles where content will be:

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  ████████████████████                           │   ← title skeleton
│  ████████  ·  ██████████  ·  ████████           │   ← metadata skeleton
│                                                 │
│─────────────────────────────────────────────────│
│                                                 │
│  ██████████████████████████                     │
│  ██████  ·  ████████████  ·  ██████             │
│                                                 │
└─────────────────────────────────────────────────┘

Skeleton blocks pulse between #e2e8f0 and #f1f5f9
at 1.5s intervals. Same layout as real content.
```

---

## Design Principles Summary

| Principle | Source | Application |
|-----------|--------|-------------|
| Hierarchy gives context | Outline | Workspace → Project → Documents/Tasks tree in sidebar |
| Content is king | Outline | Minimal chrome, generous whitespace, muted navigation |
| Cards scan in <1s | Kan | Title + priority + deadline only on kanban cards |
| Progressive disclosure | Accountability | Sections collapse, detail panels slide in |
| Skeleton loading | Outline | Layout-matching gray pulses, never spinners |
| Status = color | Kan | Consistent color language for status and priority |
| One interaction model | All three | Click to select → panel opens right (desktop) or navigate (mobile) |
| Project scoping | Outline | Sidebar selection filters all content views |
| Contextual actions | Accountability | Edit/delete only shown when user has permission |
| Schema-driven display | RJSF | ui_schema controls field order, labels, colors, sections |

---

*These wireframes are the contract. Build to these layouts and the CMS will feel like a coherent product, not a collection of screens.*
