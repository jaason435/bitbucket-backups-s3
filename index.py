import sys
sys.path.insert(0, 'vendor')
import requests
import boto3
import time
import os
import base64
import io
import credstash
from dotenv import load_dotenv
from datetime import datetime

def lambda_handler(event, context):
    # Load config
    load_dotenv()

    # Load individual config settings
    BUCKET_NAME = os.environ['BUCKET_NAME']
    backup_master_only = os.environ['backup_master_only']
    use_credstash = os.environ['use_credstash']

    # Determine if we're using credstash or not
    if use_credstash:
        ACCOUNT_NAME = credstash.getSecret(os.environ['CREDSTASH_ACCOUNTNAME'])
        ACCOUNT_PASSWORD = credstash.getSecret(os.environ['CREDSTASH_ACCOUNTPASSWORD'])
    else:
        ACCOUNT_NAME = os.environ['ACCOUNT_NAME']
        ACCOUNT_PASSWORD = os.environ['ACCOUNT_PASSWORD']

    basic_auth = base64.b64encode(f'{ACCOUNT_NAME}:{ACCOUNT_PASSWORD}'.encode()).decode("utf-8") 

    for repository,username in get_repositories(basic_auth):
        branches = get_branches(repository, username, basic_auth)
        if backup_master_only:
            backup("master", repository, username, basic_auth, BUCKET_NAME)
        else:
            for branch in branches:
                branch_name = branch['name']
                backup(branch_name, repository, username, basic_auth, BUCKET_NAME)

def log(message):
  print('{"date": "' + time.strftime("%Y-%m-%d %H:%M") + '", "message": "' + message + '"')

def get_branches(repository, username, basic_auth):
  request = requests.get(f'https://api.bitbucket.org/2.0/repositories/{username}/{repository}/refs/branches', headers={'Authorization': f'Basic {basic_auth}'})
  if (request.status_code == 200):
    return request.json()['values']
  else:
    log(f'failed getting branches from repository {repository} from {username}, response:{str(request)}')
    return []

def backup(branch_name, repository, username, basic_auth, s3_bucket):
  log(f'backup branch {branch_name} from repository {repository} from {username}')
  s3 = boto3.client('s3')
  response = requests.get(f'https://bitbucket.org/{username}/{repository}/get/{branch_name}.zip', headers={'Authorization': f'Basic {basic_auth}'}, stream=True)
  if (response.status_code == 200):
    todaysDate = datetime.today().strftime('%Y-%m-%d')
    filename = f'{username}-{repository}/{branch_name.replace("/","-")}.zip'
    s3.upload_fileobj(io.BytesIO(response.content), s3_bucket, todaysDate + '/' + filename)
  else:
    log(f'failed getting zip of branch {branch_name} from repository {repository} from {username}, response:{str(response.text)}')

def get_repositories(basic_auth):
  page = f'https://api.bitbucket.org/2.0/repositories?role=member'
  repositories = []
  while True:
    request = requests.get(page, headers={'Authorization': f'Basic {basic_auth}'})
    if (request.status_code == 200):
      json = request.json()
      for repo in json['values']:
        owner = repo['owner']
        if 'username' in owner:
          username = owner['username']
        else:
          username = owner['nickname']
        repository = repo['name'].replace(' ', '-')
        repositories.append((repository, username))
      if 'next' in json:
        page = json['next']
      else: 
        break
    else:
      log(f'failed getting account information, response:{str(request.text)}')
      sys.exit(1)
  return repositories

# lambda_handler('test','test')