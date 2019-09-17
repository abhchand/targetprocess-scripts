# TargetProcess Scripts

A series of helpful scripts to automate common TargetProcess tasks.

Available Tasks:

| Task | Description |
| ------------- | ------------- |
| [Create Feature Entities](#task-create-feature-entities) | Create one or more entities under a feature |

- [Quick Start](#quick-start)
- [Tasks](#tasks)
    - [Set Project](#task-create-feature-entities)

## <a name="quick-start"></a> Quick Start

```
# Install dependencies
bundle install

# Create and fill out an `.env` file based on the provided sample
cp .env.sample .env
vi .env
```

Then run one of the tasks below.

## <a name="tasks"></a> Tasks

### <a name="task-create-feature-entities"></a> Create Feature Entities

Bulk creates one or more entities under a given Feature

```
# List options
bin/create-feature-entities-task --help

# Create a sample YML file
cp input.sample.yml input.yml

# Run
bin/create-feature-entities-task -f input.yml
```

