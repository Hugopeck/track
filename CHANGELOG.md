# Changelog

## [3.1.0](https://github.com/Hugopeck/track/compare/v3.0.0...v3.1.0) (2026-04-02)


### Features

* **setup-track:** [1.6] add pre-push validation hook ([#80](https://github.com/Hugopeck/track/issues/80)) ([609e33b](https://github.com/Hugopeck/track/commit/609e33b9f7f019d1c23d552fed282e56c27786be))


### Bug Fixes

* **ci:** pass GH_TOKEN to track-complete writeback ([#78](https://github.com/Hugopeck/track/issues/78)) ([24cd28c](https://github.com/Hugopeck/track/commit/24cd28c0f12bac2917b87b6d37aef66248ce6cb3))
* **skills:** copy installs and honor paused projects ([#84](https://github.com/Hugopeck/track/issues/84)) ([527b97e](https://github.com/Hugopeck/track/commit/527b97ee238c2d24ac0dd553cae452288a05741c))
* **track:** complete merged task for [#82](https://github.com/Hugopeck/track/issues/82) ([#83](https://github.com/Hugopeck/track/issues/83)) ([18ae1fb](https://github.com/Hugopeck/track/commit/18ae1fb7f08a3cecaadac1147b730062650eed54))

## [3.0.0](https://github.com/Hugopeck/track/compare/v2.5.0...v3.0.0) (2026-04-02)


### ⚠ BREAKING CHANGES

* **skills:** [8.11] rename init to setup-track ([#70](https://github.com/Hugopeck/track/issues/70))

### Features

* **scripts:** [9.1] add shared task status helpers ([#71](https://github.com/Hugopeck/track/issues/71)) ([c1ce439](https://github.com/Hugopeck/track/commit/c1ce439c1792f772c37bd68bbb5572f068064e44))
* **scripts:** [9.2] add PR lifecycle status sync ([#73](https://github.com/Hugopeck/track/issues/73)) ([e258747](https://github.com/Hugopeck/track/commit/e258747ed45e30ea508c1850338c8a1e81e716f5))
* **scripts:** [9.4] add reconcile warnings ([#72](https://github.com/Hugopeck/track/issues/72)) ([1624ca2](https://github.com/Hugopeck/track/commit/1624ca2e1adb1be73501d2f853f239c86e86dd7c))
* **skills:** [8.11] rename init to setup-track ([#70](https://github.com/Hugopeck/track/issues/70)) ([4e053ac](https://github.com/Hugopeck/track/commit/4e053ac38456d7ff27414a6c88c4d94aaa01d80f))
* **skills:** add discovery loop to create, rewrite decompose for agentic parallelism ([#69](https://github.com/Hugopeck/track/issues/69)) ([708f44d](https://github.com/Hugopeck/track/commit/708f44d31aea7d9677dfe07c2984e54c31ad312b))
* **validate:** [1.4] configurable commit types in conventional-commit-lint ([47607b3](https://github.com/Hugopeck/track/commit/47607b3459ed49e838229faf18df0a54e409ce63))


### Bug Fixes

* **ci:** [8.12] run required checks for release PRs ([#77](https://github.com/Hugopeck/track/issues/77)) ([b6965e2](https://github.com/Hugopeck/track/commit/b6965e2f279cc28cfdd1ea3b2070c7bbe266de3e))
* **init:** correct ruleset status check names to match workflow display names ([#67](https://github.com/Hugopeck/track/issues/67)) ([429ea5d](https://github.com/Hugopeck/track/commit/429ea5d1386e2afac9588f0a1360a626c5a14f1e))
* **install:** add ~/.claude/skills symlinks for Claude Code discovery ([#63](https://github.com/Hugopeck/track/issues/63)) ([f454557](https://github.com/Hugopeck/track/commit/f454557abba1b006a651ed77f37b1362cc28883f))
* **scripts:** [9.3] align validation with status sync ([#74](https://github.com/Hugopeck/track/issues/74)) ([bd434ed](https://github.com/Hugopeck/track/commit/bd434edcf6a1c2d40790f20ce5903e4bce57b4b9))
* **track:** harden post-merge writeback flow ([#68](https://github.com/Hugopeck/track/issues/68)) ([24b4648](https://github.com/Hugopeck/track/commit/24b4648c43c6e2b7e6eb1343d57944396998499c))


### Documentation

* **track:** [9.5] rewrite canonical status docs ([#75](https://github.com/Hugopeck/track/issues/75)) ([2e0a22a](https://github.com/Hugopeck/track/commit/2e0a22a691d185d0c7a44597876579a8b75d5fda))

## [2.5.0](https://github.com/Hugopeck/track/compare/v2.4.2...v2.5.0) (2026-03-31)


### Features

* **hooks:** [8.3] add commit-msg linter and post-commit emitter ([#56](https://github.com/Hugopeck/track/issues/56)) ([3bd91e6](https://github.com/Hugopeck/track/commit/3bd91e67b2c4eb18f805626f5c9dfc273f615cf0))
* **init:** [1.2] add specs directory support ([#51](https://github.com/Hugopeck/track/issues/51)) ([529c84f](https://github.com/Hugopeck/track/commit/529c84fcf3078186095f574c267e1ebd0e8b833a))
* **init:** [8.4] add GitHub ruleset template ([#50](https://github.com/Hugopeck/track/issues/50)) ([c1e0e91](https://github.com/Hugopeck/track/commit/c1e0e914b787c11f50cb5b5b4f8add35a01103b4))
* **scripts:** [8.2] add deterministic scope matching to track-common.sh ([#53](https://github.com/Hugopeck/track/issues/53)) ([b79350e](https://github.com/Hugopeck/track/commit/b79350ea5c6d5557751e8da704fde02fdf00c09e))
* **track:** [1.3] add project frontmatter and blocked status ([#55](https://github.com/Hugopeck/track/issues/55)) ([2761204](https://github.com/Hugopeck/track/commit/27612046fadca044102bd3fcf86b3aae5074ed5e))
* **track:** Track-OSS alignment — project, plan, and tasks ([#48](https://github.com/Hugopeck/track/issues/48)) ([405e69a](https://github.com/Hugopeck/track/commit/405e69ab185bda4f89cd91a4b18853a5007d93f3))


### Bug Fixes

* **skills:** [8.6] deploy hooks and tighten work quick ops ([#59](https://github.com/Hugopeck/track/issues/59)) ([38f0aa2](https://github.com/Hugopeck/track/commit/38f0aa2773f2345ac837aa2967f9954bd3caebf5))
* **track:** [8.10] finish OSS alignment follow-up ([#61](https://github.com/Hugopeck/track/issues/61)) ([99dbdc6](https://github.com/Hugopeck/track/commit/99dbdc62b20ce9830216fc2457b4d6ee37daba15))
* **track:** complete merged task ([5ea242e](https://github.com/Hugopeck/track/commit/5ea242e51de6643d03415d9c6b1350a5f85fae1d))
* **track:** complete merged task ([fbb58a5](https://github.com/Hugopeck/track/commit/fbb58a55c0c00a7616d29d8bf1ae586a047b5e51))
* **track:** complete merged task ([55c3c8d](https://github.com/Hugopeck/track/commit/55c3c8dd6abfbbaa7ce59d89e962867fbd22929a))
* **track:** complete merged task ([5b4203b](https://github.com/Hugopeck/track/commit/5b4203b5055b249ef8c5e815e22d44450d95dc13))
* **track:** complete merged task ([cbfedf6](https://github.com/Hugopeck/track/commit/cbfedf68f545e6c01dc469ca8984c26b376c20d2))
* **track:** complete merged task ([d39b794](https://github.com/Hugopeck/track/commit/d39b794bcd689b495313d205574abb3b685c682e))
* **track:** complete merged task ([0ecbd9b](https://github.com/Hugopeck/track/commit/0ecbd9b6f1d22dce6d99c7613f385385588bff02))
* **track:** complete merged task ([b42b097](https://github.com/Hugopeck/track/commit/b42b0978eab918435a4041441028b846ca857e85))
* **track:** complete merged task ([6304c4c](https://github.com/Hugopeck/track/commit/6304c4c49cffce31406958dfaac572c55a82ff5f))
* **track:** complete merged task ([96e001b](https://github.com/Hugopeck/track/commit/96e001b80abde0e66482a0ee9051030b650e82b9))


### Documentation

* **specs:** [8.9] write local Track server architecture spec ([#54](https://github.com/Hugopeck/track/issues/54)) ([9ba6e14](https://github.com/Hugopeck/track/commit/9ba6e14f9c328f6c4e9e4a7570680949c1786cf5))
* **track:** [8.1] define event contract ([#52](https://github.com/Hugopeck/track/issues/52)) ([f0b1dc1](https://github.com/Hugopeck/track/commit/f0b1dc19d6bfc8bafdcab296ae9175b7943fa6c1))
* **track:** [8.8] rewrite README for open-core OSS positioning ([#62](https://github.com/Hugopeck/track/issues/62)) ([70dd40c](https://github.com/Hugopeck/track/commit/70dd40cbbe55afe30bbfe256fa21866b7f741e2a))

## [2.4.2](https://github.com/Hugopeck/track/compare/v2.4.1...v2.4.2) (2026-03-30)


### Bug Fixes

* **init:** no-task restore conductor.json ([#45](https://github.com/Hugopeck/track/issues/45)) ([21e8531](https://github.com/Hugopeck/track/commit/21e8531a1933504efee05359723e9bac414d79fa))
* **track:** complete merged task ([f5852de](https://github.com/Hugopeck/track/commit/f5852de837452935c0ebf7fe02ed3cea0b7e116d))


### Documentation

* **skills:** [3.7] finalize project 3 cleanup ([#47](https://github.com/Hugopeck/track/issues/47)) ([11e36a2](https://github.com/Hugopeck/track/commit/11e36a215bb93f29208770ee8d9d8ef3129a7270))

## [2.4.1](https://github.com/Hugopeck/track/compare/v2.4.0...v2.4.1) (2026-03-29)


### Bug Fixes

* **todo:** count cancelled tasks in project completion ([#40](https://github.com/Hugopeck/track/issues/40)) ([2804a91](https://github.com/Hugopeck/track/commit/2804a91870dd17f3873d7d9800e0af7ad92149e6))

## [2.4.0](https://github.com/Hugopeck/track/compare/v2.3.1...v2.4.0) (2026-03-28)


### Features

* **init:** [3.3] add Codex CLI AGENTS support ([#39](https://github.com/Hugopeck/track/issues/39)) ([a85ba76](https://github.com/Hugopeck/track/commit/a85ba76bca3902648019079e96f1ca00f1d62455))
* **scripts:** split Track views into board/todo/projects ([#36](https://github.com/Hugopeck/track/issues/36)) ([a3de0da](https://github.com/Hugopeck/track/commit/a3de0da910d97379cdf1b803a669137cce3d2818))


### Bug Fixes

* **config:** [3.0] refocus project 3 and repair CI linkage ([#32](https://github.com/Hugopeck/track/issues/32)) ([709b010](https://github.com/Hugopeck/track/commit/709b0102decffd27ae555046cc1e57c09e2cb2e4))
* **track:** complete merged task ([b0be945](https://github.com/Hugopeck/track/commit/b0be9451a83dc4184b793a719b9c862d7432fe28))
* **track:** complete merged task ([152c340](https://github.com/Hugopeck/track/commit/152c34071c46b93556be45294aea7fa4fe86b59d))
* **track:** complete merged task ([24283d9](https://github.com/Hugopeck/track/commit/24283d94c2e830b9842f5cd72018d22bb729dc7c))
* **track:** complete merged task ([5fabfe0](https://github.com/Hugopeck/track/commit/5fabfe0472baf2441dd30e725150ccb207eb9f97))


### Documentation

* [3.6] add OpenCode and standalone docs ([#35](https://github.com/Hugopeck/track/issues/35)) ([b824f64](https://github.com/Hugopeck/track/commit/b824f64e901ead5665479e6038a543458a2c6cb5))
* **cursor:** [3.1] document rules port plan ([#37](https://github.com/Hugopeck/track/issues/37)) ([1fd50ab](https://github.com/Hugopeck/track/commit/1fd50ab1009f698e51955fdf3bc2d761a78686b5))

## [2.3.1](https://github.com/Hugopeck/track/compare/v2.3.0...v2.3.1) (2026-03-28)


### Documentation

* **conductor:** add Track Git preference guidance ([#30](https://github.com/Hugopeck/track/issues/30)) ([56233d1](https://github.com/Hugopeck/track/commit/56233d1febe60c91fea04a1647070490dbdaf156))

## [2.3.0](https://github.com/Hugopeck/track/compare/v2.2.0...v2.3.0) (2026-03-28)


### Features

* **scripts:** [7.4] support explicit multi-task PR batching ([#27](https://github.com/Hugopeck/track/issues/27)) ([bfd447a](https://github.com/Hugopeck/track/commit/bfd447a1297db3ba6e675bc4bbeae8a9954e93d0))


### Documentation

* **skills:** add skills README and enhance project README ([#28](https://github.com/Hugopeck/track/issues/28)) ([5098f13](https://github.com/Hugopeck/track/commit/5098f13ad15e0edbef95e14129ad53264ae931bf))

## [2.2.0](https://github.com/Hugopeck/track/compare/v2.1.0...v2.2.0) (2026-03-27)


### Features

* **scripts:** add project 7 — automated test coverage ([#22](https://github.com/Hugopeck/track/issues/22)) ([cbc6a2f](https://github.com/Hugopeck/track/commit/cbc6a2f586276a74ff5bc5a2d004811cf1aaa280))
* **scripts:** add unified test runner [7.1] ([#23](https://github.com/Hugopeck/track/issues/23)) ([1b66da2](https://github.com/Hugopeck/track/commit/1b66da21a517840e349fb00cf1ea704cc6d74cce))
* **skills:** add /track:test orchestrator ([#25](https://github.com/Hugopeck/track/issues/25)) ([d207008](https://github.com/Hugopeck/track/commit/d2070085863835b34dd5f407028cd3a85723e46c))


### Bug Fixes

* **init:** upgrade legacy Track repos safely ([#20](https://github.com/Hugopeck/track/issues/20)) ([0054397](https://github.com/Hugopeck/track/commit/005439745dd3793c235d69830ef1996efa6dfa79))

## [2.1.0](https://github.com/Hugopeck/track/compare/v2.0.0...v2.1.0) (2026-03-26)


### Features

* **skills:** add writing style guide, audit fixes, init personality, and growth tagline ([#17](https://github.com/Hugopeck/track/issues/17)) ([a4558c2](https://github.com/Hugopeck/track/commit/a4558c23f606cfe117b607e44c5be4c4d0f0ef8b))


### Bug Fixes

* **scripts:** remove GH_TOKEN gate and align docs to single-mode design ([#19](https://github.com/Hugopeck/track/issues/19)) ([e64be67](https://github.com/Hugopeck/track/commit/e64be671216e7381ff78d3b584eb36f9e639fd41))

## [2.0.0](https://github.com/Hugopeck/track/compare/v1.1.1...v2.0.0) (2026-03-26)


### ⚠ BREAKING CHANGES

* **scripts:** move scripts inside .track/ directory ([#16](https://github.com/Hugopeck/track/issues/16))

> Migration note: repos initialized before v2.0.0 should re-run `/track:init` to move legacy root `scripts/` into `.track/scripts/` and create `.track/plans/`.

### refactor

* **scripts:** move scripts inside .track/ directory ([#16](https://github.com/Hugopeck/track/issues/16)) ([198873a](https://github.com/Hugopeck/track/commit/198873a28a35f05c69a097f7014459abba8c8a64))


### Features

* **skills:** add ownership, modes, and guards to all skill protocols ([#15](https://github.com/Hugopeck/track/issues/15)) ([b8ed283](https://github.com/Hugopeck/track/commit/b8ed2834acb32efc89d0d70e153666010d619c5a))


### Documentation

* launch prep — README rewrite, growth content, and 30 task decomposition ([#13](https://github.com/Hugopeck/track/issues/13)) ([f921402](https://github.com/Hugopeck/track/commit/f92140271d780b62facc87481514b814a5b24633))

## [1.1.1](https://github.com/Hugopeck/track/compare/v1.1.0...v1.1.1) (2026-03-25)


### Documentation

* fix version badge and enhance README for new init flow ([#11](https://github.com/Hugopeck/track/issues/11)) ([ae47769](https://github.com/Hugopeck/track/commit/ae47769c86f1392b0762e8deba283f6e281e8867))

## [1.1.0](https://github.com/Hugopeck/track/compare/v1.0.0...v1.1.0) (2026-03-25)


### Features

* **init:** add markdown import and learn-by-doing onboarding ([#10](https://github.com/Hugopeck/track/issues/10)) ([95f298d](https://github.com/Hugopeck/track/commit/95f298d2fd952a0586c022ce4c98501b2f3c1390))
* **scripts:** add test coverage, script sync CI, and version badge ([#7](https://github.com/Hugopeck/track/issues/7)) ([55c3273](https://github.com/Hugopeck/track/commit/55c3273033f35477b07c3eb7492216c031ee06ad))
* **skills:** improve steering, error messages, and README ([#8](https://github.com/Hugopeck/track/issues/8)) ([52b1881](https://github.com/Hugopeck/track/commit/52b18817f1ef66fe9c88faf613c24df3d098b31c))


### Bug Fixes

* **scripts:** early exit when .track/ missing + dogfood Track ([#2](https://github.com/Hugopeck/track/issues/2)) ([91ba8a9](https://github.com/Hugopeck/track/commit/91ba8a9c8e2d45e927e714398efd5f50aad832c0))
* **scripts:** fix conductor.json setup path and scaffold for init ([#6](https://github.com/Hugopeck/track/issues/6)) ([79b30ab](https://github.com/Hugopeck/track/commit/79b30ab961e6b9074c83b1c746ec6a810fb3a4e2))


### Documentation

* rewrite README for clarity and add setup script ([#9](https://github.com/Hugopeck/track/issues/9)) ([d9d212f](https://github.com/Hugopeck/track/commit/d9d212fef4cd5dbde85861642c61c95eb2bd1de6))
