# ADR-005: Documentation Generation and Management

## Status
Proposed

## Context

The multi-state learning platform requires comprehensive documentation that:
- Explains each learning state and its objectives
- Provides clear migration guides between states
- Generates automatically from code and metadata
- Stays current with rapid development
- Serves multiple audiences (learners, contributors, maintainers)
- Integrates with existing TraderX documentation

The documentation strategy must scale to dozens of learning states while maintaining quality and consistency.

## Decision

We will implement an **automated documentation generation system** that creates state-specific guides, migration tutorials, and learning paths from structured metadata and code analysis.

### Core Documentation Strategy:

#### 1. Structured Metadata-Driven Documentation
Each state branch contains metadata that drives documentation generation:

```yaml
# .traderx-state.yaml
state:
  name: "OAuth2 Authentication"
  track: "nonfunc"
  category: "auth"
  feature: "oauth2"
  difficulty: "intermediate"
  
documentation:
  learning_objectives:
    - "Understand OAuth2 flow in microservices"
    - "Implement JWT validation"
    - "Secure REST APIs"
  
  prerequisites:
    knowledge: ["basic-auth-concepts", "spring-security"]
    states: ["milestone/v1.0-baseline"]
  
  setup_guide:
    environment_variables:
      - name: "AUTH0_DOMAIN"
        description: "Auth0 domain for your tenant"
        example: "dev-12345.us.auth0.com"
    
  key_changes:
    - component: "account-service"
      files: ["src/main/java/config/SecurityConfig.java"]
      description: "Added JWT validation filter"
      learning_focus: "Spring Security configuration"
```

#### 2. Multi-Layered Documentation Architecture

##### Layer 1: Auto-Generated Core Documentation
- **State Overview**: Generated from metadata
- **Setup Instructions**: Templated from state configuration
- **API Documentation**: Generated from OpenAPI specs
- **Architecture Diagrams**: Auto-updated from code analysis

##### Layer 2: Curated Learning Content
- **Step-by-Step Tutorials**: Manually crafted, template-driven
- **Migration Guides**: Generated from state diffs with manual annotations
- **Concept Explanations**: Curated content for complex topics
- **Best Practices**: Expert-authored guidance

##### Layer 3: Interactive Learning Experience
- **Visual Learning Paths**: Interactive state graph
- **Progress Tracking**: User journey through states
- **Hands-On Exercises**: Integrated with GitHub Codespaces
- **Assessment Questions**: Knowledge validation

## Implementation Details

### 1. Documentation Generation Pipeline

#### Automated Generation Workflow
```yaml
# .github/workflows/docs-generation.yml
name: Documentation Generation

on:
  push:
    branches: ['milestone/*', 'devex/*', 'nonfunc/*', 'func/*']
  schedule:
    - cron: '0 4 * * *'  # Daily at 4 AM

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Need full history for state comparisons
      
      - name: Discover All States
        id: discover
        run: |
          git branch -r | grep -E 'origin/(milestone|devex|nonfunc|func)' | \
          sed 's/origin\///' > states.txt
      
      - name: Generate State Documentation
        run: |
          while read state; do
            git checkout $state
            ./scripts/generate-state-docs.sh $state
          done < states.txt
      
      - name: Generate Learning Paths
        run: ./scripts/generate-learning-paths.sh
      
      - name: Build Documentation Site
        run: |
          npm install --prefix docs-generator
          npm run build --prefix docs-generator
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs-site
```

#### State Documentation Generator
```bash
#!/bin/bash
# scripts/generate-state-docs.sh
# Generates documentation for a specific state

STATE=$1
echo "Generating documentation for state: $STATE"

# 1. Extract metadata
yq eval '.state' .traderx-state.yaml > state-metadata.json

# 2. Generate setup guide
./scripts/generate-setup-guide.py \
  --state $STATE \
  --metadata state-metadata.json \
  --template templates/setup-guide.md.j2 \
  --output docs/states/$STATE/setup.md

# 3. Generate architecture overview
./scripts/analyze-architecture.py \
  --state $STATE \
  --output docs/states/$STATE/architecture.md

# 4. Generate API documentation
./scripts/generate-api-docs.sh $STATE

# 5. Generate migration guides
./scripts/generate-migration-guides.py \
  --from-state $STATE \
  --output docs/states/$STATE/migrations/

echo "Documentation generated for $STATE"
```

### 2. Migration Guide Generation

