# Claude Code Agent Workflow Guide

This document outlines best practices for using Claude Code agents when working on this Rails application.

## Overview

For all **major pieces of work** (features, significant refactors, bug fixes affecting multiple components), follow a structured workflow using specialized agents to ensure code quality, test coverage, and consistency.

## Workflow

### Step 1: Plan the Work
- Clarify requirements and design
- Break down into discrete tasks
- Use `TodoWrite` to track progress

### Step 2: Implement the Feature
- Write the code according to the design
- Create models, controllers, views, services as needed
- Update routes and configurations

### Step 3: Create Tests & Fix Issues (Agent Task)
**THIS STEP IS CRITICAL - DO NOT SKIP**

Once the core implementation is complete, **immediately** invoke the general-purpose agent to:

```
Task (general-purpose agent):
- Analyze the codebase testing structure
- Create comprehensive test fixtures
- Create model tests (validations, associations, methods)
- Create controller tests (CRUD, authorization, edge cases)
- Create integration tests (workflows)
- Update existing tests for related components
- Run full test suite
- Fix any failing tests
- Report issues found and fixed
```

### Step 4: Code Review & Polish
- Address any issues found by the agent
- Verify all tests pass
- Check for console errors or warnings
- Update documentation

### Step 5: Verify Integration
- Test manually on localhost
- Ensure no regressions
- Verify admin interfaces work correctly

## When to Run the Agent

### Always run the agent after:
- ✅ Adding new models with business logic
- ✅ Adding new controllers with CRUD operations
- ✅ Creating new services or jobs
- ✅ Major refactoring of existing features
- ✅ Implementing admin interfaces
- ✅ Adding authentication/authorization changes
- ✅ Database schema changes
- ✅ Creating new integration workflows

### May skip agent for:
- ❌ Minor view tweaks (CSS, layout)
- ❌ Updating existing tests only
- ❌ Small bug fixes with existing test coverage
- ❌ Documentation updates

## Example Agent Prompt Template

```
Analyze this Rails application and create comprehensive tests for [FEATURE].

## New Code Added:
1. [List models, controllers, views created]
2. [List routes added]
3. [List database changes]

## Testing Tasks:

### 1. Create Fixtures (test/fixtures/)
- [List fixtures to create]

### 2. Create Model Tests (test/models/)
- [List model tests to create]

### 3. Create Controller Tests (test/controllers/)
- [List controller tests to create]

### 4. Create Integration Tests (test/integration/)
- [List integration tests to create]

### 5. Update Existing Tests
- [List related tests to update]

## Requirements:
1. Follow existing Minitest conventions
2. Use fixtures for test data
3. Test both success and failure paths
4. Include security/authorization tests
5. Test edge cases
6. Run bin/rails test to verify all pass
7. Fix any issues found

Start now and be thorough. Report final test results.
```

## Testing Framework

This project uses:
- **Test Framework**: Minitest (Rails default)
- **Test Data**: YAML fixtures with ERB
- **Mocking**: Mocha for mocks/stubs
- **HTTP Mocking**: WebMock + VCR
- **Browser Testing**: Capybara + Selenium (headless Chrome)
- **Coverage**: SimpleCov

### Test Structure
```
test/
├── models/          # Unit tests for models
├── controllers/     # Integration tests for controllers
├── admin/           # Admin controller tests
├── api/             # API endpoint tests
├── integration/     # End-to-end workflows
├── services/        # Service class tests
├── jobs/            # ActiveJob tests
├── mailers/         # ActionMailer tests
├── system/          # Browser-based system tests
└── fixtures/        # YAML test data
```

### Running Tests
```bash
# All tests
bin/rails test

# Specific file
bin/rails test test/models/user_test.rb

# Specific test
bin/rails test test/models/user_test.rb:27

# Pattern matching
bin/rails test -n /authentication/

# With coverage
COVERAGE=true bin/rails test
```

## Test Checklist

After agent creates tests, verify:
- [ ] All tests pass: `bin/rails test`
- [ ] Model tests cover: validations, associations, scopes, methods
- [ ] Controller tests cover: CRUD, authorization, edge cases, errors
- [ ] Integration tests cover: full workflows, edge cases
- [ ] Security tests cover: authorization, parameter validation
- [ ] Fixtures are properly formatted and loaded
- [ ] No "skipped" tests
- [ ] Code coverage hasn't decreased significantly

## Common Issues & Solutions

### Issue: Tests reference non-existent fixtures
**Solution**: Run agent task to verify all fixtures exist and are properly named

### Issue: Admin authorization tests fail
**Solution**: Ensure test user is marked as admin in fixture

### Issue: Integration tests timeout on slow operations
**Solution**: Use VCR cassettes or stub external requests

### Issue: Conflicting test data
**Solution**: Use unique identifiers in fixtures, check for duplicate keys

### Issue: Database state leaks between tests
**Solution**: Ensure fixtures use independent data, check for missing teardowns

## Recent Major Work Examples

### Example 1: Onboarding System (Completed)
- Models: SuggestedFeed, User (onboarding methods), Setting
- Controllers: Admin::SuggestedFeedsController, Admin::SettingsController
- Dashboard enhancements
- **Agent Task Run**: ✅ Created 153+ tests, all passing
- **Results**: Comprehensive coverage of models, controllers, integration flows

## Agent Task Results Log

### Onboarding Feature (2025-10-18)
- **Agent Type**: general-purpose
- **Tests Created**: 153+
- **Test Files**: 7 new files + 3 updated
- **Fixtures Created**: 2 new YAML files
- **Coverage**: Models, Controllers (admin), Integration, Security
- **Result**: ✅ All passing
- **Issues Fixed**: 3 (syntax errors, fixture conflicts, helper incompatibilities)

---

**Last Updated**: 2025-10-18
**Rails Version**: 8.0.3
**Test Framework**: Minitest
**Agent Introduced**: 2025-10-18
