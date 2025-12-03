# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Submodule: Pauser

This is a Foundry smart contract submodule for the Global Pauser contract.

### Purpose and Architecture

The Global Pauser is a universal emergency pause mechanism that can pause multiple pausable contracts across different projects. It replaces project-specific pauser implementations (like the Behodler3 Pauser) with a single, reusable solution.

#### Key Features

1. **Universal Pause Mechanism**: Can pause any contract that implements the `IPausable` interface
2. **EYE Token Burn**: Requires burning EYE tokens (default: 1000 EYE) to trigger a pause, creating an economic barrier against griefing
3. **Contract Registration**: Owner registers pausable contracts that should be paused together
4. **Single Trigger**: One pause action affects all registered contracts simultaneously
5. **Owner-Controlled Unpause**: Only the owner can unpause, ensuring controlled recovery

#### Core Contracts and Interfaces

- **`Pauser.sol`**: Main contract that manages pausable contracts and coordinates pause/unpause actions
- **`IPauser.sol`**: Interface for the Pauser contract, enabling dependency injection in downstream projects
- **`IPausable.sol`**: Interface that pausable contracts must implement to be compatible with the Global Pauser

#### State Variables

- `IERC20 public eyeToken`: The EYE token used for burn mechanism
- `uint256 public eyeBurnAmount`: Amount of EYE required to trigger pause (default: 1000 * 1e18)
- `address[] internal _pausableContracts`: Array of registered pausable contract addresses
- `mapping(address => bool) public isRegistered`: O(1) lookup for registration status
- `mapping(address => uint256) internal _contractIndex`: Enables efficient removal from array (swap-and-pop pattern)

#### Workflow

**Pause Flow:**
1. Anyone with sufficient EYE balance calls `pause()`
2. Pauser transfers EYE tokens from caller to 0xdead (burn)
3. Pauser calls `pause()` on all registered contracts in `_pausableContracts` array
4. `PauseTriggered` event emitted with caller address and burn amount

**Unpause Flow:**
1. Only owner can call `unpause()`
2. Pauser calls `unpause()` on all registered contracts
3. `UnpauseTriggered` event emitted

**Registration Flow:**
1. Owner calls `register(address pausableContract)` to add contract to pause list
2. Contract added to array and mapping updated
3. `ContractRegistered` event emitted

#### Integration Points

**From Behodler3's Perspective:**
- Behodler3 calls `setPauser(newPauserAddress)` to switch to Global Pauser
- Behodler3's `pause()` function checks that caller is the registered pauser
- No changes needed to Behodler3's pause/unpause logic

**From Pausable Contract's Perspective:**
- Must implement `IPausable` interface (provides `pause()` and `unpause()` functions)
- `pause()` should revert if caller is not the registered pauser
- `unpause()` should revert if caller is not the registered pauser
- Register with Global Pauser via owner calling `Pauser.register(contractAddress)`

#### Relationship with Other Projects

- **Behodler3**: Original use case; can migrate from Behodler3-specific Pauser to this Global Pauser
- **Any pausable project**: Can register contracts and benefit from unified pause mechanism
- **EYE Token**: Required dependency for burn mechanism (maintains Behodler ecosystem alignment)

#### Design Decisions

- **Per-contract registration** (not per-project): Allows fine-grained control over which contracts pause together
- **Array iteration for pause/unpause**: Gas costs acceptable since there will never be more than a handful of contracts
- **Simple architecture**: Prioritizes simplicity and low attack surface over gas optimization
- **Swap-and-pop removal**: O(1) unregistration using index mapping

## Dependency Management

### Types of Dependencies

1. **Immutable Dependencies** (lib/immutable/)
   - External libraries and contracts that don't change based on sibling requirements
   - Full source code is available
   - Examples: OpenZeppelin, standard libraries

2. **Mutable Dependencies** (lib/mutable/)
   - Dependencies from sibling submodules
   - ONLY interfaces and abstract contracts are exposed
   - NO implementation details are available
   - Changes to these dependencies must go through the change request process

### Important Rules

- **NEVER** access implementation details of mutable dependencies
- Mutable dependencies only expose interfaces and abstract contracts
- If a feature requires changes to a mutable dependency, add it to the change request queue
- All development must follow Test-Driven Development (TDD) principles using Foundry

### Change Request Process

When a feature requires changes to a mutable dependency:

1. Add the request to `MutableChangeRequests.json` with format:
   ```json
   {
     "requests": [
       {
         "dependency": "dependency-name",
         "changes": [
           {
             "fileName": "ISomeInterface.sol",
             "description": "Plain language description of what needs to change"
           }
         ]
       }
     ]
   }
   ```

2. **STOP WORK** immediately after adding the change request
3. Inform the user that dependency changes are needed
4. Wait for the dependency to be updated before continuing

### Available Commands

Use these as slash commands (e.g., `/add-mutable-dependency`) or run the scripts directly:

- `.claude/scripts/add-mutable-dependency.sh <repo>` - Add a mutable dependency (sibling)
- `.claude/scripts/add-immutable-dependency.sh <repo>` - Add an immutable dependency
- `.claude/scripts/update-mutable-dependency.sh <name>` - Update a mutable dependency
- `.claude/scripts/consider-change-requests.sh` - Review and implement sibling change requests

## Project Structure

- `src/` - Solidity source files
- `test/` - Test files (TDD required)
- `script/` - Deployment scripts
- `lib/mutable/` - Mutable dependencies (interfaces only)
- `lib/immutable/` - Immutable dependencies (full source)

## Development Guidelines

### Test-Driven Development (TDD)

**ALL** features, bug fixes, and modifications MUST follow TDD principles:

1. **Write tests first** - Before implementing any feature
2. **Red phase** - Write failing tests that define the expected behavior
3. **Green phase** - Write minimal code to make tests pass
4. **Refactor phase** - Improve code while keeping tests green

### Testing Commands

- `forge test` - Run all tests
- `forge test -vvv` - Run tests with verbose output
- `forge test --match-contract <ContractName>` - Run specific contract tests
- `forge test --match-test <testName>` - Run specific test
- `forge coverage` - Check test coverage

### Other Commands

- `forge build` - Compile contracts
- `forge fmt` - Format Solidity code
- `forge snapshot` - Generate gas snapshots

## Important Reminders

- This submodule operates independently from sibling submodules
- Follow Solidity best practices and naming conventions
- Use Foundry testing tools exclusively (no Hardhat or Truffle)
- If you need to change a mutable dependency, use the change request process
