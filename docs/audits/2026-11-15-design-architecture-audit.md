# MarkForMe — design, architecture and version audit

Date: 15 November 2026. Code reviewed: `main` at commit `cd64e9d` (last code change 13 June 2026).

Re-checked against the agent rules and project rules you committed on 15 November 2026 (`50a687a`), and against your direction that MarkForMe must be **fully AI-enabled, using only Apple's on-device AI**. Where those changed a recommendation, the issue says so.

## Bottom line

MarkForMe has every feature it claims, and its product rules (local only, teacher approves everything, student reports kept apart from teacher records) are sound. Underneath, it is weaker than its passing checks suggest.

- **It can damage teachers' data.** The worst case: a slow scan or AI draft can save into the wrong student's record (Issue 5).
- **A lot of it is hand-written** where Apple already provides the component: the whole screen design system, PDF report layout, parts of the rubric reader. The hand-written screens break dark mode (Issues 13–15).
- **Some of it looks like it works but does not.** The "local AI tools" are never connected to the AI, and the "snapshot tests" take no snapshots. Most of the 21 automated "guardrail" checks only look for particular words in the code (Issues 24–25).
- **The tools and libraries are out of date.** It builds with last year's Xcode and iOS SDK, the database library cannot update because its version setting caps it, and nothing pins exact library versions (Issues 1–3).

Nothing here needs a rewrite from scratch. The structure to aim for is simple: one data model per screen, standard Apple screens and controls, one report builder, one storage path. Moving to it deletes far more code than it adds.

## How this was done

- I checked versions online myself: Apple developer releases, GitHub releases for each library, and GitHub's build-machine images.
- Four Opus 5.5 reviewers each read one area of the code in full:
  - A — how the app is put together and how it saves data
  - B — screens and components
  - C — scanning, PDFs, exports, backups and the curriculum catalogue
  - D — on-device AI, Shortcuts, tests, the build pipeline and docs
- The reviewers only read the code. Nothing was built or run, because this is a Windows machine without Xcode.
- I re-checked the most serious findings against the code myself (listed at the end of this report). All held.
- Their full reports, with file and line evidence for every point, are in the `2026-11-15-details/` folder next to this file. The 84 individual findings are merged into 28 issues below; the appendix maps each original finding to its issue.

| Severity | Findings |
|---|---|
| Critical | 3 |
| High | 22 |
| Medium | 41 |
| Low | 18 |

---

## Decisions I need from you

These change what several fixes look like. My recommendation comes first in each.

**Already settled, no decision needed:**
- **Old data formats:** the agent rules treat the app as pre-production, so old storage formats, the JSON fallback store, migrations and the legacy backup reader are deleted rather than kept (Issues 7, 20, 24).
- **AI:** fully AI-enabled, with Apple's on-device model only. Apple's new iOS 27 option to send requests to its servers (Private Cloud Compute) is excluded.

1. **Raise the oldest supported iOS from 17 to 26?** Recommend yes; with the app fully AI-enabled this matters more.
   - The on-device AI needs iOS 26, so on iOS 17–25 the AI features can never work.
   - Nothing below iOS 26 has ever been tested.
   - Raising it removes most of the "if this iPhone is new enough" code.

   The cost: iPhones older than the iPhone 11 can't install it. Drafting still needs an Apple Intelligence device; on other iOS 26 devices the app says the on-device model is unavailable.
2. **Screen look: native iOS, or the branded "paper" look?** Recommend native iOS (system colours and controls, with your brand colour as an accent). It fixes dark mode and large-text problems automatically and deletes the most code. Keeping the paper look means rebuilding it once as a proper colour set with dark and high-contrast versions (Issues 13–14).
3. **Should an assignment be class-level, with one rubric shared by every student?** Recommend yes. Today every student's record carries its own copy of the rubric and instructions (Issue 22).
4. **Paper size for PDF reports: A4?** Recommend A4. Reports are currently US Letter (Issue 15).
5. **Encrypt the full backup with a password?** Recommend yes. It holds every student's work and your private notes, and is shared through Files or AirDrop. The Teacher Record archive would stay a plain ZIP so it opens on school PCs (Issue 20).
6. **Fold the guided-grading wizard into the assignment overview?** Recommend yes. Today the two use different rules for whether Setup is done (Issue 23).
7. **Approve new tests for the rules that matter?** Your agent rules require explicit approval for added tests. Recommend approving:
   - About six behaviour tests: wrong-student saves, stale links, low-confidence lines, export gates, gradebook totals, restore. These replace the word-checking scripts (Issue 25).
   - One test that runs the existing AI test cases through the real on-device model on an Apple Intelligence device, so drafting quality is measured after each prompt change or iOS update (Issue 24).
8. **Where else should on-device AI help?** See Issue 29. Recommend two additions, both suggestions the teacher confirms: turning a pasted plain-text rubric into criteria, and suggesting curriculum references for an assignment.

---

## Group 1 — Out-of-date versions

**Issue 1: Built with last year's Apple tools, and supports iOS versions nobody tests**

- **What's wrong:** The app builds with Xcode 26.6 and the iOS 26 SDK. Apple released Xcode 27.1 and iOS 27 on 15 October 2026. The Swift language setting is 6.0; current Swift is 6.4.2. The project file uses the older Xcode format (version 56), which makes it hard to edit, and agents have been editing it by hand. The oldest supported iOS is 17, but the build machines only ever test iOS 26.
- **Current example:**

  | Setting | Now |
  |---|---|
  | Xcode used to build | 26.6 (GitHub build machine `macos-26`) |
  | iOS SDK | 26 |
  | Swift language mode | 6.0 |
  | Oldest supported iOS | 17.0 |
  | Oldest iOS actually tested | 26 |

- **Proposed fix:**
  - Build with Xcode 27.1 on GitHub's Xcode 27 build machine.
  - Move to the current Swift language mode and the modern project format, where Xcode picks up files from folders automatically.
  - Set the oldest supported iOS to 26 (Decision 1).
- **New example:**

  | Setting | After |
  |---|---|
  | Xcode used to build | 27.1 |
  | iOS SDK | 27 |
  | Swift language mode | 6.x current |
  | Oldest supported iOS | 26.0 |
  | Oldest iOS actually tested | 26 |

