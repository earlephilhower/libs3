#!/bin/sh

# Environment:
# S3_ACCESS_KEY_ID - must be set to S3 Access Key ID
# S3_SECRET_ACCESS_KEY - must be set to S3 Secret Access Key
# TEST_BUCKET_PREFIX - must be set to the test bucket prefix to use
# S3_COMMAND - may be set to s3 command to use, examples:
#              "valgrind s3"
#              "s3 -h" (for aws s3)
#              default: "s3"

if [ -z "$S3_ACCESS_KEY_ID" ]; then
    echo "S3_ACCESS_KEY_ID required"
    exit -1;
fi

if [ -z "$S3_SECRET_ACCESS_KEY" ]; then
    echo "S3_SECRET_ACCESS_KEY required"
    exit -1;
fi

if [ -z "$TEST_BUCKET_PREFIX" ]; then
    echo "TEST_BUCKET_PREFIX required"
    exit -1;
fi

if [ -z "$S3_COMMAND" ]; then
    S3_COMMAND=s3
fi

TEST_BUCKET=${TEST_BUCKET_PREFIX}.testbucket

# Create the test bucket
echo "$S3_COMMAND create $TEST_BUCKET"
$S3_COMMAND create $TEST_BUCKET

# List to find it
echo "$S3_COMMAND list | grep $TEST_BUCKET"
$S3_COMMAND list | grep $TEST_BUCKET

# Test it
echo "$S3_COMMAND test $TEST_BUCKET"
$S3_COMMAND test $TEST_BUCKET

# List to ensure that it is empty
echo "$S3_COMMAND list $TEST_BUCKET"
$S3_COMMAND list $TEST_BUCKET

# Put some data
rm -f seqdata
seq 1 10000 > seqdata
echo "$S3_COMMAND put $TEST_BUCKET/testkey filename=seqdata noStatus=1"
$S3_COMMAND put $TEST_BUCKET/testkey filename=seqdata noStatus=1

rm -f testkey
# Get the data and make sure that it matches
echo "$S3_COMMAND get $TEST_BUCKET/testkey filename=testkey"
$S3_COMMAND get $TEST_BUCKET/testkey filename=testkey
diff seqdata testkey
rm -f seqdata testkey

# Delete the file
echo "$S3_COMMAND delete $TEST_BUCKET/testkey"
$S3_COMMAND delete $TEST_BUCKET/testkey

# Remove the test bucket
echo "$S3_COMMAND delete $TEST_BUCKET"
$S3_COMMAND delete $TEST_BUCKET

# Make sure it's not there
echo "$S3_COMMAND list | grep $TEST_BUCKET"
$S3_COMMAND list | grep $TEST_BUCKET

# Now create it again
echo "$S3_COMMAND create $TEST_BUCKET"
$S3_COMMAND create $TEST_BUCKET

# Put 10 files in it
for i in `seq 0 9`; do
    echo "echo \"Hello\" | $S3_COMMAND put $TEST_BUCKET/key_$i"
    echo "Hello" | $S3_COMMAND put $TEST_BUCKET/key_$i
done

# List with all details
echo "$S3_COMMAND list $TEST_BUCKET"
$S3_COMMAND list $TEST_BUCKET

COPY_BUCKET=${TEST_BUCKET_PREFIX}.copybucket

# Create another test bucket and copy a file into it
echo "$S3_COMMAND create $COPY_BUCKET"
$S3_COMMAND create $COPY_BUCKET
echo <<EOF
$S3_COMMAND copy $TEST_BUCKET/key_5 $COPY_BUCKET/copykey
EOF
$S3_COMMAND copy $TEST_BUCKET/key_5 $COPY_BUCKET/copykey

# List the copy bucket
echo "$S3_COMMAND list $COPY_BUCKET"
$S3_COMMAND list $COPY_BUCKET

# Compare the files
rm -f key_5 copykey
echo "$S3_COMMAND get $TEST_BUCKET/key_5 filename=key_5"
$S3_COMMAND get $TEST_BUCKET/key_5 filename=key_5
echo "$S3_COMMAND get $COPY_BUCKET/copykey filename=copykey"
$S3_COMMAND get $COPY_BUCKET/copykey filename=copykey
diff key_5 copykey
rm -f key_5 copykey

