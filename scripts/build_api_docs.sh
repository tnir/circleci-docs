#!/bin/bash

set -e

# commands to build the widdershins/slate api documentation.
#

build_api_v1() {
    echo "Building API v1 documentation with Slate"
    cd src-api
    bundle exec middleman build --clean --verbose
    echo "Output bundled."
}

# We build our API v2 documentation from an openAPI spec. After fetching the spec we:
# a) augment the spec using "snippet-enricher-cli" to add code-samples to the spec.
# b) merge in any custom code samples we need to alter, using jq.
# c) run the spec through redoc-cli, outputting a single html file.
# d) move the file into our temporary workspace, created in .circleci/config.yml
build_api_v2() {
    echo "Building API v2 documentation with Redocly CLI"
    cd src-api;
    echo "Fetching OpenAPI spec."
    curl https://circleci.com/api/v2/openapi.json > openapi.json
    echo "Adding code samples to openapi.json spec."
    ./node_modules/.bin/snippet-enricher-cli --targets="node_request,python_python3,go_native,shell_curl" --input=openapi.json  > openapi-with-examples.json
    echo "Merging in JSON patches to correct and augment the OpenAPI spec."
    jq -s '.[0] * .[1]' openapi-with-examples.json openapi-patch.json > openapi-patched.json
    echo Bundle api docs and remove unused components
    npx redocly bundle openapi-patched.json --remove-unused-components --output openapi-final.json
    echo "Lint API docs"
    npx redocly lint openapi-final.json
    echo "Build docs with redocly cli."
    npx redocly build-docs openapi-final.json
    echo "Moving build redoc file to api/v2"
    mv redoc-static.html index.html
}


if [ "$1" == "-v1" ]
then
	build_api_v1
    cp -R build/* /tmp/workspace/api/v1
    echo "Output build moved to /tmp/workspace/api/v1"
    cp -R /tmp/workspace/api/v1/* /tmp/workspace/api
    echo "Also - Move /tmp/workspace/api/v1 so default root (api/) displays api v1."

elif [ "$1" == "-v1-next" ]
then
	build_api_v1

elif [ "$1" == "-v2-next" ]
then
	build_api_v2

elif [ "$1" == "-v2" ]
then
	build_api_v2
    cp index.html /tmp/workspace/api/v2
else
	echo "Invalid command"
fi