- **Advantages:** The app is built against the iOS that teachers actually run. Many iOS-version checks can be deleted. The newer scanning, AI and screen APIs become usable directly.
- **Disadvantages:** A new compiler version usually turns up some new warnings and errors to fix. Older iPhones are dropped.
- **Recommendation:** Do it first, so every later fix is written against the current tools. Needs Decision 1.

**Issue 2: Library versions float, and the database library is stuck on an old major version**

- **What's wrong:**
  - No lock file (`Package.resolved`) is committed. Without one, each build quietly takes whatever library versions are newest that day, so no build can be reproduced exactly.
  - The database library, GRDB, is set to "6.x only", so it can never reach the current 7.x.
  - The PDF library TPPDF has had no stable release since November 2024.
  - ZIPFoundation's minimum is set to 0.9.0, but 0.9.18 fixed a security hole: a crafted archive could write files outside the folder it was unpacked into.
  - Each weekly automatic check fails because the lock file is missing. That failure is deliberate, but it means the weekly check is permanently red and nobody looks at it.
- **Current example:**

  | Library | Allowed now | Latest | Problem |
  |---|---|---|---|
  | GRDB (database) | 6.x only | 7.12.0 (1 Nov 2026) | Can't update |
  | swift-markdown | 0.2.0 or later | 0.9.0 | Old minimum |
  | TPPDF (PDF layout) | 2.x | 2.6.1 (Nov 2024) | Stale library; see Issue 15 |
  | ZIPFoundation | 0.9.0 or later | 0.9.20 | Minimum allows a version with a known security hole |
  | swift-snapshot-testing | 1.0.0 or later | 1.19.7 | Linked but never used (Issue 25) |
  | Lock file | none | — | Builds not reproducible |

- **Proposed fix:**
  - Upgrade GRDB to 7.12.
  - Raise ZIPFoundation's minimum to 0.9.20 and swift-markdown's to 0.9.0.
  - Remove TPPDF (Issue 15) and swift-snapshot-testing (Issue 25).
  - Commit the lock file. The GitHub build machines are Macs, so a build job can generate it.
- **New example:**

  | Library | Allowed after |
  |---|---|
  | GRDB | 7.12.0 or later, within 7.x |
  | swift-markdown | 0.9.0 or later |
  | ZIPFoundation | 0.9.20 or later |
  | TPPDF, swift-snapshot-testing | removed |
  | Lock file | committed; every build uses the same versions |

- **Advantages:** Reproducible builds, the current database library, the security fix guaranteed, and two fewer libraries.
- **Disadvantages:** GRDB 7 renames a few things, so the storage code needs a migration pass. That code is being reworked anyway (Issue 20).
- **Recommendation:** Do it together with Issue 1.

**Issue 3: The GitHub build pipeline is outdated and wasteful**

- **What's wrong:**
  - The pipeline uses version 4 of GitHub's checkout and upload steps; version 7 is current.
  - Every run rebuilds the app from scratch six or more times, with duplicated jobs.
  - It throws away the library cache each time.
  - It picks "the newest Xcode 26 installed" rather than a fixed version.
  - **Conflicts with your new agent rules:**
    - Every change runs twice: once on the pull request and again when it lands on main. The rules require one pull-request verification path, with no duplicate push-triggered runs.
    - A change that only touches documentation still runs the full app build. The rules allow app jobs to be skipped once the workflow confirms the change is documentation only.
- **Current example:** A pull request that only fixes a typo in the README runs the full set of nine jobs, including six full builds, then runs them all again after merging.
- **Proposed fix:**
  - Run on pull requests only (plus manual runs).
  - Detect documentation-only changes and skip the app jobs for those.
  - Fix Xcode at 27.1.
  - Build once and reuse that build for the unit tests, UI test, screenshots and release build.
  - Keep the library cache, keyed on the lock file.
  - Update both steps to version 7.
  - Move the release-readiness check out of the weekly scheduled run (the run that is permanently red) and into release preparation.
- **New example (same typo fix):** The workflow sees documentation only and skips the app jobs. A code change runs one build plus the tests against it, once.
- **Advantages:** Faster feedback, lower Mac build costs, and stable results.
- **Disadvantages:** The pipeline file needs a careful rework, but the design is standard.
- **Recommendation:** Do it alongside Issues 1–2.

**Issue 4: The repo's own agent skills can't be updated**

- **What's wrong:**
  - The seven skills in the repo's agent folder were copied from a GitHub repository that now returns "not found", so nobody can tell whether they are current.
  - Some are irrelevant to this app: C memory safety, and modernising UIKit apps (this app is SwiftUI).
  - The iOS skills named in the repo's agent instructions (the CI-fixing skill, the Xcode build tool, the SwiftUI review skills) aren't installed for Claude. The SwiftUI review skills are actively maintained.
  - Claude Code itself (2.1.310, latest 2.1.325) updates itself and needs nothing.
- **Current example:** `skills-lock.json` points every skill at `wisdom-in-a-nutshell/agents`, which returns a "not found" error on GitHub.
- **Proposed fix:**
  - Delete the irrelevant copied skills (C memory safety, UIKit modernising, device-interaction).
  - Keep the copied SwiftUI and testing skills only if they are still useful after review.
  - Keep the project's own `gradedraft-*` skills, which your project rules point to.
  - Delete `skills-lock.json`: it is a list of instruction hashes, which your agent rules now prohibit.
  - Install the CI and SwiftUI skills that your project rules list, for the fix work.
- **New example:** Every remaining skill is either the project's own or from a live source, and every one is relevant to a SwiftUI iPhone/iPad app. There is no hash file.
- **Advantages:** Agents get current, relevant iOS guidance during the fixes.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Do it before the fix work starts.

---

## Group 2 — Things that can damage teachers' data or give wrong results

**Issue 5: A slow task can save into the wrong student's record** *(Critical — confirmed against the code)*

- **What's wrong:** Scanning, PDF import, the AI draft and feedback rewrite each take several seconds. When they finish, they save into whichever assignment is open at that moment, not the one they started on. While they run, only the draft and import buttons are switched off; the teacher can still move to another student.
  - **The cause:** one app-wide "currently selected assignment" pointer. Screens call "select this assignment, then act" about 50 times, and the "is this assignment saved?" check is repeated about 60 times.
  - **The same pointer causes more bugs:** the Exports tab exports whichever assignment was opened last without saying which, the Rubric screen can crash on a missing assignment, and a stale link can show another student's data instead of "not found". That last one breaks the repo's own rule that a stale link must fail closed.