#### Automated Diff Analysis
```python
#!/usr/bin/env python3
# scripts/generate-migration-guides.py
# Generates migration guides based on git diffs

import git
import yaml
import jinja2
from pathlib import Path

def generate_migration_guide(from_state, to_state):
    """Generate migration guide between two states"""
    
    repo = git.Repo('.')
    
    # Get diff between states
    diff = repo.git.diff(f'{from_state}..{to_state}', name_only=True)
    changed_files = diff.split('\n')
    
    # Categorize changes
    changes = {
        'configuration': [],
        'code': [],
        'documentation': [],
        'dependencies': []
    }
    
    for file in changed_files:
        if file.endswith('.properties') or file.endswith('.yml'):
            changes['configuration'].append(file)
        elif file.endswith('.java') or file.endswith('.js') or file.endswith('.cs'):
            changes['code'].append(file)
        elif file.endswith('.md'):
            changes['documentation'].append(file)
        elif file.endswith('pom.xml') or file.endswith('package.json'):
            changes['dependencies'].append(file)
    
    # Load state metadata
    repo.git.checkout(to_state)
    with open('.traderx-state.yaml') as f:
        target_metadata = yaml.safe_load(f)
    
    # Generate migration guide
    template = jinja2.Template(Path('templates/migration-guide.md.j2').read_text())
    
    guide_content = template.render(
        from_state=from_state,
        to_state=to_state,
        target_metadata=target_metadata,
        changes=changes,
        learning_objectives=target_metadata.get('documentation', {}).get('learning_objectives', [])
    )
    
    # Save migration guide
    output_dir = Path(f'docs/states/{to_state}/migrations')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    guide_path = output_dir / f'from-{from_state.replace("/", "-")}.md'
    guide_path.write_text(guide_content)
    
    return guide_path

if __name__ == '__main__':
    # Generate guides for all state transitions
    # Implementation details...
```

#### Migration Guide Template
```markdown
<!-- templates/migration-guide.md.j2 -->
# Migration Guide: {{ from_state }} → {{ to_state }}

## Overview
This guide walks you through migrating from `{{ from_state }}` to `{{ to_state }}`.

**Estimated Time**: {{ target_metadata.documentation.duration_estimate | default("2-4 hours") }}
**Difficulty**: {{ target_metadata.state.difficulty | title }}

## Learning Objectives
{% for objective in learning_objectives %}
- {{ objective }}
{% endfor %}

## Prerequisites
Ensure you have successfully completed the `{{ from_state }}` state and understand:
{% for prereq in target_metadata.documentation.prerequisites.knowledge %}
- {{ prereq }}
{% endfor %}

## Step-by-Step Migration

### Step 1: Prepare Your Environment
```bash
# Switch to the target state
git checkout {{ to_state }}
git pull origin {{ to_state }}

# Clean previous state
docker-compose down
./gradlew clean
```

### Step 2: Configuration Changes
{% if changes.configuration %}
The following configuration files need to be updated:
{% for file in changes.configuration %}
- `{{ file }}`
{% endfor %}

<!-- Detailed configuration changes would be inserted here -->
{% endif %}

### Step 3: Code Changes
{% if changes.code %}
Key code changes in this migration:
{% for file in changes.code %}
- `{{ file }}`
{% endfor %}

<!-- Detailed code explanations would be inserted here -->
{% endif %}

### Step 4: Dependency Updates
{% if changes.dependencies %}
Update your dependencies:
{% for file in changes.dependencies %}
- `{{ file }}`
{% endfor %}
{% endif %}

### Step 5: Validation
Verify your migration was successful:
```bash
./scripts/validate-state.sh {{ to_state }}
```

## Key Concepts Introduced
<!-- Generated from state metadata and code analysis -->

## Troubleshooting
<!-- Common issues and solutions -->

## Next Steps
<!-- Possible learning paths from this state -->
```

### 3. Interactive Documentation Features

#### Learning Path Visualization
```javascript
// docs-generator/src/components/LearningPathGraph.jsx
import React from 'react';
import { Graph } from 'react-d3-graph';

const LearningPathGraph = ({ states, transitions }) => {
  const nodes = states.map(state => ({
    id: state.name,
    label: state.display_name,
    color: getTrackColor(state.track),
    size: state.milestone ? 1000 : 500
  }));
  
  const links = transitions.map(transition => ({
    source: transition.from,
    target: transition.to,
    label: `${transition.difficulty} (${transition.duration})`
  }));
  
  const graphConfig = {
    directed: true,
    nodeHighlightBehavior: true,
    node: {
      size: 300,
      highlightStrokeColor: "blue"
    },
    link: {
      highlightColor: "lightblue"
    }
  };
  
  return (
    <Graph
      id="learning-path-graph"
      data={{ nodes, links }}
      config={graphConfig}
    />
  );
};
```

#### Progress Tracking
```javascript
// docs-generator/src/components/ProgressTracker.jsx
import React, { useState, useEffect } from 'react';

const ProgressTracker = ({ userId, learningPath }) => {
  const [progress, setProgress] = useState({});
  
  useEffect(() => {
    // Load progress from localStorage or API
    const savedProgress = localStorage.getItem(`progress-${userId}-${learningPath}`);
    if (savedProgress) {
      setProgress(JSON.parse(savedProgress));
    }
  }, [userId, learningPath]);
  
  const markStateComplete = (stateId) => {
    const newProgress = {
      ...progress,
      [stateId]: {
        completed: true,
        completedAt: new Date().toISOString()
      }
    };
    setProgress(newProgress);
    localStorage.setItem(`progress-${userId}-${learningPath}`, JSON.stringify(newProgress));
  };
  
  return (
    <div className="progress-tracker">
      {/* Progress visualization */}
    </div>
  );
};
```

