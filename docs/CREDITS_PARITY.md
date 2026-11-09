# Native end credits

`credits_roll.gd` preserves the source `game/index.html` credit content, cast order, original face atlas frames, title painting, circular portrait clipping, Commune wording, linear scroll, Skip control, 22–40 second duration rule and 600ms completion delay. The native 960×540 layout uses touch-sized controls and bundled fonts. The source reduced-motion 1.6× duration and paid/unpaid Crunch text are supported by the presentation API.

`main.gd` only permits credits after the verified six-world main-stage chain, including the source `6-ending` story after 6-6. The menu offers credits replay after completion. Skipping, timing out and Android Back return to the campaign menu; foreground/background events pause both the roll and ending music. Neither viewing nor replaying credits writes progress or grants rewards. Original score title and ending tracks are separate authored music, not a claim of source audio identity.

An exhaustive search of supplied `game/**/*.html` and `game/**/*.js` finds only the credits read of `bd-crunch`, with no setter or repayment interaction. The native host therefore retains the source default, “Crunch, who still owes everyone 85p.” It does not invent a payment mechanic or paid state.

Verification:
- `test_credits_roll.gd`: 43 presentation/content/timing/replay/masking assertions, including native CanvasItem submission.
- `test_campaign_completion.gd`: 237 real-main synthetic GUI/story/save/accounting checks through all 36 main-stage transitions and all 19 normal progression scenes, including ending, focus lifecycle and actual touch Skip/replay.
- These deliberately synthetic clear fixtures do not prove gameplay completion. Full input-driven world suites provide that separate evidence.
- A native desktop framebuffer screenshot revealed rectangular portrait spill; a real circular alpha mask corrected it. Physical-phone rendering and accessibility validation remain open.
