# Error Patterns Reference

Default error patterns used by the workspace-monitor skill. Patterns are loaded
based on `CC_LANGUAGE` from `cognitive-core.conf`. Language packs can override
these with `language-packs/<language>/monitor-patterns.conf`.

## Universal Patterns (All Languages)

These patterns apply regardless of `CC_LANGUAGE`:

```
# Severity: CRITICAL
OutOfMemoryError|StackOverflowError|SIGKILL|SIGSEGV|core dumped
Segmentation fault|Bus error|Killed

# Severity: ERROR
ERROR|FATAL|SEVERE|CRITICAL
Connection refused|Connection timed out|Connection reset
Permission denied|Access denied|Unauthorized
Disk full|No space left on device

# Severity: WARNING
WARN|WARNING|DEPRECAT
timeout|Timeout|TIMEOUT
retry|Retry|retrying
```

## Perl

```
# Runtime errors
die\b|croak\b|confess\b
DBI.*failed|execute.*failed|prepare.*failed
Can't locate .* in @INC
Undefined subroutine
Use of uninitialized value
Deep recursion on subroutine
Global symbol .* requires explicit package name

# Test patterns (TAP format)
not ok
Failed test
Looks like you failed
Looks like you planned .* but ran
Dubious, test returned
```

## Python

```
# Runtime errors
Traceback \(most recent call last\)
\w+Error:|\w+Exception:
ImportError|ModuleNotFoundError
KeyError|IndexError|AttributeError|TypeError|ValueError
FileNotFoundError|PermissionError|OSError
RuntimeError|RecursionError
asyncio.*exception|Task was destroyed

# Test patterns (pytest)
FAILED|ERROR.*test
ERRORS|FAILURES
=+ FAILURES =+
=+ ERRORS =+
short test summary
```

## Java

```
# Runtime errors
Exception|Caused by:
at [a-z].*\(.*\.java:[0-9]+\)
NullPointerException|ClassNotFoundException|ClassCastException
NoSuchMethodException|IllegalArgumentException|IllegalStateException
IOException|FileNotFoundException|SocketException
OutOfMemoryError|StackOverflowError
java\.lang\.Error

# Build patterns (Maven/Gradle)
BUILD FAILURE|BUILD SUCCESS
COMPILATION ERROR
Tests run:.*Failures:.*Errors:
\[ERROR\].*Failed to execute
\[WARNING\].*deprecated
Could not resolve dependencies

# Spring Boot specific
ApplicationContextException|BeanCreationException
Failed to start .* context
Whitelabel Error Page
```

## Node.js / TypeScript

```
# Runtime errors
TypeError|ReferenceError|SyntaxError|RangeError
Error:|error TS[0-9]+
Cannot find module|MODULE_NOT_FOUND
ENOENT|EACCES|ECONNREFUSED|EADDRINUSE
UnhandledPromiseRejection|unhandled rejection
Maximum call stack size exceeded

# Build patterns
error TS[0-9]+:.*
Module not found|Cannot resolve
Failed to compile
Build error occurred
BREAKING CHANGE
chunk .* exceeded
```

## Go

```
# Runtime errors
panic:|runtime error:
fatal error:|goroutine .* \[running\]
index out of range|nil pointer dereference
deadlock|all goroutines are asleep

# Build patterns
cannot find package|undefined:
build failed|compilation failed
```

## Rust

```
# Compile/runtime errors
error\[E[0-9]+\]:
panicked at|thread .* panicked
cannot find|not found in this scope
mismatched types|expected .* found
borrow checker|cannot borrow

# Build patterns (Cargo)
error: could not compile
warning:.*unused
Compiling .* failed
```

## C# / .NET

```
# Runtime errors
System\.\w+Exception
Unhandled exception
NullReferenceException|ArgumentException|InvalidOperationException
StackOverflowException|OutOfMemoryException

# Build patterns (dotnet/MSBuild)
Build FAILED|error CS[0-9]+
error MSB[0-9]+|warning CS[0-9]+
```

## Shell / Bash

```
# Script errors
\[ERROR\]|\[DENY\]|\[WARN\]
command not found
Permission denied
No such file or directory
syntax error|unexpected token
FAIL|FAILED|failed

# cognitive-core specific
integrity-mismatch|guard-failure
security-violation
```