- **Current example (illustrative, following the code path):**

  | Step | What the teacher does | What the app does |
  |---|---|---|
  | 1 | On Ava's final review, taps **Draft Feedback Suggestion Locally** | Starts the AI draft for Ava |
  | 2 | While it runs, opens Ben's assignment | The selected assignment becomes Ben's |
  | 3 | The draft finishes | Saves **Ava's** AI draft onto **Ben's** record and deletes Ben's existing final review |

- **Proposed fix:** Each screen gets its own small data model tied to the ID of the assignment it shows. Every slow task remembers that ID and saves to it, and fails openly if it no longer exists. The app-wide pointer and the 60 repeated checks are deleted.
- **New example (same steps):**

  | Step | What the teacher does | What the app does |
  |---|---|---|
  | 1 | On Ava's final review, taps **Draft Feedback Suggestion Locally** | Starts the AI draft for Ava |
  | 2 | Opens Ben's assignment | Ben's screen opens; Ava's draft carries on |
  | 3 | The draft finishes | Saves to **Ava's** record; Ben's record is untouched |

- **Advantages:** Removes the worst data-damage bug and a whole category of similar ones, and deletes a lot of defensive code.
- **Disadvantages:** It touches every screen, so it is the biggest single change in this audit and needs the behaviour tests from Issue 25 to back it up.
- **Recommendation:** Fix first among the code issues.

**Issue 6: A failed "Replace local" restore deletes the teacher's original files, then says everything was rolled back** *(High — two reviewers found it independently)*

- **What's wrong:** When restoring a full backup with "Replace local", the app deletes the existing original scans and PDFs before saving the new data to the database. If that save fails, the originals are already gone, but the message says local data and original files were rolled back.
- **Current example (illustrative):**

  | Step | Result |
  |---|---|
  | Teacher restores a backup with **Replace local**; the database save fails | Original scans deleted |
  | Message shown | "Local data and original files were rolled back" (false) |

- **Proposed fix:** Move the existing files aside first. Delete them only after the database save succeeds, and move them back if it fails.
- **New example (same restore):**

  | Step | Result |
  |---|---|
  | Database save fails | Original scans moved back; nothing lost |
  | Message shown | "Restore failed. Your existing data and files are unchanged." (true) |

- **Advantages:** A failed restore no longer causes permanent loss, and the message tells the truth.
- **Disadvantages:** The restore briefly needs extra disk space.
- **Recommendation:** Fix.

**Issue 7: If storage fails, the app silently carries on with blank or made-up data**

- **What's wrong:**
  - If the database can't open, the app silently switches to an empty backup store, and Settings still says "Stored locally on this device". The teacher sees an empty app, and anything new goes into a second store that the database later can't see.
  - When a stored value can't be read, it is silently replaced. An unreadable scanned-text review status becomes "not needed", which skips the teacher's review step. An unreadable ID becomes a new random ID. One bad entry in a list (the audit trail, export history or evidence) empties the whole list, and the next save makes the loss permanent.
  - With no data at all, a fake blank "New Assignment" is created.
- **Current example (illustrative):**

  | Stored scanned-text status | Shown to the teacher |
  |---|---|
  | (unreadable) | "Review not needed": the teacher-review step is skipped |

- **Proposed fix:**
  - If storage fails, show a blocking error screen that says plainly what failed.
  - Any unreadable value is an error.
  - Where tolerance is truly wanted, choose the cautious state: "needs review" for scanned text, "stale" for a final review.
  - Delete the backup store and the fake blank assignment (settled by the pre-production rule).
- **New example (same record):**

  | Stored scanned-text status | Shown to the teacher |
  |---|---|
  | (unreadable) | "Needs review": the teacher must review the scanned text before an AI draft |

- **Advantages:** Fails openly instead of faking success, as the repo's own rules require.
- **Disadvantages:** A teacher with damaged data sees an error rather than a partly working app. That is the honest outcome.
- **Recommendation:** Fix.

**Issue 8: PDF import invents highlight positions and gives scanner text 100% confidence**

- **What's wrong:**
  - **Invented highlights:** for a PDF that already has typed text, the app makes up a highlight rectangle for each line instead of asking PDFKit where the line is. The made-up boxes are drawn in reverse order (line 1 at the bottom of the page), and from line 29 onward above the page. They are saved as "evidence" and printed in the Teacher Record.
  - **Scanner text trusted completely:** any text on a page at all marks it as typed with 100% confidence. Most school copiers produce PDFs carrying the copier's own text recognition, which is often poor on handwriting. That text skips the app's own recognition and the low-confidence check, and can be confirmed with the one-tap "confirm all". This breaks the repo rule that low-confidence lines need line-by-line teacher action.
  - **Handwriting dropped:** a page with only a printed header and a handwritten answer is treated as typed, so the handwriting is lost.
  - **Locked PDFs:** password-protected PDFs "import" as blank pages.
- **Current example (illustrative copier-scanned essay, page 1):**

  | Line | Text from the PDF | Confidence shown | Highlight drawn |
  |---|---|---|---|
  | 1 | "The Industrial Revolutoin changed" | 100% | At the bottom of the page |
  | 2 | "how peple worked" | 100% | Second from the bottom |
  | — | **Confirm all** | Confirms both in one tap | — |

- **Proposed fix:**
  - Use PDFKit's real per-line positions (`selectionsByLine` and `bounds(for:)`).
  - Treat a page as typed only when its text covers the page meaningfully. Otherwise run the app's own text recognition and keep its confidence.
  - Label copier text with its source ("PDF text layer") instead of a fake 100%, and require each such line to be confirmed individually.
  - Detect locked PDFs and say so.