### 4. Documentation Website Architecture

#### Site Structure
```
docs-site/
├── index.html                    # Landing page
├── getting-started/
│   ├── index.md                 # Quick start guide
│   └── concepts.md              # Core concepts
├── learning-paths/
│   ├── index.md                 # All learning paths
│   ├── devex/                   # DevEx track paths
│   ├── nonfunc/                 # Non-functional track paths
│   └── func/                    # Functional track paths
├── states/
│   ├── milestone-v1-baseline/   # Individual state docs
│   ├── devex-containerization/
│   └── ...
├── guides/
│   ├── contributing.md          # How to contribute
│   ├── maintenance.md           # Maintenance procedures
│   └── troubleshooting.md       # Common issues
└── api/
    ├── reference/               # API documentation
    └── examples/                # Usage examples
```

#### Documentation Site Generator
```python
#!/usr/bin/env python3
# scripts/build-docs-site.py
# Builds the complete documentation website

import yaml
import jinja2
import shutil
from pathlib import Path

class DocsBuilder:
    def __init__(self):
        self.states = self.discover_states()
        self.learning_paths = self.build_learning_paths()
        
    def discover_states(self):
        """Discover all states and their metadata"""
        states = {}
        for state_dir in Path('docs/states').iterdir():
            if state_dir.is_dir():
                metadata_file = state_dir / 'metadata.yaml'
                if metadata_file.exists():
                    with open(metadata_file) as f:
                        states[state_dir.name] = yaml.safe_load(f)
        return states
    
    def build_learning_paths(self):
        """Build learning path graph from state relationships"""
        # Implementation to build directed graph of learning paths
        pass
    
    def generate_site(self):
        """Generate the complete documentation site"""
        self.generate_index()
        self.generate_state_pages()
        self.generate_learning_path_pages()
        self.generate_api_docs()
        self.copy_static_assets()
    
    def generate_index(self):
        """Generate main landing page"""
        template = self.env.get_template('index.html.j2')
        content = template.render(
            states=self.states,
            learning_paths=self.learning_paths,
            stats=self.calculate_stats()
        )
        Path('docs-site/index.html').write_text(content)
```

### 5. Content Quality and Consistency

#### Documentation Standards
```yaml
# .github/docs-standards.yml
documentation_standards:
  structure:
    required_sections:
      - "Overview"
      - "Learning Objectives"
      - "Prerequisites"
      - "Setup Instructions"
      - "Key Concepts"
      - "Validation"
      - "Next Steps"
  
  style:
    tone: "Educational, encouraging, practical"
    code_examples: "Complete and runnable"
    screenshots: "Current and high-quality"
  
  validation:
    spell_check: true
    link_check: true
    code_validation: true
    accessibility_check: true
```

#### Content Review Process
```bash
#!/bin/bash
# scripts/validate-documentation.sh
# Validates documentation quality and consistency

echo "Validating documentation quality..."

# 1. Spell check
echo "Running spell check..."
cspell "docs/**/*.md"

# 2. Link validation
echo "Checking links..."
markdown-link-check docs/**/*.md

# 3. Code block validation
echo "Validating code blocks..."
./scripts/validate-code-blocks.py docs/

# 4. Accessibility check
echo "Checking accessibility..."
pa11y-ci --sitemap http://localhost:3000/sitemap.xml

# 5. Style consistency
echo "Checking style consistency..."
alex docs/**/*.md

echo "Documentation validation complete!"
```

## Integration with Learning Platform

### GitHub Integration
- **Codespaces**: Pre-configured development environments for each state
- **Repository Templates**: Quick setup for learners
- **GitHub Actions**: Automated validation of learner progress

### External Platform Integration
```yaml
# Integration capabilities for external learning platforms
integrations:
  lms:
    scorm_package: true
    progress_api: true
    assessment_integration: true
  
  corporate_training:
    white_label: true
    analytics: true
    certification: true
  
  developer_platforms:
    katacoda: true
    gitpod: true
    codespaces: true
```

## Success Metrics

### Documentation Quality:
- **Completeness**: All states have required documentation sections
- **Accuracy**: Documentation matches actual code and functionality
- **Freshness**: Documentation updated within 24 hours of code changes
- **Accessibility**: Meets WCAG 2.1 AA standards

### Learning Effectiveness:
- **Comprehension**: Assessment scores after completing documentation
- **Task Success**: Percentage of learners successfully completing state setup
- **Time to Competency**: How quickly learners achieve state objectives
- **Retention**: Knowledge retention after completing learning paths

### Community Engagement:
- **Contribution Rate**: Community contributions to documentation
- **Issue Resolution**: Time to resolve documentation issues
- **Usage Analytics**: Most popular content and learning paths
- **Feedback Quality**: Community ratings and suggestions

This documentation strategy ensures comprehensive, current, and educational content while scaling efficiently across multiple learning states.
