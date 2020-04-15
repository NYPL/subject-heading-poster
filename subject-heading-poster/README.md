# Subject Heading Poster

This project contains source code and supporting files for a serverless application that you can deploy with the SAM CLI. It includes the following files and folders.

- subject-heading-poster - Code for the application's Lambda function.
- subject-heading-poster/events - Invocation events that you can use to invoke the function.
- subject-heading-poster/sam.[environment].yml - A template that defines the application's AWS resources.

The application uses the continuous-update-service Lambda and the Bib Kinesis stream. These resources are defined in the `sam.[environment].yml` file in this project.

## Setup
This services use the Ruby2.5 runtime.

### Installation

``bundle install; bundle install --deployment``

If you get the error ``You must use Bundler 2 or greater with this lockfile.`` run

``gem install bundler -v 2.0.2``

### Config
All config is in `sam.[ENVIRONMENT].yml` templates, encrypted as necessary.

## Contributing
### Git Workflow
 * Cut branches from `development`.
 * Create PR against `development`.
 * After review, PR author merges.
 * Merge `development` > `qa`
 * Merge `qa` > `master`
 * Tag version bump in `master`

## SAM CLI
The Serverless Application Model Command Line Interface (SAM CLI) is an extension of the AWS CLI that adds functionality for building and testing Lambda applications. It uses Docker to run your functions in an Amazon Linux environment that matches Lambda. It can also emulate your application's build environment and API.

To use the SAM CLI, you need the following tools.

* AWS CLI - [Install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [configure it with your AWS credentials].
* SAM CLI - [Install the SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
* Ruby - [Install Ruby 2.5](https://www.ruby-lang.org/en/documentation/installation/)
* Docker - [Install Docker community edition](https://hub.docker.com/search/?type=edition&offering=community)

### Running Events Locally
The following will invoke the lambda against various mock events. Replace `[event]` with one of the mock events listed below.

```bash
subject-heading-poster$ sam local invoke SubjectHeadingPoster --event events/[event].json --template sam.[environment].yml
```


The SAM CLI can also emulate your application's API. Use the `sam local start-api` to run the API locally on port 3000.

```bash
subject-heading-poster$ sam local start-api
subject-heading-poster$ curl http://localhost:3000/
```