- **New example (same page):**

  | Line | Text | Confidence shown | Highlight drawn |
  |---|---|---|---|
  | 1 | "The Industrial Revolution changed" | 74% (app's own text recognition) | On line 1 |
  | 2 | "how peple worked" | 58% (low) | On line 2 |
  | — | **Confirm all** | Skips line 2, which needs the teacher's own action | — |

- **Advantages:** The evidence is real, the low-confidence rule actually holds, and handwriting isn't lost.
- **Disadvantages:** Scanning takes longer, because more pages go through text recognition.
- **Recommendation:** Fix.

**Issue 9: Final review can silently throw away typed feedback**

- **What's wrong:** On Final Review, typed student feedback and private notes stay unsaved until **Save Teacher Edits** is tapped. Tapping accept or reject on a criterion, or changing evidence, reloads the review and wipes whatever was typed. Leaving the screen also drops unsaved edits without warning. Across the app there are four different save behaviours:
  - the rubric saves on every keystroke;
  - the wizard's Setup step saves only when **Save** is tapped;
  - scanned-text edits save when the teacher leaves the field;
  - final review saves only when **Save Teacher Edits** is tapped.
- **Current example (illustrative):**

  | Step | Student feedback box |
  |---|---|
  | Teacher types "Strong use of evidence in paragraph 2." | Shows the text |
  | Teacher taps **Accept** on criterion 3 | **Empty**: the text is gone |

- **Proposed fix:** One rule everywhere: edits save automatically shortly after the teacher stops typing. If an explicit Save is kept on Final Review, other actions must not overwrite unsaved text, and leaving asks for confirmation.
- **New example (same steps):**

  | Step | Student feedback box |
  |---|---|
  | Teacher types the feedback | Saved automatically |
  | Teacher taps **Accept** on criterion 3 | Still shows "Strong use of evidence in paragraph 2." |

- **Advantages:** Teachers stop losing work, and every screen behaves the same way.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix.

**Issue 10: Roster import crashes on common spreadsheet headers**

- **What's wrong:**
  - A roster CSV whose header row has two blank or repeated column names crashes the app. Excel exports often have these.
  - Only exact header names and UTF-8 text are understood, so ordinary school exports (for example "Given Name", or Windows text encoding) silently import wrong.
- **Current example (illustrative header row):** `First Name, Last Name, , ` → **the app crashes.**
- **Proposed fix:**
  - Ignore blank columns and keep the first of any repeated name.
  - Accept common header variants.
  - Detect the text encoding.
  - Show any columns that weren't recognised in the roster preview.
- **New example (same header row):** The import preview shows 28 students, with "2 empty columns ignored".
- **Advantages:** No crash, and real school exports work.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix.

**Issue 11: The gradebook CSV counts unapproved AI draft scores as the total**

- **What's wrong:**
  - The gradebook's `total_score` column uses the AI draft's score when there is no approved final review. That breaks the core promise that only teacher-approved grades are final.
  - Other gaps: two characters are missing from the formula-injection guard (tab and carriage return), Excel isn't told the file is UTF-8 (so names with accents garble), and scores print as "7.0".
  - Keeping the hand-written CSV code itself is the right call. The only package alternative has had no release since 2021, and Apple's spreadsheet library turns a student code like "00123" into 123.
- **Current example (illustrative):**

  | student | status | total_score |
  |---|---|---|
  | Zoë Nguyen | AI draft only, not reviewed | 17.0 |

  (opened in Excel: "ZoÃ« Nguyen")
- **Proposed fix:**
  - Leave `total_score` blank until the final review is approved and current.
  - Put any AI suggestion in a clearly named separate column, or leave it out.
  - Complete the formula guard, mark the file as UTF-8, and print scores as "17".
- **New example (same student):**

  | student | status | total_score | ai_draft_suggestion |
  |---|---|---|---|
  | Zoë Nguyen | Not yet reviewed by teacher | *(blank)* | 17 |

- **Advantages:** The gradebook can't pass off an AI suggestion as a grade.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix. I've treated this as a defect rather than a question, because it conflicts with the app's stated product promise.

**Issue 12: The AI never sees the instructions written for it, and its limits are guessed**

- **What's wrong:**
  - **Instructions hidden:** every AI call switches off the option that shows the model the field descriptions in the code. Those descriptions include "quote evidence from the student's text" and "do not infer effort, disability or language background". Apple's guidance is to leave the option on unless the model already knows the format.
  - **Limits guessed:** the size limit is a guess (characters ÷ 3.2, against a fixed 4,096 units). Apple has provided the real measurements since iOS 26.4.
  - **Errors read from text:** errors are identified by searching the error message's wording.
  - **Fake streaming:** "streaming" output is collected and thrown away while the screen says it is streaming.
  - **No model record:** the record kept with each draft doesn't note the iOS or model version. iOS 27 ships a new on-device model, so two drafts of the same essay can differ with no record of why.
- **Current example (illustrative):**

  | Instruction in the code | Seen by the AI? |
  |---|---|
  | "Quote the exact sentence from the student's work as evidence" | No |
  | "Do not infer effort, disability, or language background" | No |

- **Proposed fix:**
  - Remove the switch, so the instructions are sent.
  - Use Apple's real size measurements and its typed error kinds.
  - Show the draft appearing criterion by criterion as the model writes it. That fits a fully AI-enabled app better than a progress spinner.
  - Record the iOS and model version with each draft.
- **New example:**

  | Instruction | Seen by the AI? |
  |---|---|
  | "Quote the exact sentence…" | Yes |
  | "Do not infer effort…" | Yes |

- **Advantages:** Better-grounded drafts, and the fairness instructions actually apply. The fix is small: one setting at four call sites.
- **Disadvantages:** Each request is slightly larger.
- **Recommendation:** Fix.

---

## Group 3 — Hand-written code that Apple already provides

**Issue 13: The screens are a hand-made "stationery" design system dressed up as standard iOS lists**

- **What's wrong:**
  - **One-row screens:** an automated check demanded standard iOS lists and forms. Instead of rebuilding the screens, they were wrapped so that each whole screen sits inside a single list row: the whole assignment list, the whole Rubric page, the whole Final Review editor. As a result there is no swipe-to-delete, no selection, no efficient scrolling for long lists, and the whole page re-measures on every keystroke.
  - **Rubric checklist:** its "tap to jump" probably doesn't work (medium confidence; untested).
  - **Duplication and dead code:** the custom cards, rows and buttons are copied six or more times with four different accent colours, and some are dead.
  - **Small defects:** the Assignments screen has two search fields on the same text, and there are no Xcode previews anywhere.
- **Current example (Assignments screen):** One list row holds a paper card holding every assignment in the class. Swiping an assignment does nothing.
- **Proposed fix:** Rebuild each screen from standard Apple parts:
  - real list rows, with swipe actions;
  - one section per rubric part and per criterion;
  - Apple's standard labelled values, empty states, menus and sharing;
  - on iPad, a proper sidebar layout;
  - previews for each screen.

  Then delete the stationery layer, or keep it only as a colour accent (Decision 2).
- **New example (same screen):** Each assignment is its own row. Swipe left to delete; tap to open. With 300 assignments, scrolling is smooth because only the visible rows are drawn.
- **Advantages:** Large, error-prone code deleted. Native behaviour, accessibility and the iOS 26/27 look come free.
- **Disadvantages:** It is a big visual change, and the paper look goes unless you choose to keep it.
- **Recommendation:** Do it, after Issue 5 so that each screen is rebuilt once. Needs Decision 2.

**Issue 14: Dark mode is broken on screens and can be broken in exported PDFs** *(Critical — two reviewers)*

- **What's wrong:**
  - **Screens:** the "paper" backgrounds are fixed cream colours with no dark version, but the text uses the system colour, which turns white in dark mode. The result is white text on cream cards on Home, Classes, Assignments, Rubric and Final Review.
  - **PDFs:** reports take their text colour from the phone's light/dark setting, so a report exported in dark mode can have white text on a white page. Confidence on the PDF part is medium, because it wasn't run.
- **Current example (phone in dark mode, Assignments row):** near-white text on a cream card: almost unreadable.
- **Proposed fix:**
  - Screens use system colours; or, if the paper look is kept, a colour set with dark versions (Decision 2).
  - PDFs always use fixed black text on white.
- **New example (same row, dark mode):** light text on a dark background, as in every other iOS app. The PDF has black text on white regardless of phone settings.
- **Advantages:** The app is readable at night, and reports always print correctly.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix; it comes almost free with Issue 13.

**Issue 15: PDF reports are laid out by hand twice, with a stale library and US paper size**

- **What's wrong:**
  - **Text glued together:** reports are built by joining text strings with nothing to stop student text being read as formatting, so a student line starting with "#" or "-" becomes a heading or bullet. Dates print in UTC rather than local time.
  - **Two renderers:** that text is then re-read by hand into the TPPDF library. If TPPDF fails, a second hand-written renderer silently takes over.
  - **Paper and dead content:** both renderers use US Letter paper. A whole "report template catalogue" exists that the real reports never use.
  - **Misleading preview:** the PDF "preview" shows the Markdown text, not the PDF.
- **Current example (illustrative Student Report line):**

  | Student wrote | Report shows |
  |---|---|
  | "- my second reason is…" | A bullet point, with the dash removed |
  | Exported at 9:30 am Sydney time | "2026-11-14 22:30 UTC" |

- **Proposed fix:**
  - Build each report once as a structured document, with student text marked so it can't become formatting.
  - Produce the PDF through Apple's built-in print-to-PDF on A4, and the Markdown file from the same document.
  - Show the real PDF in the preview.
  - Delete TPPDF, both hand-written renderers and the unused template catalogue.
- **New example (same line):**

  | Student wrote | Report shows |
  |---|---|
  | "- my second reason is…" | "- my second reason is…" exactly as written |
  | Exported at 9:30 am Sydney time | "15 Nov 2026, 9:30 am" |

- **Advantages:** One renderer, correct paper size, faithful student text, and one less library.
- **Disadvantages:** The report's visual style has to be designed once more.
- **Recommendation:** Do it. Needs Decision 4 (A4).

**Issue 16: Text recognition uses Apple's older API**

- **What's wrong:** Scanning uses Vision's older text-recognition request. iOS 26 adds a request that understands document structure (paragraphs and tables) and works in modern Swift.
- **Current example:** A scanned two-paragraph answer comes back as a flat list of lines, so paragraph breaks are lost in the scanned text.
- **Proposed fix:** Use the newer request (`RecognizeDocumentsRequest`, iOS 26) and delete the older path (needs Decision 1).
- **New example (same scan):** Comes back as two paragraphs of lines, each line with its own confidence and position.
- **Advantages:** Better structure and less code.
- **Disadvantages:** Recognition quality must be re-checked on real scans.
- **Recommendation:** Do it, after Decision 1.

**Issue 17: The rubric reader is half proper Markdown parsing and half line-by-line text matching**

- **What's wrong:** Rubric import claims to use the swift-markdown parser, but half of it still matches text line by line, and the two halves can read the same rubric differently.
- **Current example (illustrative):** A rubric table with a points range in a heading is read as 2 criteria by one half and 3 by the other. The preview shows the second reading.
- **Proposed fix:** Read rubrics only through the swift-markdown document structure (headings, lists, tables), with clear warnings for anything it can't place.
- **New example (same rubric):** It is read one way, consistently, with a warning on the ambiguous points range.
- **Advantages:** Predictable imports and less code.
- **Disadvantages:** Some messy rubrics that half-worked may now need light tidying.
- **Recommendation:** Fix.

**Issue 18: Excel roster files are read with a hand-written text filter**

- **What's wrong:** XLSX roster files are read by stripping XML tags with a text pattern, which breaks on shared strings and special characters.
- **Current example (illustrative):** A student named "O'Brien & Sons" in an XLSX file imports as "O&apos;Brien &amp; Sons".
- **Proposed fix:** Use the maintained CoreXLSX package (0.14.2), or drop XLSX and accept CSV only.
- **New example (same file):** The name imports as "O'Brien & Sons".
- **Advantages:** Correct names.
- **Disadvantages:** Adds one small library, unless XLSX is dropped.
- **Recommendation:** Use CoreXLSX.

---

## Group 4 — How the app is put together, and speed

**Issue 19: One giant control object drives every screen and does heavy work on every keystroke**

- **What's wrong:**
  - One object with about 30 observed properties drives all 17 screens, using the older pattern that refreshes every observing screen on any change (`ObservableObject` rather than `@Observable`).
  - Every keystroke in an assignment field:
    - re-runs the AI readiness check;
    - warms up the AI model;
    - rebuilds the packet preview;
    - recomputes "has this changed" fingerprints by converting whole records to JSON;
    - adds a "draft marked stale" entry to the audit trail (once a draft exists);
    - saves every assignment to the database.
  - Lists re-sort on every edit, so rows jump while the teacher types.
- **Current example (illustrative):** Typing a 40-word rubric note after a draft exists adds roughly 40 "draft marked stale" audit entries and saves every assignment about 200 times.
- **Proposed fix:**
  - Move to `@Observable` with one small model per screen (shared with Issue 5).
  - Save shortly after typing stops, and mark the draft stale once.
  - Cache fingerprints.
  - Keep list order stable while editing.
- **New example (same typing):** One save after the teacher pauses, and one "draft marked stale" entry.
- **Advantages:** Faster typing, a cleaner audit trail and less battery use.
- **Disadvantages:** Done together with Issue 5, so the same caution applies.
- **Recommendation:** Do it with Issue 5.

**Issue 20: Data is stored two or three times, slowly, on the main thread**

- **What's wrong:**
  - **Every save:** each save writes a full JSON copy of every assignment and also deletes and re-inserts every assignment's database rows. All of this happens on the main thread, so the screen can stutter.
  - **Drifting copies:** some save paths update the rows but not the JSON copy, so the two drift apart.
  - **Unused schema:** about 23 database tables are created but never used, yet the data-model document presents them as the design. There are no indexes and no links between tables.
  - **Bloated backups:** backups store each record up to three times, uncompressed, and a restore reads the archive three or four times.
  - **More main-thread work:** large page images and restore unpacking also run on the main thread.
  - The recorded reason (an escape hatch during migration) doesn't apply to an app that has never shipped.
- **Current example:** Editing one student's feedback, in a class of 30, rewrites all 30 assignments in both formats.
- **Proposed fix:**
  - One storage path: GRDB 7, with record types mapped directly to tables.
  - Save only the record that changed, off the main thread.
  - One clean schema, with links between tables and indexes, replacing the migration history (settled by the pre-production rule).
  - Delete the JSON copy, the backup store and the unused tables (settled by the pre-production rule).
  - Backups store each record once, compressed, with optional encryption for the full backup (Decision 5).
- **New example (same edit):** One database update for that one student's record.
- **Advantages:** Faster, simpler and no drift between copies. SwiftData was considered and is worse for this app; keep GRDB.
- **Disadvantages:** Real work, and safe only behind behaviour tests.
- **Recommendation:** Do it. Needs Decision 5.

**Issue 21: The 75 MB curriculum catalogue is fully loaded at app start**

- **What's wrong:** The Australian Curriculum catalogue ships as 75 MB of JSON split into 37 pieces plus a 22 MB search index. The app decodes all of it, on the main thread, at startup. The splitting gains nothing.
- **Current example:** Launching the app decodes about 75 MB of curriculum before the teacher has opened the curriculum screen.
- **Proposed fix:** Ship it as one read-only SQLite database with built-in full-text search, through GRDB, which the app already uses. Searches query only what's needed.
- **New example (same launch):** Nothing loads until the teacher searches, and the search returns in milliseconds.
- **Advantages:** Faster launch, less memory and a much smaller generator script.
- **Disadvantages:** The generator script has to change its output format.
- **Recommendation:** Do it.

**Issue 22: Each student's record carries its own copy of the rubric**

- **What's wrong:** What the app calls an "assignment" is really one student's submission. Importing a roster copies the whole rubric, instructions, answer key and exemplar into each student's record. Classes are matched by their name text rather than an ID, and a student's name is stored in three places.
- **Current example (illustrative):**

  | Record | Rubric |
  |---|---|
  | Persuasive essay — Ava | Copy 1 |
  | Persuasive essay — Ben | Copy 2 (Ben's copy edited separately) |

  Renaming the class "7B" to "7B English" splits it into two classes on screen.
- **Proposed fix:** A class has an assignment; the assignment has one rubric and setup; each student has a submission under it. Use IDs everywhere (Decision 3).
- **New example (same class):**

  | Assignment | Rubric | Submissions |
  |---|---|---|
  | Persuasive essay (7B English) | One shared rubric | Ava, Ben, … |

- **Advantages:** Matches how teachers think, one place to fix a rubric, and no name-matching bugs.
- **Disadvantages:** Changes the data model, so it is best done together with Issue 20.
- **Recommendation:** Do it, if you agree in Decision 3.

**Issue 23: Navigation, the wizard and smaller screen issues**

- **What's wrong:**
  - **"Next student":** keeps stacking Final Review screens, there is no saved navigation state, and the iPad sidebar is a set of plain buttons.
  - **Wizard:** the guided-grading wizard's Setup step uses different rules from the assignment overview's Setup step.
  - **Shortcuts:** a Shortcut run while the app is already open isn't handled until the next launch.
  - **Photos:** the photo picker takes only one photo, so multi-page work can't be imported from Photos.
  - **Small issues:** attachments show a misleading "Not started" status; some screens break at the largest text sizes; the scanned page image is decoded on every screen redraw.
- **Current example:** After grading 10 students with **Next student**, pressing Back 10 times walks through every previous Final Review.
- **Proposed fix:**
  - One navigation model with proper routes, and an adaptive sidebar on iPad.
  - "Next student" replaces the current screen rather than stacking.
  - Fold the wizard into the overview (Decision 6).
  - Handle Shortcuts while the app is open.
  - Allow selecting several photos, and fix the smaller items.
- **New example (same session):** Back returns to the class list in one tap.
- **Advantages:** Predictable navigation that works properly on iPad.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Do it with Issue 13.

---

## Group 5 — Fake, dead or "theatre" code

**Issue 24: Features that look ready but aren't connected, and test code shipped in the app**

- **What's wrong:**
  - **AI tools never connected:** about 580 lines of "local AI tools" exist in two parallel versions, but neither is ever given to the AI. Even so, the AI Readiness screen shows "Local tool policy — Ready". That breaks the repo's own no-fake-behaviour rule.
  - **Evaluation fixtures never run:** the AI "evaluation fixtures" are never run against the AI.
  - **Shipped test code:** batch-readiness and evaluation code is test-only but ships in the app, and so do the UI-test fixture data and launch switches.
  - **Dead code:** several screens and components are dead (`GradeResultView`, `StationeryScreen` and others), and there is an old "legacy JSON" restore path.
- **Current example:** AI Readiness screen: "Local tool policy — **Ready**" (no tool is ever used).
- **Proposed fix:**
  - Delete the unconnected tools layer and its "Ready" line, the dead screens and the legacy restore path (settled by the pre-production rule).
  - Move test-only code and fixtures out of the app.
  - Turn the AI test cases into a real check: one device test that runs them through the actual on-device model (needs Decision 7).

  **Note on full AI enablement:** removing the tools layer removes no AI capability. The AI never used it; drafting already receives the whole reviewed text and rubric. If a real need for model tool calls appears (for example, letting the model look up one criterion while drafting criterion by criterion), build that one tool properly with Apple's Tool API at that point.
- **New example (same screen):** The "Local tool policy" line is gone; every line shown reflects something real. Before a release, the device test drafts all ten AI test cases (strict answer key, a prompt-injection attempt, an EAL/D-sensitive case and so on) and reports where drafts changed.
- **Advantages:** The app stops claiming things it doesn't do, a lot of code goes, and AI drafting quality becomes measurable.
- **Disadvantages:** The device test needs an Apple Intelligence Mac or iPad to run.
- **Recommendation:** Do it early; it shrinks everything else.

**Issue 25: The automated checks mostly look for particular words in the code instead of testing behaviour**

- **What's wrong:**
  - **Word checks:** most of the 21 Python "guardrail" scripts check that particular wording exists in particular files, for example that the exact line `@Published var preparedExportArtifact` is present. Coding agents wrote them as a substitute for tests they couldn't run on Windows. As a result they:
    - protect dead code from deletion;
    - block the modernisation in Issue 19;
    - stand in for real tests: the stale-link rule from Issue 5 has no behaviour test at all.
  - **"Snapshot" tests:** they only check that a screen's internal class name contains "CollectionView". The snapshot library is linked but never used.
  - **Untested AI logic:** the AI retry logic has no tests, and the only test of the real AI service asserts nothing (`XCTAssertTrue(true)`).
  - **Old prompt:** the prompt-safety tests check a prompt that production no longer sends.
  - **Linting:** it is configured to check almost nothing.
  - All 561 tests use the older XCTest framework.
- **Current example:** If the export screen were rewritten correctly but `@Published var preparedExportArtifact` were renamed, the build would fail. If the stale-link rule broke, nothing would fail.
- **Your new agent rules settle the main point:** tests must not assert source spelling, wrapper names or documentation wording. Most of these scripts do exactly that, so they go.
- **Proposed fix:**
  - **Keep** the checks that test something real: the no-network scan, the curriculum data validation and the end-to-end UI test.
  - **Extend the no-network scan** to fail on Apple's iOS 27 server-model option (Private Cloud Compute) and on any AI model other than the on-device one. Using the scan that already exists keeps one owner for the "on-device AI only" rule. Without this, the rule can be broken with one line the scan doesn't see today.
  - **Strengthen existing tests:** where an existing test already covers a rule (for example the view-model hardening tests), make it test the real behaviour.
  - **Add new tests only with approval:** the behaviour tests that have no existing owner (wrong-student saves, stale links, low-confidence lines, export gates, gradebook totals, restore) need your approval under the new rules (Decision 7). Write them in Apple's newer Swift Testing framework.
  - **Delete** the remaining word-checking scripts, the fake snapshot tests, the unused snapshot library and the tests of the old prompt.
  - **Update the validation command list** in PROJECT_RULES.md (your file) to match: `repo_health.py` currently runs the scripts being deleted.
- **New example (same change):** Renaming the variable passes. Breaking the stale-link rule fails a named test: "Opening a deleted assignment shows Not Found and changes nothing."
- **Advantages:** Checks that catch real breakage and allow improvement, as your rules now require.
- **Disadvantages:** Writing the behaviour tests takes real effort up front.
- **Recommendation:** Do it first, before the big rework in Issues 5, 19 and 20, so those changes are protected.

**Issue 26: "File protection hardening" does nothing, and sensitive exports pile up**

- **What's wrong:**
  - **Protection setting:** the "hardening" sets the file-protection level that iOS already applies by default.
  - **Leftover exports:** exported student reports and backups are never deleted from the app's temporary and Documents folders.
  - **Leftover scans:** re-importing student work leaves old page images on disk, with evidence still pointing at deleted lines.
- **Current example:** After a term of exports, the Documents folder holds dozens of past student reports and full backups that the teacher can't see in the app.
- **Proposed fix:**
  - Use a stronger protection level where it matters, or stop claiming hardening.
  - Delete export files once shared, and clean up replaced scans.
- **New example:** After sharing, the export file is removed. Only the teacher's own saved copies remain.
- **Advantages:** Less sensitive data lying around, and accurate claims.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix.

**Issue 27: The documents are a sprawl that hides the few that matter**

- **What's wrong:**
  - **Volume:** a 92 KB audit file in the repo root, a stale "next prompt" file, old v2/v3 implementation notes, a second copy of the core rules outside the ledgers folder, and duplicated release kits.
  - **Inaccuracy:** some documents describe things that aren't true. The data-model document lists the unused tables as the design, and the next-validation prompt refers to a patch file that was applied long ago.
  - Your new README and rule files already fix the entry point. The six ledgers and the duplicate core-rules file were deleted on 15 November at your instruction; their still-valid product rules now sit in PROJECT_RULES.md.
- **Current example:** The README points agents to the data-model document, which describes about 23 tables that the app never uses.
- **Proposed fix:**
  - Delete the root audit file, the next-validation prompt, the v2/v3 notes and the duplicate release kit.
  - Rewrite the architecture and data-model documents to match the code after the fixes.
  - Once fixes are done, delete this audit too: the agent rules say documentation must describe the current system, with no archived history.
- **New example:** Every document the README links to describes the app as it actually is.
- **Advantages:** Faster, more accurate onboarding for you and for agents.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Do it last, once the code matches.

**Issue 28: Shortcuts are over-built for a first release**

- **What's wrong:** There are seven Shortcut actions, including AI Readiness, Packet Preview, Latest Draft and AI Constraints, and they pass data through a hand-built mailbox file. Apple's current Shortcuts API handles opening a specific screen directly.
- **Current example:** Seven actions, plus a temporary protected file with a 15-minute expiry used to hand data to the app.
- **Proposed fix:**
  - Keep three actions (Open Assignment, Add Pasted Student Work, Create Assignment), using Apple's current open-screen pattern, and delete the mailbox.
  - Open Assignment takes a destination, such as AI Draft, Final Review or AI Readiness. The AI screens stay one Siri request away, so nothing is lost for full AI enablement.
- **New example:** "Open Assignment → Persuasive essay, Ava → AI Draft" opens that screen directly.
- **Advantages:** Less code and fewer edge cases, with the same reach.
- **Disadvantages:** Fewer separately named Siri phrases.
- **Recommendation:** Do it.

**Issue 29: On-device AI is used only for drafting and rewording feedback**

- **What's wrong:** Your direction is a fully AI-enabled app using Apple's on-device model only. Today the AI does two jobs: the rubric draft, and rewording feedback. Other setup steps are entirely manual even where the on-device model could suggest and the teacher confirm:
  - **Rubric setup:** the rubric reader only recognises Markdown structure (headings, lists, tables). The teacher must reformat a rubric copied from a document or PDF before the app can find its criteria.
  - **Curriculum:** the teacher searches and maps curriculum references entirely by hand.

  These are candidates, not defects. No product rule requires them, so they need your decision (Decision 8).
- **Current example (illustrative):** A teacher pastes a rubric from a Word document as plain paragraphs ("Thesis — 4 marks: clear position…"). The rubric preview finds no criteria, and the teacher must retype it as a Markdown table.
- **Proposed fix:**
  - **Rubric setup:** when the rubric isn't Markdown, offer "Suggest criteria with on-device AI". The model returns a structured list of criteria, points and level descriptors, which the teacher edits and confirms in the existing rubric preview.
  - **Curriculum:** offer "Suggest curriculum references" from the assignment's rubric and instructions, limited to codes that exist in the bundled catalogue, each confirmed by the teacher.
  - **Both:** when the on-device model is unavailable, the buttons show the local-unavailable state, and manual entry still works.
  - **Not recommended:** feeding page images straight to the AI (new in iOS 27) for grading. It would skip the teacher's line-by-line scanned-text review, which your project rules require.
- **New example (same rubric):** The preview shows "Thesis — 4 points — 4 levels", suggested by on-device AI, and waits for the teacher to confirm.
- **Advantages:** The AI helps at setup, where teachers spend real time, while the teacher still confirms everything.
- **Disadvantages:** Each suggestion feature needs its own prompt, its own checks and its own device testing.
- **Recommendation:** Add both after the core fixes. Decision 8.

---

## Recommended order of work

1. **Update the toolchain and libraries:** Issues 1–4.
2. **Write the behaviour tests and remove the fake and dead parts:** Issues 25 and 24, so the rework is protected and smaller.
3. **Fix data damage:** Issues 5 and 19, then 6–12.
4. **Rework storage and the data model:** Issues 20–22.
5. **Rebuild the screens and reports on Apple components:** Issues 13–18 and 23.
6. **Tidy up:** Issues 26–28.
7. **Extra on-device AI features, if approved:** Issue 29.
8. **Release blockers:** commit the lock file, add the support website and contact details, run manual device testing.

## Keep as is

- The product rules: local only, teacher approves every grade, student reports kept apart from teacher records.
- Typed AI output checked by the app's own validator, and never truncating student work silently.
- Keeping student identity out of the AI prompt for fairness, and the protection against instructions hidden in student work.
- The restore safety checks on paths and sizes, and the restore preview.
- The "assignment not found" screens, the scanned-text highlight mapping, and the wizard's step logic.
- The document-scanner bridge (still needed; Apple has no SwiftUI scanner).
- Anonymous export filenames.
- ZIP for the Teacher Record archive.
- GRDB rather than SwiftData.
- The hand-written CSV writer (with the Issue 11 fixes).
- The real end-to-end UI test.
- Strict concurrency checking, which is already on.

## Checked against the code by me

- **Issue 5:** the AI draft saves through the live "selected assignment" pointer after waiting. Only buttons are disabled while it runs; navigation is not.
- **Issue 10:** roster import builds its column lookup in a way that crashes on repeated names.
- **Issue 21:** 75 MB of curriculum JSON, all decoded by the loader.
- **Issue 12:** the AI instructions are switched off at four call sites.
- **Issue 24:** no tool is connected to the AI anywhere.
- **Issue 14:** the paper colours are fixed values, with no dark versions and no light-mode lock.
- **Repo untouched:** the repo was unchanged after all four reviews.

## Appendix — where each original finding went

| Issue | Findings |
|---|---|
| 1 | D-17, D-18 |
| 2 | D-15, A-13 (GRDB), C-06 (TPPDF), C-13 (ZIPFoundation minimum) |
| 3 | D-16 |
| 4 | D-21 |
| 5 | A-01, A-02, B-04, B-08, B-18 |
| 6 | A-09, C-04 |
| 7 | A-04, A-08, A-16, A-18 |
| 8 | C-02, C-03 |
| 9 | B-05 |
| 10 | C-10, C-11 |
| 11 | C-12 |
| 12 | D-01, D-04, D-05, D-08, D-09 |
| 13 | B-02, B-09, B-10, B-13, B-17 |
| 14 | B-01, C-05 |
| 15 | C-06, C-07, C-08, B-16 |
| 16 | C-15 |
| 17 | C-09 |
| 18 | A-21 |
| 19 | A-03, A-12, A-14, A-20, B-03, B-07 |
| 20 | A-05, A-06, A-07, A-11, A-13, A-17, C-13, C-14, B-06 |
| 21 | C-01 |
| 22 | A-10 |
| 23 | B-11, B-12, B-14, B-19, B-20, A-15, C-18 |
| 24 | D-02, D-11, A-19, C-20, B-09 (dead parts), D-23 |
| 25 | D-03, D-06, D-07, D-13, D-14, D-22, B-15, D-10 (cloud rule) |
| 26 | C-16, C-17, C-19 |
| 27 | D-20 |
| 28 | D-12, D-10 |
| 29 | Added after your 15 November AI direction (not from the reviewers) |
