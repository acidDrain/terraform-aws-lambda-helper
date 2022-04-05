# terraform-aws-lambda-helper

An example project that uses `terraform` and TypeScript to deploy a Lambda 
function to AWS. The Lambda runs on a schedule/cron via Event Bridge.


- [Getting Started](#getting-started)
  - [Transpiling the TypeScript Source](#transpiling-the-typescript-source)
  - [Terraform](#terraform)
    - [Producing a `terraform` Plan](#producing-a-terraform-plan)
    - [Creating a `JSON` Version of the `terraform` Plan](#creating-a-json-version-of-the-terraform-plan)
    - [Deploying the Lambda](#deploying-the-lambda)
    - [Destroying and Removing All Resources from AWS](#destroying-and-removing-all-resources-from-aws)

## Getting Started

First, this project uses `terraform`. Make sure that [`terraform` is 
installed](https://www.terraform.io/downloads).

Terraform will use your active AWS configuration, AWS environment variables, 
etc., for access to AWS. The easiest way to use this project is to pre-set your
AWS credentials or profile.

You can simply set the environment variable `AWS_PROFILE` to an active AWS
profile/configuration and that should be enough.

Example:

```sh
$ export AWS_PROFILE=lab-aws
$ aws sso login
Attempting to automatically open the SSO authorization page in your default browser.
If the browser does not open or you wish to use a different device to authorize this request, open the following URL:

https://device.sso.us-west-2.amazonaws.com/

Then enter the code:

XXXX-YYYY
Successfully logged into Start URL: https://my-custom-domain.awsapps.com/start
```

### Transpiling the TypeScript Source

This project includes configuration that TypeScript uses to transpile files in 
`./src` to `ES6`, and uses `ES6 modules` (due to `"type": "module"` in 
`package.json`). [This works natively with node14 (and 
Lambda)](https://aws.amazon.com/blogs/compute/using-node-js-es-modules-and-top-level-await-in-aws-lambda/)

To transpile and produce artifacts for Lambda:

```sh
$ make build
npm install

added 129 packages, and audited 130 packages in 1s

24 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
touch node_modules
node_modules/.bin/tsc --build
```

To simply do a type check:


```sh
$ make type-check
node_modules/.bin/tsc --noEmit
src/index.ts:5:8 - error TS2304: Cannot find name 'bar'.

5   foo: bar;
         ~~~

src/index.ts:9:64 - error TS2741: Property 'foo' is missing in type '{ region: string; LambdaName: string; }' but required in type 'IBaseENV'.

 9 const getValuesFromEnv = (env: NodeJS.ProcessEnv): IBaseENV => ({
                                                                  ~~
10   region: env.region,
   ~~~~~~~~~~~~~~~~~~~~~
11   LambdaName: env.LambdaName,
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
12 });
   ~~

  src/index.ts:5:3
    5   foo: bar;
        ~~~
    'foo' is declared here.


Found 2 errors in the same file, starting at: src/index.ts:5

make: *** [Makefile:57: type-check] Error 2

```

### Terraform

The terraform configuration will:

- copy the `package*json` to the `build` folder
- change directory to `build` and run `npm ci`
- zip up the contents of `build` and place the resulting `zip` archive in 
  `build`
- create an S3 bucket and upload the `zip` archive of the Lambda code
- create the necessary IAM role, policies, and policy attachments for the 
  Lambda to trigger by Event Bridge


#### Producing a `terraform` Plan

```sh
$ make plan
npm install
terraform init

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/archive from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/archive v2.2.0...
- Installed hashicorp/archive v2.2.0 (signed by HashiCorp)bulk request {
- Installing hashicorp/aws v4.0.0...

added 129 packages, and audited 130 packages in 1s

24 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
touch node_modules
node_modules/.bin/tsc --build
cp package*json build/ && \
cd build/ && \
NODE_ENV=production npm ci

up to date, audited 1 package in 230ms

found 0 vulnerabilities
- Installed hashicorp/aws v4.0.0 (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
terraform plan -out tfplan.bin

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

....
<output truncated>
....

Plan: 13 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + function_name      = "cron-lambda-dev"
  + lambda_bucket_name = (known after apply)

─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: tfplan.bin

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan.bin"

```

#### Creating a `JSON` Version of the `terraform` Plan

```sh
$ make plan-json
terraform show -json tfplan.bin > tfplan.json
$ jq -r '.resource_changes[] | "\(.change) - \(.mode) - \(.address)"' tfplan.json
{"actions":["create"],"before":null,"after":{"description":"This rule invokes a Lambda every day at the specified time (UTC).","event_bus_name":"default","event_pattern":null,"is_enabled":true,"name":"scheduled","role_arn":null,"schedule_expression":"cron(25 06 * * ? *)","tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"}},"after_unknown":{"arn":true,"id":true,"name_prefix":true,"tags_all":{}},"before_sensitive":false,"after_sensitive":{"tags_all":{}}} - managed - aws_cloudwatch_event_rule.scheduled-lambda
{"actions":["create"],"before":null,"after":{"batch_target":[],"dead_letter_config":[],"ecs_target":[],"event_bus_name":"default","http_target":[],"input":"{\n  \"detail-type\": \"Scheduled Event\",\n  \"detail\": {}\n}\n","input_path":null,"input_transformer":[],"kinesis_target":[],"redshift_target":[],"retry_policy":[],"role_arn":null,"run_command_targets":[],"sqs_target":[]},"after_unknown":{"arn":true,"batch_target":[],"dead_letter_config":[],"ecs_target":[],"http_target":[],"id":true,"input_transformer":[],"kinesis_target":[],"redshift_target":[],"retry_policy":[],"rule":true,"run_command_targets":[],"sqs_target":[],"target_id":true},"before_sensitive":false,"after_sensitive":{"batch_target":[],"dead_letter_config":[],"ecs_target":[],"http_target":[],"input_transformer":[],"kinesis_target":[],"redshift_target":[],"retry_policy":[],"run_command_targets":[],"sqs_target":[]}} - managed - aws_cloudwatch_event_target.run_lambda_daily
{"actions":["create"],"before":null,"after":{"kms_key_id":null,"name":"/aws/lambda/cron-lambda-dev","name_prefix":null,"retention_in_days":0,"tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"}},"after_unknown":{"arn":true,"id":true,"tags_all":{}},"before_sensitive":false,"after_sensitive":{"tags_all":{}}} - managed - aws_cloudwatch_log_group.lambda_run_log
{"actions":["create"],"before":null,"after":{"log_group_name":"/aws/lambda/cron-lambda-dev","name":"/failure"},"after_unknown":{"arn":true,"id":true},"before_sensitive":false,"after_sensitive":{}} - managed - aws_cloudwatch_log_stream.lambda_failures
{"actions":["create"],"before":null,"after":{"log_group_name":"/aws/lambda/cron-lambda-dev","name":"/success"},"after_unknown":{"arn":true,"id":true},"before_sensitive":false,"after_sensitive":{}} - managed - aws_cloudwatch_log_stream.lambda_successes
{"actions":["create"],"before":null,"after":{"description":null,"name_prefix":null,"path":"/","tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"}},"after_unknown":{"arn":true,"id":true,"name":true,"policy":true,"policy_id":true,"tags_all":{}},"before_sensitive":false,"after_sensitive":{"tags_all":{}}} - managed - aws_iam_policy.lambda_overrides_policy
{"actions":["create"],"before":null,"after":{"assume_role_policy":"{\n  \"Version\": \"2012-10-17\",\n  \"Statement\": [\n    {\n      \"Sid\": \"\",\n      \"Effect\": \"Allow\",\n      \"Action\": \"sts:AssumeRole\",\n      \"Principal\": {\n        \"Service\": \"lambda.amazonaws.com\"\n      }\n    }\n  ]\n}","description":null,"force_detach_policies":false,"max_session_duration":3600,"name":"scheduled-lambda-role","path":"/","permissions_boundary":null,"tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"}},"after_unknown":{"arn":true,"create_date":true,"id":true,"inline_policy":true,"managed_policy_arns":true,"name_prefix":true,"tags_all":{},"unique_id":true},"before_sensitive":false,"after_sensitive":{"inline_policy":[],"managed_policy_arns":[],"tags_all":{}}} - managed - aws_iam_role.lambda_exec
{"actions":["create"],"before":null,"after":{"role":"scheduled-lambda-role"},"after_unknown":{"id":true,"policy_arn":true},"before_sensitive":false,"after_sensitive":{}} - managed - aws_iam_role_policy_attachment.lambda_policy
{"actions":["create"],"before":null,"after":{"code_signing_config_arn":null,"dead_letter_config":[],"description":null,"environment":[{"variables":{"LambdaName":"cron-lambda-dev","region":"us-west-2"}}],"file_system_config":[],"filename":null,"function_name":"cron-lambda-dev","handler":"index.handler","image_config":[],"image_uri":null,"kms_key_arn":null,"layers":null,"memory_size":128,"package_type":"Zip","publish":false,"reserved_concurrent_executions":-1,"runtime":"nodejs14.x","s3_key":"cron-lambda-dev-archive.zip","s3_object_version":null,"source_code_hash":"YCsQUFkk66CgH0X6Uk0B0gZ2lDxoDDbzWKzQT43kTVQ=","tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"},"timeout":3,"timeouts":null,"vpc_config":[]},"after_unknown":{"architectures":true,"arn":true,"dead_letter_config":[],"environment":[{"variables":{}}],"file_system_config":[],"id":true,"image_config":[],"invoke_arn":true,"last_modified":true,"qualified_arn":true,"role":true,"s3_bucket":true,"signing_job_arn":true,"signing_profile_version_arn":true,"source_code_size":true,"tags_all":{},"tracing_config":true,"version":true,"vpc_config":[]},"before_sensitive":false,"after_sensitive":{"architectures":[],"dead_letter_config":[],"environment":[{"variables":{}}],"file_system_config":[],"image_config":[],"tags_all":{},"tracing_config":[],"vpc_config":[]}} - managed - aws_lambda_function.main
{"actions":["create"],"before":null,"after":{"action":"lambda:InvokeFunction","event_source_token":null,"function_name":"cron-lambda-dev","principal":"events.amazonaws.com","qualifier":null,"source_account":null,"statement_id":"AllowExecutionFromCloudWatch","statement_id_prefix":null},"after_unknown":{"id":true,"source_arn":true},"before_sensitive":false,"after_sensitive":{}} - managed - aws_lambda_permission.allow_cloudwatch
{"actions":["create"],"before":null,"after":{"bucket":"cron-lambda-dev-bucket","bucket_prefix":null,"force_destroy":true,"tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"}},"after_unknown":{"acceleration_status":true,"acl":true,"arn":true,"bucket_domain_name":true,"bucket_regional_domain_name":true,"cors_rule":true,"grant":true,"hosted_zone_id":true,"id":true,"lifecycle_rule":true,"logging":true,"object_lock_configuration":true,"policy":true,"region":true,"replication_configuration":true,"request_payer":true,"server_side_encryption_configuration":true,"tags_all":{},"versioning":true,"website":true,"website_domain":true,"website_endpoint":true},"before_sensitive":false,"after_sensitive":{"cors_rule":[],"grant":[],"lifecycle_rule":[],"logging":[],"object_lock_configuration":[],"replication_configuration":[],"server_side_encryption_configuration":[],"tags_all":{},"versioning":[],"website":[]}} - managed - aws_s3_bucket.lambda_bucket
{"actions":["create"],"before":null,"after":{"bucket":"cron-lambda-dev-bucket","expected_bucket_owner":null,"rule":[{"apply_server_side_encryption_by_default":[{"kms_master_key_id":"","sse_algorithm":"AES256"}],"bucket_key_enabled":null}]},"after_unknown":{"id":true,"rule":[{"apply_server_side_encryption_by_default":[{}]}]},"before_sensitive":false,"after_sensitive":{"rule":[{"apply_server_side_encryption_by_default":[{}]}]}} - managed - aws_s3_bucket_server_side_encryption_configuration.lambda_bucket-encryption
{"actions":["create"],"before":null,"after":{"acl":"private","cache_control":null,"content":null,"content_base64":null,"content_disposition":null,"content_encoding":null,"content_language":null,"etag":"de1d6866a5f2634dbc73e2637e411e2b","force_destroy":false,"key":"cron-lambda-dev-archive.zip","metadata":null,"object_lock_legal_hold_status":null,"object_lock_mode":null,"object_lock_retain_until_date":null,"source":"./build/cron-lambda-dev-archive.zip","source_hash":null,"tags":null,"tags_all":{"ManagedBy":"terraform","application":"cron-lambda","environment":"dev"},"website_redirect":null},"after_unknown":{"bucket":true,"bucket_key_enabled":true,"content_type":true,"id":true,"kms_key_id":true,"server_side_encryption":true,"storage_class":true,"tags_all":{},"version_id":true},"before_sensitive":false,"after_sensitive":{"tags_all":{}}} - managed - aws_s3_object.lambda_handler_object
{"actions":["read"],"before":null,"after":{"override_json":null,"override_policy_documents":null,"policy_id":null,"source_json":null,"source_policy_documents":null,"statement":[{"actions":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"condition":[],"effect":"Allow","not_actions":null,"not_principals":[],"not_resources":null,"principals":[],"resources":[],"sid":null}],"version":null},"after_unknown":{"id":true,"json":true,"statement":[{"actions":[false,false,false],"condition":[],"not_principals":[],"principals":[],"resources":[true]}]},"before_sensitive":false,"after_sensitive":{"statement":[{"actions":[false,false,false],"condition":[],"not_principals":[],"principals":[],"resources":[false]}]}} - data - data.aws_iam_policy_document.lambda_overrides

```

#### Deploying the Lambda

```sh
$ make deploy
terraform apply tfplan.bin
aws_cloudwatch_log_group.lambda_run_log: Creating...
aws_cloudwatch_event_rule.scheduled-lambda: Creating...
aws_iam_role.lambda_exec: Creating...
aws_s3_bucket.lambda_bucket: Creating...
aws_cloudwatch_event_rule.scheduled-lambda: Creation complete after 2s [id=scheduled]
aws_cloudwatch_log_group.lambda_run_log: Creation complete after 2s [id=/aws/lambda/cron-lambda-dev]
data.aws_iam_policy_document.lambda_overrides: Reading...
aws_cloudwatch_log_stream.lambda_successes: Creating...
aws_cloudwatch_log_stream.lambda_failures: Creating...
data.aws_iam_policy_document.lambda_overrides: Read complete after 0s [id=2997056222]
aws_iam_policy.lambda_overrides_policy: Creating...
aws_iam_policy.lambda_overrides_policy: Creation complete after 0s [id=arn:aws:iam::1234567890123:policy/terraform-20220405045930651600000001]
aws_cloudwatch_log_stream.lambda_successes: Creation complete after 0s [id=/success]
aws_iam_role.lambda_exec: Creation complete after 2s [id=scheduled-lambda-role]
aws_iam_role_policy_attachment.lambda_policy: Creating...
aws_cloudwatch_log_stream.lambda_failures: Creation complete after 0s [id=/failure]
aws_iam_role_policy_attachment.lambda_policy: Creation complete after 1s [id=scheduled-lambda-role-20220405045931482700000002]
aws_s3_bucket.lambda_bucket: Creation complete after 7s [id=cron-lambda-dev-bucket]
aws_s3_bucket_server_side_encryption_configuration.lambda_bucket-encryption: Creating...
aws_s3_object.lambda_handler_object: Creating...
aws_s3_bucket_server_side_encryption_configuration.lambda_bucket-encryption: Creation complete after 1s [id=cron-lambda-dev-bucket]
aws_s3_object.lambda_handler_object: Creation complete after 1s [id=cron-lambda-dev-archive.zip]
aws_lambda_function.main: Creating...
aws_lambda_function.main: Still creating... [10s elapsed]
aws_lambda_function.main: Creation complete after 12s [id=cron-lambda-dev]
aws_lambda_permission.allow_cloudwatch: Creating...
aws_cloudwatch_event_target.run_lambda_daily: Creating...
aws_lambda_permission.allow_cloudwatch: Creation complete after 1s [id=AllowExecutionFromCloudWatch]
aws_cloudwatch_event_target.run_lambda_daily: Creation complete after 1s [id=scheduled-terraform-20220405045949126500000003]

Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

function_name = "cron-lambda-dev"
lambda_bucket_name = "cron-lambda-dev-bucket"

```

#### Destroying and Removing All Resources from AWS

```sh
$ make destroy-all
Plan: 0 to add, 0 to change, 13 to destroy.

Changes to Outputs:
  - function_name      = "cron-lambda-dev" -> null
  - lambda_bucket_name = "cron-lambda-dev-bucket" -> null

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: destroy.tfplan.bin

To perform exactly these actions, run the following command to apply:
    terraform apply "destroy.tfplan.bin"
terraform apply destroy.tfplan.bin
aws_cloudwatch_log_stream.lambda_failures: Destroying... [id=/failure]
aws_lambda_permission.allow_cloudwatch: Destroying... [id=AllowExecutionFromCloudWatch]
aws_cloudwatch_log_stream.lambda_successes: Destroying... [id=/success]
aws_iam_role_policy_attachment.lambda_policy: Destroying... [id=scheduled-lambda-role-20220405045931482700000002]
aws_s3_bucket_server_side_encryption_configuration.lambda_bucket-encryption: Destroying... [id=cron-lambda-dev-bucket]
aws_cloudwatch_event_target.run_lambda_daily: Destroying... [id=scheduled-terraform-20220405045949126500000003]
aws_iam_role_policy_attachment.lambda_policy: Destruction complete after 1s
aws_iam_policy.lambda_overrides_policy: Destroying... [id=arn:aws:iam::1234567890123:policy/terraform-20220405045930651600000001]
aws_cloudwatch_log_stream.lambda_failures: Destruction complete after 1s
aws_cloudwatch_log_stream.lambda_successes: Destruction complete after 1s
aws_cloudwatch_event_target.run_lambda_daily: Destruction complete after 1s
aws_iam_policy.lambda_overrides_policy: Destruction complete after 0s
aws_cloudwatch_log_group.lambda_run_log: Destroying... [id=/aws/lambda/cron-lambda-dev]
aws_s3_bucket_server_side_encryption_configuration.lambda_bucket-encryption: Destruction complete after 1s
aws_lambda_permission.allow_cloudwatch: Destruction complete after 1s
aws_cloudwatch_event_rule.scheduled-lambda: Destroying... [id=scheduled]
aws_lambda_function.main: Destroying... [id=cron-lambda-dev]
aws_cloudwatch_log_group.lambda_run_log: Destruction complete after 0s
aws_lambda_function.main: Destruction complete after 0s
aws_iam_role.lambda_exec: Destroying... [id=scheduled-lambda-role]
aws_s3_object.lambda_handler_object: Destroying... [id=cron-lambda-dev-archive.zip]
aws_cloudwatch_event_rule.scheduled-lambda: Destruction complete after 0s
aws_s3_object.lambda_handler_object: Destruction complete after 1s
aws_s3_bucket.lambda_bucket: Destroying... [id=cron-lambda-dev-bucket]
aws_iam_role.lambda_exec: Destruction complete after 1s
aws_s3_bucket.lambda_bucket: Destruction complete after 0s

Apply complete! Resources: 0 added, 0 changed, 13 destroyed.

```

