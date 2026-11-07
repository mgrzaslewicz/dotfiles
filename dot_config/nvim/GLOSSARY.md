# Neovim config test glossary

Terms for testing the Neovim config: how the tests are layered and how recorded language server responses stand in for live servers.

## Test layers

**Layer A**:
Headless unit and smoke tests in `tests/test_*.lua`. No real language server or build tool runs; LSP responses come from contracts.
_Avoid_: unit suite, fast tests

**Layer B**:
Tests in `tests/e2e/test_*.lua` that run real servers, real Gradle and Maven builds, and DAP against fixtures.
_Avoid_: integration tests, slow tests

**Smoke suite**:
The replayed tests (`tests/test_replay_*.lua`) run against real servers on the fixtures instead of their contracts, outside the PR gate, usually nightly (`tests/run.sh --smoke`). It catches server and protocol drift that contracts cannot see. Not the smoke tests of layer A, which start the full config in a child Neovim.

## Recorded responses

**Fixture**:
A small project under `tests/e2e/fixtures/` that the tests copy before use. Tests build and edit only the copy.

**Recording**:
One saved response from a real server to one request on one fixture.

**Contract**:
All recordings for one fixture and one server, kept in one file under `tests/contracts/`.
_Avoid_: snapshot, mock, golden file

**Replay**:
Serving recordings in place of a live server during layer A tests. A request with no recording fails the test.
_Avoid_: mock, stub server

**Recording refresh**:
Re-recording contracts from live servers. Runs as part of `mise run nvim:update` when a Mason pin moves.
