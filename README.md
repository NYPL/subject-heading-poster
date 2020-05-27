# Subject Heading Poster
The `SubjectHeadingPoster` is a Lambda listening to the `BibStream` to post bib data to the [Subject Heading (SHEP) API](https://github.com/NYPL/subject-headings-explorer-poc/tree/shep-api). It pulls in the `isResearchLayer` which is a Lambda Layer deployed on AWS. The code for the Layer lives in the [`is-research-service`](https://github.com/NYPL/is-research-service) repo.

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

To locally test a successful bib ingest, run the SHEP API (https://github.com/NYPL/subject-headings-explorer-poc) locally. Match the port to the one in the 'SHEP_API_BIBS_ENDPOINT' in the template. E.g., 'SHEP_API_BIBS_ENDPOINT': http://docker.for.mac.localhost:8080/api/v0.1/bibs is the url for the API running on port :8080.

```bash
sam local invoke SubjectHeadingPoster --event events/[event].json --template sam.[environment].yml
```
## Triggering events
Refer to this [lsp workflow documentation](https://github.com/NYPL/lsp_workflows/blob/d66eaeceb39401a533440420aca6004ee7c3c78f/workflows/bib-and-item-data-pipeline.md#appendix-b-re-playing-updates) for a method to trigger an event on the bib stream.

## Automated tests
``bundle exec rspec -fd``
