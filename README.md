# AWS Lightsail Wordpress Terraform

This project, as the name may suggest, includes the Terraform configuration neeeded to setup a Wordpress site in Amazon Web Services(AWS) Lightsail.

## Why use Terraform with Lightsail?

Lightsail was introduced to make it easy to manage a Virtal Private Server(VPS). However, I wanted to make it even easier to deploy a Wordpress instance. Plus, I personally prefer to have my infrastructure as code, regardless of how simple the infrastructure may seem at first.

## Instance Snapshots

AWS Lightsail does provide an easy interface where instance snapshots can be created. However, this is a manual process.

This project configures an AWS Lambda function to create automatic snapshots of the Lightsail Wordpress instance. It also comes with a function to delete older snapshots, after they have surpassed the "retention period".

### Snapshot Failure

It is possible, for several reasons, that a Lambda function may fail. In our case, this would potentially mean that we have no backups of our site. To mitigate this, this project uses CloudWatch alarms and SNS notifications to notify you whenever:

- A function results in an error
- A function is not invoked when expected

## Setting up

Make sure that you have Terraform version **v0.11.5** installed. This should work with older versions of Terraform but it may not.

### AWS credentials

Make sure you have your AWS credentials setup. Follow the instructions at the [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html). These credentials would have be setup in order for you to be able to run the terraform commands.

After the AWS credentials are setup, the ".aws/credentials" file would look like the following:

[profile]
aws_access_key_id = XXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXX

From here on out, all your terraform commands should be prefixed with "AWS_PROFILE=profile". For example, "AWS_PROFILE=profile terraform plan".

### Terraform remote state

We will be using an S3 bucket to store our Terraform state and a DynamoDB table as a lock table. To set these resources up, move into the **state** directory and run the following commands:

- terraform init
- terraform get
- terraform apply
  - You will be asked to provide the values for "aws_region" and "project-prefix"
  - Make note of the "state_bucket_name" and "lock_table_name" since you will use them in the next step.

### Core module to use remote state

Move into the **core** directory and run the following command:

terraform init -backend-config "bucket={state_bucket_name}" -backend-config "key=core-state" -backend-config "region={aws_region}" -backend-config "encrypt=true" -backend-config "lock_table={lock_table_name}"

You are all set to setup the infrastructure now.

### Core infrastructure

Move into the the **core** directory and run the following commands:

- terraform init
- terraform get
- terraform apply
  - You will be asked to provide the values for several variables. Refer to the **variables.tf** for more information

**Tip** Terraform supports providing values for the needed variables in a `terraform.tfvars` file. I strongly recommend you make use of this since it makes it very easy to keep track of the variables and run terraform commands.

### Next steps

After you have completed the steps above, you are all set with your Wordpress instance. Navigate to the IP address outputted as a result of setting up the core infrastructure and you will reach your homepage.

Yoy may want to access your website using a domain name instead of an IP. To do that, you can add/update the `A record` of your domain with your hosting provider to point to the IP address of your website. Terrafor currently does not support this step.

## Tearing down

**Having infrastructure as code brings joy at least in two occasions: 1) Applying infrastructure and 2) Destroying infrastructure**. If you would like to tear down your wordpress site, it is as easy as running `terraform destroy` first in the **core** directory and then in the **state** directory.
