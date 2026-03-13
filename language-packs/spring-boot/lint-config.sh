#!/bin/bash
# cognitive-core language pack: Spring Boot lint integration
# Configures Checkstyle, SpotBugs, and PMD for Spring Boot projects
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Spring Boot lint tools for: $PROJECT_DIR"

# --- Checkstyle configuration ---
CHECKSTYLE_DIR="$PROJECT_DIR/config/checkstyle"
if [ ! -f "$CHECKSTYLE_DIR/checkstyle.xml" ]; then
    mkdir -p "$CHECKSTYLE_DIR"
    cat > "$CHECKSTYLE_DIR/checkstyle.xml" << 'CHECKSTYLE'
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">

<module name="Checker">
    <property name="severity" value="warning"/>
    <property name="fileExtensions" value="java"/>

    <!-- File-level checks -->
    <module name="FileLength">
        <property name="max" value="500"/>
    </module>
    <module name="FileTabCharacter"/>
    <module name="NewlineAtEndOfFile"/>

    <module name="TreeWalker">
        <!-- Naming conventions -->
        <module name="TypeName"/>
        <module name="MethodName"/>
        <module name="ParameterName"/>
        <module name="LocalVariableName"/>
        <module name="MemberName"/>
        <module name="ConstantName"/>
        <module name="PackageName"/>

        <!-- Import checks -->
        <module name="AvoidStarImport"/>
        <module name="RedundantImport"/>
        <module name="UnusedImports"/>
        <module name="IllegalImport">
            <property name="illegalPkgs" value="sun"/>
        </module>

        <!-- Size violations -->
        <module name="MethodLength">
            <property name="max" value="60"/>
        </module>
        <module name="ParameterNumber">
            <property name="max" value="7"/>
        </module>

        <!-- Coding -->
        <module name="EmptyStatement"/>
        <module name="EqualsHashCode"/>
        <module name="MissingSwitchDefault"/>
        <module name="SimplifyBooleanExpression"/>
        <module name="SimplifyBooleanReturn"/>
        <module name="StringLiteralEquality"/>
        <module name="IllegalCatch">
            <property name="illegalClassNames" value="java.lang.Throwable, java.lang.RuntimeException"/>
        </module>

        <!-- Design -->
        <module name="FinalClass"/>
        <module name="HideUtilityClassConstructor"/>
        <module name="InterfaceIsType"/>

        <!-- Whitespace -->
        <module name="WhitespaceAround"/>
        <module name="WhitespaceAfter"/>
        <module name="NoWhitespaceBefore"/>
        <module name="GenericWhitespace"/>

        <!-- Javadoc (relaxed for Spring Boot services) -->
        <module name="MissingJavadocType">
            <property name="scope" value="public"/>
            <property name="excludeScope" value="nothing"/>
            <property name="tokens" value="INTERFACE_DEF"/>
        </module>
    </module>
</module>
CHECKSTYLE
    echo "  Created config/checkstyle/checkstyle.xml"
else
    echo "  Checkstyle config already exists, skipping"
fi

# --- Checkstyle suppression file ---
if [ ! -f "$CHECKSTYLE_DIR/suppressions.xml" ]; then
    cat > "$CHECKSTYLE_DIR/suppressions.xml" << 'SUPPRESS'
<?xml version="1.0"?>
<!DOCTYPE suppressions PUBLIC
    "-//Checkstyle//DTD SuppressionFilter Configuration 1.2//EN"
    "https://checkstyle.org/dtds/suppressions_1_2.dtd">

<suppressions>
    <!-- Generated code -->
    <suppress checks=".*" files=".*Generated.*\.java"/>

    <!-- Test classes have relaxed rules -->
    <suppress checks="MagicNumber" files=".*Test\.java"/>
    <suppress checks="MethodLength" files=".*Test\.java"/>
    <suppress checks="FileLength" files=".*Test\.java"/>
    <suppress checks="MissingJavadocType" files=".*Test\.java"/>

    <!-- Configuration classes -->
    <suppress checks="HideUtilityClassConstructor" files=".*Application\.java"/>

    <!-- DTOs and records -->
    <suppress checks="MissingJavadocType" files=".*Dto\.java"/>
    <suppress checks="MissingJavadocType" files=".*Record\.java"/>
