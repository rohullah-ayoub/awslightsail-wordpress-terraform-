# AWS Lightsail Wordpress Terraform

This project, as the name may suggest, includes the Terraform configuration neeeded to setup a Wordpress site in Amazon Web Services(AWS) Lightsail.

## Why use Terraform with Lightsail?

It is a valid question. Lightsail was introduced to make it easy to manage a Virtal Private Server(VPS). However, I wanted to make it even easier to deploy a Wordpress installation. Plus, I personally prefer to have my infrastructure as code, regardless of how simple the infrastructure may seem at first.

### Instance Snapshots

AWS Lightsail does provide an easy interface where instance snapshots can be created. However, this is a manual process.

This project configures an AWS Lambda function to create automatic snapshots of the Lightsail Wordpress instance. It even comes with a function to delete older snapshots, after they have surpassed the "retention period".

## How to use

Please make sure that you have Terraform version **v0.11.5** installed. This should work with older versions of Terraform but it may not.

Please make sure you have your AWS credentials setup. Follow the instructions at the [AWS documentation](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html), if you have not done this already.

### Setting up state Backend resources

We will be using an S3 bucket to store our Terraform state and a DynamoDB table as a lock table. To set these resources up, move into the **state** directory and run the following commands:

- terraform init
- terraform get
- terraform apply
  - You will be asked to provide the values for "aws_region" and "project-prefix"
  - Make note of the "state_bucket_name" and "lock_table_name" since you will use them in the next step.

## Setting up Backend for the core infrastructure

Move into the **core** directory and run the following command:

terraform init -backend-config "bucket={state_bucket_name}" -backend-config "key=core-state" -backend-config "region={aws_region}" -backend-config "encrypt=true" -backend-config "lock_table={lock_table_name}"

You are all set to setup the infrastructure now.

## Setting up the core infrastructure

In the **core** directory and run the following commands:

- terraform init
- terraform get
- terraform apply
  - You will be asked to provide the values for several variables. Refer to the **variables.tf** for more information
