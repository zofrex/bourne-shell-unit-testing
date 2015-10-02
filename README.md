## What is this?

Unit testing Bash (or any Bourne-compatible) shell scripts using shunit2, complete with stubbing and mocking (kinda)!

## Setup

#### Quickstart with OS X and Homebrew

```
brew install shunit2
```

#### Other systems

Download [shunit2](https://code.google.com/p/shunit2/wiki/ProjectInfo) and make sure it's on your path.

### Running the tests

```
make test
```

## How does it work?

### The test system: shunit2

I picked shunit2 and not [Bats](https://github.com/sstephenson/bats) for two reasons:

* Higher confidence level that shunit2 would work on pure Bourne scripts and not just Bash scripts - an absolute requirement for me
* Higher similarity to other test frameworks I've used before e.g. jUnit, in particular having self-documenting assertions available

That said these techniques should work with any shell script testing framework and not just shunit2.

### Basic tests

The first test is very simple:

```
testApiVersion()
{
  actual=`echo | $FREEBSD_PORTS supports-api-version`

  assertEquals "exit code" 0 $?
  assertEquals 1 "$actual"
}
```

I've put the script under test's path in `$FREEBSD_PORTS` to avoid repeating it in every test (if you've noticed that it actually references a wrapper script, ignore that for now - I'll come back to it). All this test does is run that command with the option "supports-api-version" and checks that it returns a status code of 0 and outputs "1".

If at any point in development I accidentally break this contract I quickly find out when I run the test suite:

```
testApiVersion
ASSERT:expected:<1> but was:<>
```

For simple shell scripts, this alone would be sufficient to achieve high confidence the script works, even when peforming major refactoring. But I wanted to do more:

### Stubbing binaries

My script uses the binary `pkg` to list installed packages on the machine and pull out their names and versions. To be able to test I get the right results, I need to control the output of pkg, because the real package list changes all the time.

Stubbing out pkg to replace the real one with my own controlled fake one is really easy, in the test file I just need to add a new directory to my path:

```
export PATH=tests/stubs:$PATH
```

And now any binaries I create in `tests/stubs` will be used instead of the system binaries.

### Stubbing built-ins

The next challenge was controlling the output of `whereis` - a shell built-in, so it can't be overridden by a binary with the same name on the path.

Built-ins _can_ be overridden by functions... but I call my script in a sub-shell in the tests, and in Bourne shell you cannot export functions to sub-shells, only variables (aside: you can in Bash, `export -f functionname` - but I needed Bourne shell support). I tried sourcing the script from the tests instead of exec'ing it but that broke all the things.

#### Introducing: the binary wrapper:

Instead of executing my script from the tests, I execute `wrapper.sh` - as a sub-shell, so the test harness doesn't get broken and command-line arguments are placed into `$1` etc as expected. The wrapper declares the `whereis` function, and then _sources_ (not executes) the script under test - meaning the custom declared whereis is used by my script instead of the real one:

```
function whereis {
  case "$*" in
  "-sq nano")
    echo "/usr/ports/editors/nano"
  ;;
  esac
}

. modules/packages/freebsd_ports
```

### Mocking

To test the script I needed more than just stubbing, for example I need to check that "make" is called in the correct directory, and that in some circumstances it's "make install" and in others "make deinstall reinstall". This called for a mock instead of a stub.

Ideally, mocks would be created via a mock library with a nice DSL, but as no such thing existed for shell scripts mine are all custom coded and very nasty. Don't let their nastiness put you off the idea, though: Bourne scripting is very powerful, easily powerful enough to build a nice interface for dynamically creating mocks.

Here's an example where I ensure `cd` was called with a particular argument before `make` was invoked:

Wrapper:

```
function cd {
  CD_ARGS="$*"
}

function make {
  if [ "$CD_ARGS" != "$ASSERT_CWD" ]
  then
    >&2 echo "ASSERT:make expected to be run in directory:<$ASSERT_CWD> but ran in:<$CD_ARGS>"
    exit 1
  fi
}
```

Test:

```
testInstallAnyVersion()
{
  export ASSERT_CWD=/usr/ports/editors/nano
  echo Name=nano | $FREEBSD_PORTS repo-install
}
```

### Assert a command was run

It's easy to make sure that if a command was called, it was called with the right arguments - throw an error from the mock or stub on invocation if the arguments are incorrect. How to make sure that a command was called at all, though? The only point we can be sure the command wasn't called is after the script finishes, but we have no way of exporting variables from the wrapper back up to the test suite.

#### Solution: trap

I've created assertions to be tested at the end of the script and put them all in a function called `finish_and_assert`. The last thing the wrapper does before sourcing the script under test is:

```
trap finish_and_assert EXIT
```

This ensures that the final assertions are run at the very end of the script and not before. Lastly, which assertions to run are controlled by environment variables set in the tests and passed down to the wrapper:

```
testInstallAnyVersion()
{
  export ASSERT_MAKE_RUNS=install
  echo Name=nano | $FREEBSD_PORTS repo-install
}
```


## Why is this useful?

Unit testing in general is useful because you can change your code faster by being able to test it in isolation. You can quickly verify a small part of your larger system does what it should, and it's often much easier to debug a small module that's giving incorrect results than a larger system performing many operations based on those incorrect results. It can also be a lot faster if you replace operations that take a long time (such as compiling a package) with a "test double" that behaves in a preset way but doesn't perform the actual operation.

That's the theory. In practice, having tests available _did_ speed up my development of this bash script. I was able to edit it and refactor it with confidence, bolstered by the passing test suite that runs in _under a second_ - a full integration test of this module could take _hours_!

## Why is this terrible?

The mocks in particular are extremely fragile. Changes to the script spec or even implementation are likely to require large changes to the test harness. For example, there are several ways to get a list of packages on FreeBSD and `pkg info` is just one of them. Changing to another method could break the tests without actually breaking the script, making the tests a maintenance burden.

Mocking low-level things such as `cd` is also a really bad idea, as there are lots of ways to cd to a target directory and you could end up effectively reimplementing cd in a shell script.

Test state is not cleared up between tests so that has to be done manually:

```
setUp()
{
  unset ASSERT_MAKE_RUNS
  unset ASSERT_CWD
  unset ASSERT_PORTS_UPDATED
}
```

This was one of the largest single causes of errors while I was developing.

## How could it be less terrible?

If the techniques here were generalised and packaged up in a library or test framework of their own, a lot of the boiler plate and repetition could be tidied away. The tests would be a lot more expressive if they set up the mocks they need themselves, rather than all the logic for all the tests being grouped together in a separate mock file. For examples, look at Mockito and Hamcrest for Java, and rspec for Ruby.

For filesystem assertions, mocking is not a sustainable approach for anything beyond trivial complexity. Luckily, POSIX gives us an answer for containing a script to a fake filesystem with `chroot`. If we made a fresh copy of a known-state fake filesystem for each test and chroot'd to it when executing the script, we would have total control over the filesystem environment.

Similarly, POSIX gives us answers for clearing state as well: a system of `fork()`ing processes should be able to guarantee all state has been cleared between test runs.