# Delete the files
for i in `seq 0 9`; do
    echo "$S3_COMMAND delete $TEST_BUCKET/key_$i"
    $S3_COMMAND delete $TEST_BUCKET/key_$i
done
echo "$S3_COMMAND delete $COPY_BUCKET/copykey"
$S3_COMMAND delete $COPY_BUCKET/copykey

# Delete the copy bucket
echo "$S3_COMMAND delete $COPY_BUCKET"
$S3_COMMAND delete $COPY_BUCKET

# Now create a new zero-length file
echo "$S3_COMMAND put $TEST_BUCKET/aclkey < /dev/null"
$S3_COMMAND put $TEST_BUCKET/aclkey < /dev/null

# Get the bucket acl
rm -f acl
echo "$S3_COMMAND getacl $TEST_BUCKET filename=acl"
$S3_COMMAND getacl $TEST_BUCKET filename=acl

# Add READ for all AWS users, and READ_ACP for everyone
echo <<EOF >> acl
Group   Authenticated AWS Users                                   READ
EOF
echo <<EOF >> acl
Group   All Users                                                 READ_ACP
EOF
echo "$S3_COMMAND setacl $TEST_BUCKET filename=acl"
$S3_COMMAND setacl $TEST_BUCKET filename=acl

# Test to make sure that it worked
rm -f acl_new
echo "$S3_COMMAND getacl $TEST_BUCKET filename=acl_new"
$S3_COMMAND getacl $TEST_BUCKET filename=acl_new
diff acl acl_new
rm -f acl acl_new

# Get the key acl
rm -f acl
echo "$S3_COMMAND getacl $TEST_BUCKET/aclkey filename=acl"
$S3_COMMAND getacl $TEST_BUCKET/aclkey filename=acl

# Add READ for all AWS users, and READ_ACP for everyone
echo <<EOF >> acl
Group   Authenticated AWS Users                                   READ
EOF
echo <<EOF >> acl
Group   All Users                                                 READ_ACP
EOF
echo "$S3_COMMAND setacl $TEST_BUCKET/aclkey filename=acl"
$S3_COMMAND setacl $TEST_BUCKET/aclkey filename=acl

# Test to make sure that it worked
rm -f acl_new
echo "$S3_COMMAND getacl $TEST_BUCKET/aclkey filename=acl_new"
$S3_COMMAND getacl $TEST_BUCKET/aclkey filename=acl_new
diff acl acl_new
rm -f acl acl_new

# Check multipart file upload (>15MB)
dd if=/dev/zero of=mpfile bs=1024k count=30
echo "$S3_COMMAND put $TEST_BUCKET/mpfile filename=mpfile"
$S3_COMMAND put $TEST_BUCKET/mpfile filename=mpfile
echo "$S3_COMMAND get $TEST_BUCKET/mpfile filename=mpfile.get"
$S3_COMMAND get $TEST_BUCKET/mpfile filename=mpfile.get
diff mpfile mpfile.get

# Check multipart copy
echo "$S3_COMMAND copy $TEST_BUCKET/mpfile $TEST_BUCKET/mpcopy"
$S3_COMMAND copy $TEST_BUCKET/mpfile $TEST_BUCKET/mpcopy
echo "$S3_COMMAND get $TEST_BUCKET/mpcopy filename=mpcopy.get"
$S3_COMMAND get $TEST_BUCKET/mpcopy filename=mpcopy.get
diff mpfile mpcopy.get

rm -f mpfile mpfile.get mpcopy.get

# Remove the test file
echo "$S3_COMMAND delete $TEST_BUCKET/aclkey"
$S3_COMMAND delete $TEST_BUCKET/aclkey
echo "$S3_COMMAND delete $TEST_BUCKET/mpfile"
$S3_COMMAND delete $TEST_BUCKET/mpfile
echo "$S3_COMMAND delete $TEST_BUCKET/mpcopy"
$S3_COMMAND delete $TEST_BUCKET/mpcopy
echo "$S3_COMMAND delete $TEST_BUCKET"
$S3_COMMAND delete $TEST_BUCKET
