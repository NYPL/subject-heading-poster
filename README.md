# Subject Heading Services
This repo contains services related to SCC's Subject Heading Explorer.

## Subject Heading Poster
The `SubjectHeadingPoster` is a Lambda listening to the `BibStream`. It pulls in the `isResearchLayer` which is a Lambda Layer deployed on AWS. The code for the Layer lives in the [`is-research-service`](https://github.com/NYPL/is-research-service) repo.
