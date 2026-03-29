# Changelog

## [2.4.2](https://github.com/Hugopeck/track/compare/v2.4.1...v2.4.2) (2026-03-29)


### Bug Fixes

* **init:** no-task restore conductor.json ([#45](https://github.com/Hugopeck/track/issues/45)) ([21e8531](https://github.com/Hugopeck/track/commit/21e8531a1933504efee05359723e9bac414d79fa))

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
