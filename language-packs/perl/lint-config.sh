#!/bin/bash
# cognitive-core language pack: Perl lint integration
# Configures perlcritic and perltidy for the project
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Perl lint tools for: $PROJECT_DIR"

# Create .perlcriticrc if not present
if [ ! -f "$PROJECT_DIR/.perlcriticrc" ]; then
    cat > "$PROJECT_DIR/.perlcriticrc" << 'CRITIC'
severity = 4
verbose = %f:%l:%c: %m (%p, Severity: %s)\n

# Recommended policies
[TestingAndDebugging::RequireUseStrict]
severity = 5

[TestingAndDebugging::RequireUseWarnings]
severity = 5

[Modules::RequireEndWithOne]
severity = 4

[Variables::ProhibitUnusedVariables]
severity = 3

# Exclude policies that conflict with Moose/modern Perl
[-Modules::RequireExplicitPackage]
[-Subroutines::RequireFinalReturn]
[-ValuesAndExpressions::ProhibitConstantPragma]
CRITIC
    echo "  Created .perlcriticrc"
else
    echo "  .perlcriticrc already exists, skipping"
fi

# Create .perltidyrc if not present
if [ ! -f "$PROJECT_DIR/.perltidyrc" ]; then
    cat > "$PROJECT_DIR/.perltidyrc" << 'TIDY'
-i=4        # 4-space indentation
-ci=4       # continuation indent
-nst        # no tabs
-bar        # opening brace always right
-nsfs       # no space before semicolons
-nolq       # no outdent long quotes
-l=100      # line length 100
-pt=2       # paren tightness
-sbt=2      # square bracket tightness
-bt=2       # brace tightness
TIDY
    echo "  Created .perltidyrc"
else
    echo "  .perltidyrc already exists, skipping"
fi

echo "Perl lint configuration complete."
