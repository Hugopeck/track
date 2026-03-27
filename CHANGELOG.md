# Changelog

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