</suppressions>
SUPPRESS
    echo "  Created config/checkstyle/suppressions.xml"
else
    echo "  Checkstyle suppressions already exist, skipping"
fi

# --- SpotBugs exclude filter ---
SPOTBUGS_DIR="$PROJECT_DIR/config/spotbugs"
if [ ! -f "$SPOTBUGS_DIR/exclude.xml" ]; then
    mkdir -p "$SPOTBUGS_DIR"
    cat > "$SPOTBUGS_DIR/exclude.xml" << 'SPOTBUGS'
<?xml version="1.0" encoding="UTF-8"?>
<FindBugsFilter>
    <!-- Exclude Spring-managed beans from serialization warnings -->
    <Match>
        <Or>
            <Class name="~.*Controller"/>
            <Class name="~.*Service"/>
            <Class name="~.*Repository"/>
            <Class name="~.*Configuration"/>
        </Or>
        <Bug pattern="SE_BAD_FIELD"/>
    </Match>

    <!-- Exclude generated code -->
    <Match>
        <Or>
            <Class name="~.*Generated.*"/>
            <Class name="~.*MapperImpl"/>
            <Class name="~.*Q[A-Z].*"/>
        </Or>
    </Match>

    <!-- Exclude Spring Boot application class -->
    <Match>
        <Class name="~.*Application"/>
        <Bug pattern="HE_EQUALS_USE_HASHCODE"/>
    </Match>

    <!-- Exclude DTOs from mutable state warnings -->
    <Match>
        <Or>
            <Class name="~.*Dto"/>
            <Class name="~.*Request"/>
            <Class name="~.*Response"/>
        </Or>
        <Bug pattern="EI_EXPOSE_REP,EI_EXPOSE_REP2"/>
    </Match>
</FindBugsFilter>
SPOTBUGS
    echo "  Created config/spotbugs/exclude.xml"
else
    echo "  SpotBugs config already exists, skipping"
fi

# --- PMD ruleset ---
PMD_DIR="$PROJECT_DIR/config/pmd"
if [ ! -f "$PMD_DIR/ruleset.xml" ]; then
    mkdir -p "$PMD_DIR"
    cat > "$PMD_DIR/ruleset.xml" << 'PMD'
<?xml version="1.0"?>
<ruleset name="Spring Boot Ruleset"
         xmlns="http://pmd.sourceforge.net/ruleset/2.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://pmd.sourceforge.net/ruleset/2.0.0
                             https://pmd.sourceforge.io/ruleset_2_0_0.xsd">

    <description>PMD rules for Spring Boot projects</description>

    <!-- Best practices -->
    <rule ref="category/java/bestpractices.xml">
        <exclude name="JUnitTestsShouldIncludeAssert"/>
        <exclude name="GuardLogStatement"/>
    </rule>

    <!-- Code style -->
    <rule ref="category/java/codestyle.xml">
        <exclude name="AtLeastOneConstructor"/>
        <exclude name="OnlyOneReturn"/>
        <exclude name="CommentDefaultAccessModifier"/>
        <exclude name="DefaultPackage"/>
        <exclude name="TooManyStaticImports"/>
        <exclude name="LongVariable"/>
        <exclude name="ShortVariable">
            <properties>
                <property name="minimum" value="2"/>
            </properties>
        </exclude>
    </rule>

    <!-- Design -->
    <rule ref="category/java/design.xml">
        <exclude name="LawOfDemeter"/>
        <exclude name="LoosePackageCoupling"/>
        <exclude name="DataClass"/>
        <exclude name="TooManyMethods">
            <properties>
                <property name="maxmethods" value="20"/>
            </properties>
        </exclude>
    </rule>

    <!-- Error prone -->
    <rule ref="category/java/errorprone.xml">
        <exclude name="BeanMembersShouldSerialize"/>
        <exclude name="DataflowAnomalyAnalysis"/>
    </rule>

    <!-- Performance -->
    <rule ref="category/java/performance.xml"/>

    <!-- Security -->
    <rule ref="category/java/security.xml"/>
</ruleset>
PMD
    echo "  Created config/pmd/ruleset.xml"
else
    echo "  PMD config already exists, skipping"
fi

echo "Spring Boot lint configuration complete."
