#!/bin/sh
#
# Copyright (c) 2007 Johannes E Schindelin
# Modified 2009 Elijah Newren
#

test_description='Test eg stash (mainly stash descriptions)'

. ./test-lib.sh

test_expect_success 'stash some dirty working directory' '
	echo 1 > file &&
	git add file &&
	test_tick &&
	git commit -m initial &&
	echo 2 > file &&
	git add file &&
	echo 3 > file &&
	test_tick &&
	git stash save number 1 &&
	git diff-files --quiet &&
	git diff-index --cached --quiet HEAD
'

cat > expect << EOF
diff --git a/file b/file
index 0cfbf08..00750ed 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-2
+3
EOF

test_expect_success 'parents of stash' '
	test $(git rev-parse stash^) = $(git rev-parse HEAD) &&
	git diff stash^2..stash > output &&
	test_cmp output expect
'

test_expect_success 'apply stashed changes' '
	echo 5 > other-file &&
	git add other-file &&
	test_tick &&
	git commit -b -m other-file &&
	git stash apply number 1 &&
	test 3 = $(cat file) &&
	test 1 = $(git show :file) &&
	test 1 = $(git show HEAD:file)
'

test_expect_success 'apply stashed changes (including index)' '
	git reset --hard HEAD^ &&
	echo 6 > other-file &&
	git add other-file &&
	test_tick &&
	git commit -m other-file &&
	git stash apply --index number 1 &&
	test 3 = $(cat file) &&
	test 2 = $(git show :file) &&
	test 1 = $(git show HEAD:file)
'

test_expect_success 'unstashing in a subdirectory' '
	git reset --hard HEAD &&
	mkdir subdir &&
	cd subdir &&
	git stash apply number 1 &&
	cd ..
'

test_expect_success 'drop top stash' '
	git reset --hard &&
	git stash list > stashlist1 &&
	echo 7 > file &&
	git stash save number 2 &&
	git stash drop &&
	git stash list > stashlist2 &&
	diff stashlist1 stashlist2 &&
	git stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(git show :file) &&
	test 1 = $(git show HEAD:file)
'

test_expect_success 'drop middle stash' '
	git reset --hard &&
	echo 8 > file &&
	git stash save number 3 &&
	echo 9 > file &&
	git stash save number 4 &&
	git stash drop number 3 &&
	test 2 = $(git stash list | wc -l) &&
	git stash apply &&
	test 9 = $(cat file) &&
	test 1 = $(git show :file) &&
	test 1 = $(git show HEAD:file) &&
	git reset --hard &&
	git stash drop &&
	git stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(git show :file) &&
	test 1 = $(git show HEAD:file)
'

test_expect_success 'stash pop' '
	git reset --hard &&
	git stash pop number 1 &&
	test 3 = $(cat file) &&
	test 1 = $(git show :file) &&
	test 1 = $(git show HEAD:file) &&
	test 0 = $(git stash list | wc -l)
'

cat > expect << EOF
diff --git a/file2 b/file2
new file mode 100644
index 0000000..1fe912c
--- /dev/null
+++ b/file2
@@ -0,0 +1 @@
+bar2
EOF

cat > expect1 << EOF
diff --git a/file b/file
index 257cc56..5716ca5 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-foo
+bar
EOF

cat > expect2 << EOF
diff --git a/file b/file
index 7601807..5716ca5 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-baz
+bar
diff --git a/file2 b/file2
new file mode 100644
index 0000000..1fe912c
--- /dev/null
+++ b/file2
@@ -0,0 +1 @@
+bar2
EOF

test_expect_success 'stash branch' '
	echo foo > file &&
	git commit file -m first
	echo bar > file &&
	echo bar2 > file2 &&
	git add file2 &&
	git stash save number 5 &&
	echo baz > file &&
	git commit file -m second &&
	git stash branch stashbranch number 5 &&
	test refs/heads/stashbranch = $(git symbolic-ref HEAD) &&
	test $(git rev-parse HEAD) = $(git rev-parse master^) &&
	git diff --cached > output &&
	test_cmp output expect &&
	git diff --unstaged > output &&
	test_cmp output expect1 &&
	git add file &&
	git commit -b -m alternate\ second &&
	git diff master stashbranch > output &&
	test_cmp output expect2 &&
	test 0 = $(git stash list | wc -l)
'

test_expect_success 'apply -q is quiet' '
	echo foo > file &&
	git stash save number 6 &&
	git stash apply -q number 6 > output.out 2>&1 &&
	test ! -s output.out
'

test_expect_success 'save -q is quiet' '
	git stash save --quiet number 7 > output.out 2>&1 &&
	test ! -s output.out
'

test_expect_success 'pop -q is quiet' '
	git stash pop -q number 7 > output.out 2>&1 &&
	test ! -s output.out
'

test_expect_success 'drop -q is quiet' '
	git stash save number 8 &&
	git stash drop -q number 8 > output.out 2>&1 &&
	test ! -s output.out
'

test_expect_success 'stash -k' '
	echo bar3 > file &&
	echo bar4 > file2 &&
	git add file2 &&
	git stash -k &&
	test bar,bar4 = $(cat file),$(cat file2)
'

test_expect_success 'stash --invalid-option' '
	echo bar5 > file &&
	echo bar6 > file2 &&
	git add file2 &&
	test_must_fail git stash --invalid-option &&
	test_must_fail git stash save --invalid-option &&
	test bar5,bar6 = $(cat file),$(cat file2) &&
	git stash -- -message-starting-with-dash &&
	test bar,bar2 = $(cat file),$(cat file2)
'

cat > expect << EOF
same old stash with no branch
same old stash on foobar
-message-starting-with-dash
b3d634c alternate second
number 6
EOF

test_expect_success 'output for stash list' '
	git checkout -b foobar &&
	git stash apply alternate second &&
	git stash save same old stash on foobar &&
	git checkout HEAD~0 &&
	git stash apply alternate second &&
	git stash save same old stash with no branch &&
	git stash list > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
stash@{0}: On (no branch): same old stash with no branch
stash@{1}: On foobar: same old stash on foobar
stash@{2}: On stashbranch: -message-starting-with-dash
stash@{3}: WIP on stashbranch: b3d634c alternate second
stash@{4}: On stashbranch: number 6
EOF

test_expect_success 'output for stash list --details' '
	git stash list --details > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
same old stash with no branch
stash@{0}
same old stash on foobar
stash@{1}
-message-starting-with-dash
stash@{2}
b3d634c alternate second
stash@{3}
number 6
stash@{4}
EOF

test_expect_success 'output for stash list --refs' '
	git stash list --refs > actual 2>&1 &&
	test_cmp expect actual
'

test_done
