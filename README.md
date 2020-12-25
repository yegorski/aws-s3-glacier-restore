# Restore Glacier Objects to S3

Script to run restore files from Glacier with multiple threads.

## Prerequisites

1. AWS S3 CLI `brew install s3cmd`
1. Python3
1. Terraform
1. AWS credentials to run Terraform in your AWS account

## Restoring A Small Number of Objects Sequentially

1. List objects in the bucket. Optionally Specify `PREFIX` to limit which objects to restore:

   ```bash
   BUCKET=<bucket name> PREFIX=prefix/to/objects python3 list_objects.py > my_objects.txt
   ```

   1. NOTE: if your bucket/prefix contains objects that are both in S3 and Glacier, and you want to filter only by Glacier status, replace `print(i["Key"])` in the Python script with `print(i)` in the `list_objects.py` script. This will get the object and its properties, not just the filename (aka `Key`). Then you can run `grep GLACIER my_objects.txt > my_glacier_objects.txt` to get only objects in Glacier. After this, you'll still need to get a list of Keys only in order to run the next step.

1. Run `./restore.bash restore <bucket name> my_glacier_objects.txt`.
1. Run `./restore.bash copy <bucket-name> my_glacier_objects.txt`.

## Restoring A Large Number of Objects In Parallel

### Create a Server to Perform Glacier Restore

When dealing with large number of objects, it may not be feasible to perform the the restore from your local computer. You may need the following:

- A large EC2 server, 8 to 16 CPUs should be sufficient.
- A script to restore objects in parallel.

> NOTE: Terraform steps below use the [AWS EC2 Instance Terraform Module][] Terraform module.

1. Replace `BUCKET_NAME` in `terraform/ec2.tf` with your bucket.
1. Run `terraform apply`.
1. Manually apply this bucket policy replacing `AWS_ACCOUNT_ID`, `BUCKET_NAME`, and `ROLE_NAME`, allowing the EC2's role to access the bucket:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "EC2RestoreServerAllowFullAccess",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::AWS_ACCOUNT_ID:role/ROLE_NAME"
         },
         "Action": "s3:*",
         "Resource": ["arn:aws:s3:::BUCKET_NAME/*", "arn:aws:s3:::BUCKET_NAME"]
       }
     ]
   }
   ```

1. SSH into the server `ssh ec2-user@SERVER_ID`.
1. Become root `sudo su -`.
1. Check that the server has access to the buckets `aws s3 ls s3://BUCKET_NAME/`.
1. Copy the `list_objects.py` and `restore.bash` to the server and allow execiution `chmod +x restore.bash`.

### Perform Glacier Restore

1. Output the list of bucket objects into a file:

   ```bash
   BUCKET=<bucket name> PREFIX=prefix/to/objects python3 list.py > my_objects.txt
   ```

   1. The `PREFIX` is optional but it is a good idea to specify it because listing all objects is a long operation. Restoring object piece-meal by prefix speeds up the process.

1. Filter the list by objects that are in Glacier:

   ```bash
   grep GLACIER staging.txt > my_glacier_objects.txt
   ```

1. Output only the keys of archived objects:

   ```bash
   cat my_glacier_objects.txt | awk -F ' ' '{ print $2 }' | sed 's/^.//' | sed 's/..$//' > my_objects_keys.txt
   ```

1. Split up the keys file into chunks. Each chunk will be processed in parallel. This command splits the keys file into separate files each with 100k rows.

   ```bash
   split -l 100000 ../my_objects_keys.txt
   ```

1. For example if the `prefix/to/objects` prefix has a million objects, with 100K records split per file, you'll get a list of 10 files:

   ```txt
   xaa
   xab
   xac
   xad
   xae
   xaf
   xag
   xah
   xai
   xaj
   ```

1. Performing the restore is a 2-step process.

   1. The only difference with the parallel restore is that there is a loop that iterates over 100k chucks. The command executions are detached from the terminal session (via `nohup`) and are run in the backgroup (via trailing `&`). That way an SSH session timeout won't halt the restore.

   ```bash
   for file in $(ls .); do
       echo "Restoring ${file}" > ${file}.log
       nohup ./restore.bash restore "<bucket name>" ${file} &
   done
   ```

1. Monitor the restore via `jobs` Linux command or tail the `${file}.log` files.
1. After the restores are successful, the objects are available for 30 days. To make them available permanently, run the `copy` command on the same files:

   ```bash
   for file in $(ls .); do
       echo "Copying back ${file}" > ${file}.log
       nohup ./restore.bash copy "<bucket name>" ${file} &
   done
   ```

## Teardown

After the restore, the server is longer needed. Run `terraform destroy`.

[aws ec2 instance terraform module]: https://github.com/yegorski/terraform-aws-ec2
