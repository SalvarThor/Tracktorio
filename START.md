# Starting the build

1. Extract this folder somewhere outside OneDrive, for example `C:\dev\train-tycoon`.
2. Open PowerShell in that folder and start Claude Code in plan mode:

   ```
   claude --permission-mode plan
   ```

3. Accept the workspace trust dialog. It lists the allow rules and the extra directory
   from `.claude/settings.json`.
4. Optional check: run `/memory` to confirm CLAUDE.md and SPEC.md loaded.
5. Paste the kickoff prompt below.
6. Review the plan it proposes. When it looks right, switch out of plan mode (Shift+Tab
   cycles modes) and let it run Phase 0.

## Kickoff prompt

```
Read CLAUDE.md, docs/SPEC.md and docs/PLAN.md. We are starting Phase 0.
Propose how you will do Phase 0, item by item, including how you plan to test the
in-game test runner on this machine. Flag anything in the plan, settings.json or the
skills that looks wrong for this Windows setup. Do not start until I approve the plan.
At the end of Phase 0, stop and report: what works, what failed, the findings for
A1-A7, and any decisions you need from me.
```

## Later sessions

```
Continue with the next unchecked item in docs/PLAN.md.
```

You can delete this file once the build is under way.
