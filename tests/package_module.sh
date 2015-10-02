#! /bin/sh -e

export PATH=tests/stubs:$PATH
export COMMAND=modules/packages/freebsd_ports
FREEBSD_PORTS=tests/wrapper.sh

setUp()
{
  unset ASSERT_MAKE_RUNS
  unset ASSERT_CWD
  unset ASSERT_PORTS_UPDATED
}

testApiVersion()
{
  actual=`echo | $FREEBSD_PORTS supports-api-version`

  assertEquals "exit code" 0 $?
  assertEquals 1 "$actual"
}

testInvalidComand()
{
  actual=`echo | $FREEBSD_PORTS oogly-boogly-moogly`

  assertEquals "exit code" 0 $?
  assertEquals "ErrorMessage=Invalid operation" "$actual"
}

testGetData()
{
  input="File=zip
Version=3.0-4
Architecture=amd64"
  expected="PackageType=repo
Name=zip"

  actual=`echo "$input" | $FREEBSD_PORTS get-package-data`

  assertEquals "exit code" 0 $?
  assertEquals "$expected" "$actual"
}

testListPackages()
{
  expected="Name=autoconf
Version=2.69
Architecture=freebsd:10:x86:64
Name=autoconf-wrapper
Version=20131203
Architecture=freebsd:10:x86:64
Name=cfengine
Version=3.7.0_1
Architecture=freebsd:10:x86:64
Name=gettext-tools
Version=0.19.5.1
Architecture=freebsd:10:x86:64
Name=sudo
Version=1.8.14p3
Architecture=freebsd:10:x86:64"

  actual=`echo | $FREEBSD_PORTS list-installed`

  assertEquals "exit code" 0 $?
  assertEquals "$expected" "$actual"
}

testInstallPackage()
{
  input="Name=nano
Version=2.4.2
Architecture=amd64"
  export ASSERT_MAKE_RUNS=install
  export ASSERT_CWD=/usr/ports/editors/nano

  actual=`echo "$input" | $FREEBSD_PORTS repo-install`

  assertEquals "exit code" 0 $?
  assertEquals "" "$actual"
}

testListUpdates()
{
  expected="Name=ca_root_nss
Version=3.20
Architecture=freebsd:10:x86:64
Name=portmaster
Version=3.17.8
Architecture=freebsd:10:x86:64"
  export ASSERT_PORTS_UPDATED=1

  actual=`echo | $FREEBSD_PORTS list-updates`

  assertEquals "exit code" 0 $?
  assertEquals "$expected" "$actual"
}


testListUpdatesLocal()
{
  expected="Name=ca_root_nss
Version=3.20
Architecture=freebsd:10:x86:64
Name=portmaster
Version=3.17.8
Architecture=freebsd:10:x86:64"

  actual=`echo | $FREEBSD_PORTS list-updates-local`

  assertEquals "exit code" 0 $?
  assertEquals "$expected" "$actual"
}

testUpdatePackage()
{
  input="Name=ca_root_nss
Version=3.20"
  export ASSERT_MAKE_RUNS="deinstall reinstall"
  export ASSERT_CWD=/usr/ports/security/ca_root_nss

  actual=`echo "$input" | $FREEBSD_PORTS repo-install`

  assertEquals "exit code" 0 $?
  assertEquals "" "$actual"
}

testInstallWrongVersion()
{
  input="Name=nano
Version=2.4.3
Architecture=amd64"
  export ASSERT_CWD=/usr/ports/editors/nano

  actual=`echo "$input" | $FREEBSD_PORTS repo-install`

  assertEquals "exit code" 0 $?
  assertEquals "ErrorMessage=Could not install nano 2.4.3, available version was 2.4.2" "$actual"
}

testInstallAnyVersion()
{
  input="Name=nano
Architecture=amd64"
  export ASSERT_MAKE_RUNS=install
  export ASSERT_CWD=/usr/ports/editors/nano

  actual=`echo "$input" | $FREEBSD_PORTS repo-install`

  assertEquals "exit code" 0 $?
  assertEquals "" "$actual"
}

testRemove()
{
  input="Name=nano"
  export ASSERT_MAKE_RUNS=deinstall
  export ASSERT_CWD=/usr/ports/editors/nano

  actual=`echo "$input" | $FREEBSD_PORTS remove`

  assertEquals "exit code" 0 $?
  assertEquals "" "$actual"
}
