# Trailer strip — the recovery mapping

Every commit rewritten on 2026-08-17 to remove the `Co-Authored-By: Claude` trailer, old SHA to new.
The trees are byte-identical; only the message changed. Authored by teohondascully before and after.

**The backup is gone, and this table is now the whole record.** The pre-rewrite history was preserved at
`pre-trailer-strip` = `03034e8fe92028a39ad3220593bca8cf747c229b`, pushed to origin as
`refs/backup/pre-trailer-strip`. It was then deleted deliberately, along with `refs/original/*`, because
the backup held the last surviving copies of the 23 trailer messages — the safety net was the final thing
carrying the thing it protected against, so it could not both exist and let the strip finish.

**Nothing that was committed is lost.** No tree ever changed: every old SHA below and its new SHA name
byte-identical content, and the author is `teohondascully` on both sides. What is gone is the *message
text* of 23 commits, which was the point. The old SHAs no longer resolve in any repository; they are
retained here so a future reader can still trace a citation from an old log, doc, or comment to the commit
it meant.

```
OLD                                         NEW                                         SUBJECT
7a1b427f3110dd4b05e7aa26b44a3196a0c64d87    ba029b985811328fb1d86b35f59331f6b9e9a902    test(harness): register the layer that proves a Bazaar has art
c769372ab88976f24c3650b278cbc300d9a74948    4c78dc3dfba6eb2541b11161af3d5c0f459bfaa2    docs(peers): the index is shared, and a freeze must claim the tree
0c73c89e5f41ec8f5aca74b24aac359f8100349f    7d7cf6e381cffd83f30bd91df2c09144bad4a08c    docs(handoff): item 5 is 49 layers in 8 variants, not 41 byte-identical
c191f5e9f771d7eb95c3c930f4fe390ab04e31d6    b6f6c9f173c09ea6095e63e8fba2a5b74f80ff96    perf(harness): the 120fps budget existed, had never run, and could not be measured
b4de6ae1b6c90165669c4f6c8625251a4153fa1c    b9f2bd06aa9b758e91fc113a145ef7a994db2882    docs(audit): commit the auditing session's response before it can be lost
8d72dae196e78e91f6374757f9cdb2cbc45c0781    afd936be20307d3c12e3fb76c9a6cc60c35a159e    test(perf): the DIG phase could time a body standing still and call it mining
8e64818fcb38265ca2adcbe68e7a7c331c1a33f0    c65449574272601b3a5c1e56087dc621f94071ab    docs(handoff): Strike 9 — the reply to the auditing session
25494c42de0efbb61e8a18f3df3fa0c631591684    11acae6773e735f5fe03f5f05be1b02b5581514b    perf(bake): hand the fine grid over whole, and stop passing a paced number
9bac504e5bb3ea1dab23b584da15b980cf0b781e    3fef5b52da1e70ae969afb6d018d0c0008b2c5cf    perf(bake): falsify the second hypothesis about the 1.5s load freeze
a5c5186865d88f55ea02d4e01ad323a430b52e50    33714e6cdfbe4bfeba6a45864e26fcf127983132    test(perf): make DIG measure fixed WORK, so a 15% win would be visible
a42cf76a3f073f15bb725ba626c70a60104c2c81    b69ca65a59907f2ac7eb6752d41caa89e5beb8d0    fix(save): the backup generation was spent by the save that followed a recovery
f7b78a55cd2b0a7ffc0dfecec1357434ec6b2cdf    af3ec8bfda6d96c2013310b4bdcebd2586aef567    fix(harness): the sentinel could leave its marker at the player's save path
d933159fb0646801355ca934a92f83b2eb488be4    86ce3a1b129e6df5b379d80997e6f6751f0289e8    fix(harness): the save gate checked two of the three ways to register a layer
4e907e8aeef1faccad70521005b1014815e5d5a7    6a4faa1f9fcc6c652c034cc7328f0baf132e4740    docs: strike 10, and three more shapes that fooled somebody today
0e15aa6de45ac26d35d64685e8eedf0397afb89f    c60ccf776aafbc264f24bafab8b2f8d442330bb0    docs(audit): the numbers behind strike 10, both configurations
688155dffcb9073551d621e8a5a48b0fd169fa64    08c7414cb9425c7c64d663cc8c4458ad66f94755    docs(comments): three comments that asserted numbers the measurements refuted
c607bae132474204e142ad4d6d7c8f8e9a8ca529    053129672d983fe4358b88cca93dc2defc29214e    fix(corpus): the sweep could fabricate the finding it went looking for
3d47aca094cdde9322f8b38dc21c61be142243ac    2587173500fb29da0953f7a9db7cff75e78ab0e7    fix(agent): dig_down_to declared success on a world where the target was air
cf9ec35fc1b0f8519d3797a6ab58e005576ff36a    e15758c7139f133c1fc8aee87ab72ea5d9bda55d    docs: strike 11 — queue item 3 closed, and the shape it taught
1aea9af80feb90974bb2c3f46fbdc1523abf1c23    0d5a9d158f1a45f9771f542d6e83d7277fbbf1f8    refactor(harness): one _check, and a written answer to "how do I add a layer"
f31baa208e98755c07e9bbed7e3169b53527d44d    869ac2965810dc9b8d51e33fca6d24aaf3f240e7    refactor(harness): fold the two newest layers onto the shared _check
5c6d45e161e49dc887a414f1f007923df7dbff53    7746d1e629a66a50e3b12530ba2645ea6803333b    perf(harness): report missed deadlines, because p95 cannot answer "120fps"
65009ea00eb44f98558f70832bd253024e98fd20    24ea6f690cfb3b126ba71f329d38aa5106429d7b    docs: strike 12 — the 120fps headline was wrong in the game's favour
```

## Worktree branches, stripped 2026-08-17

Same rewrite, trees byte-identical (`git diff <old> <new>` = 0 lines on both).

```
BRANCH                    OLD TIP                                     NEW TIP
audio-per-material        f8fb057e06b8fb27a71e4e07ec0380d08eaf005f    ec1912071b64aad4f975ffce99b895ffabc6c256
presentation-glyphs       805f68645c92e1768b005f9da3844c8232f0a9d5    aa59ddb841d8ac984390b8d3c567df58d96d5ead
```

## The backup ref was removed

`pre-trailer-strip` / `refs/backup/pre-trailer-strip` held the 23 original messages by design, which
made it the last thing in the project carrying the trailer. Removed at the user's instruction:
**zero commits anywhere.** The strip is no longer reversible from git. What survives is this file —
every old SHA against its new one — and the fact that the rewrite changed no tree, so nothing that
was ever committed has been lost. Only the old message text is gone, which was the point.
