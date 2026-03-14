#!/bin/bash
# cognitive-core language pack: Struts + JSP lint integration
# Creates Checkstyle and PMD configs appropriate for legacy Java web projects
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Struts/JSP lint tools for: $PROJECT_DIR"

# ---- Checkstyle for legacy Java ----
if [ ! -f "$PROJECT_DIR/config/checkstyle/checkstyle.xml" ]; then
    mkdir -p "$PROJECT_DIR/config/checkstyle"
    cat > "$PROJECT_DIR/config/checkstyle/checkstyle.xml" << 'HEREDOC'
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">
<!-- cognitive-core: Checkstyle for legacy Struts/JSP projects -->
<!-- Relaxed rules appropriate for legacy code — focus on safety, not style -->
<module name="Checker">
    <property name="charset" value="UTF-8"/>
    <property name="severity" value="warning"/>

    <module name="TreeWalker">
        <!-- Security: catch dangerous patterns -->
        <module name="IllegalTokenText">
            <property name="tokens" value="STRING_LITERAL"/>
            <property name="format" value="(?i)(password|secret|apikey)\s*=\s*&quot;[^&quot;]+&quot;"/>
            <property name="message" value="Possible hardcoded credential"/>
        </module>

        <!-- Basic naming (relaxed for legacy) -->
        <module name="TypeName"/>
        <module name="MethodName"/>
        <module name="ConstantName"/>

        <!-- Import hygiene -->
        <module name="UnusedImports"/>
        <module name="RedundantImport"/>
        <module name="AvoidStarImport">
            <property name="allowStaticMemberImports" value="true"/>
        </module>

        <!-- Error-prone patterns -->
        <module name="EmptyCatchBlock">
            <property name="exceptionVariableName" value="^(ignored|expected)$"/>
        </module>
        <module name="MissingSwitchDefault"/>
        <module name="FallThrough"/>
        <module name="EqualsHashCode"/>
        <module name="StringLiteralEquality"/>

        <!-- Size limits (generous for legacy code) -->
        <module name="MethodLength">
            <property name="max" value="200"/>
        </module>
        <module name="ParameterNumber">
            <property name="max" value="10"/>
        </module>
    </module>

    <!-- File-level checks -->
    <module name="FileLength">
        <property name="max" value="3000"/>
    </module>
    <module name="FileTabCharacter"/>
</module>
HEREDOC
    echo "  Created config/checkstyle/checkstyle.xml (legacy-appropriate rules)"
else
    echo "  Checkstyle config already exists, skipping"
fi

# ---- PMD for legacy Java ----
if [ ! -f "$PROJECT_DIR/config/pmd/ruleset.xml" ]; then
    mkdir -p "$PROJECT_DIR/config/pmd"
    cat > "$PROJECT_DIR/config/pmd/ruleset.xml" << 'HEREDOC'
<?xml version="1.0"?>
<!-- cognitive-core: PMD ruleset for legacy Struts/JSP projects -->
<ruleset name="cognitive-core-legacy"
    xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0
        https://pmd.sourceforge.io/ruleset_2_0_0.xsd">

    <description>Security-focused rules for legacy Java web applications</description>

    <!-- Security -->
    <rule ref="category/java/security.xml"/>

    <!-- Error-prone -->
    <rule ref="category/java/errorprone.xml/EmptyCatchBlock"/>
    <rule ref="category/java/errorprone.xml/AvoidCatchingNPE"/>
    <rule ref="category/java/errorprone.xml/CloseResource"/>
    <rule ref="category/java/errorprone.xml/NullAssignment"/>

    <!-- Best practices -->
    <rule ref="category/java/bestpractices.xml/UnusedPrivateField"/>
    <rule ref="category/java/bestpractices.xml/UnusedLocalVariable"/>
    <rule ref="category/java/bestpractices.xml/SystemPrintln"/>

    <!-- Performance -->
    <rule ref="category/java/performance.xml/StringInstantiation"/>
    <rule ref="category/java/performance.xml/UseStringBufferForStringAppends"/>
</ruleset>
HEREDOC
    echo "  Created config/pmd/ruleset.xml (security-focused)"
else
    echo "  PMD config already exists, skipping"
fi

echo "Struts/JSP lint configuration complete."
