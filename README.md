# Bitbucket Backups
Take backups of your Bitbucket repositories on AWS S3.

Feel free to read about this with some more details on [Medium](https://medium.com/axons/essential-kubernetes-tools-94503209d1cb).

[![DockerHub Badge](https://dockeri.co/image/bouwe/bitbucket-backups-s3)](https://hub.docker.com/r/bouwe/bitbucket-backups-s3)

## Installation - For Kubernetes
Set the right environment variables in the secrets file.

```
kubectl apply -f kubernetes/
```

## Terraform
Use the examples in ```/terraform``` to get started with setting up a lambda function and then scheduling it using a cloudwatch event rules.

### Lambda
Change the ```memory_size``` depending on the size of the repo's you're backing up (Lambda prices depend on memory).

This project uses credstash (https://github.com/fugue/credstash)

Follow the setup and add credstash entries for the username and password for BitBucket.

Then in the lambda file, update the ```CREDSTASH_ACCOUNTNAME``` & ```CREDSTASH_ACCOUNTPASSWORD``` to point to the key names of what you saved.

### Event Bridge
Update the ```schedule_expression``` rate to match how often you want this to run.

# Notes:
Run the following to update dependencies before uploading to Lambda
```pip3 install -t vendor -r aws_requirements.txt```

